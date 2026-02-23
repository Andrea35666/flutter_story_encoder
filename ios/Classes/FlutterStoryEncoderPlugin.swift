import Flutter
import UIKit
import AVFoundation

public class FlutterStoryEncoderPlugin: NSObject, FlutterPlugin, StoryEncoderHostApi {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var pixelBufferPool: CVPixelBufferPool?
    
    private var frameTime: CMTime = .zero
    private var isEncoding = false
    private let queue = DispatchQueue(label: "com.lucasveneno.flutter_story_encoder.queue")
    
    private var flutterApi: StoryEncoderFlutterApi?
    private var config: EncoderConfig?
    private var framesProcessed: Int64 = 0
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterStoryEncoderPlugin()
        StoryEncoderHostApiSetup.setUp(registrar.messenger(), api: instance)
        instance.flutterApi = StoryEncoderFlutterApi(binaryMessenger: registrar.messenger())
    }
    
    public func start(config: EncoderConfig, completion: @escaping (Result<Bool, Error>) -> Void) {
        queue.async {
            self._start(config: config, completion: completion)
        }
    }
    
    private func _start(config: EncoderConfig, completion: @escaping (Result<Bool, Error>) -> Void) {
        self.config = config
        self.framesProcessed = 0
        self.frameTime = .zero
        
        let url = URL(fileURLWithPath: config.outputPath)
        try? FileManager.default.removeItem(at: url)
        
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: config.width,
                AVVideoHeightKey: config.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: config.bitrate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: config.fps,
                    AVVideoExpectedSourceFrameRateKey: config.fps
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = false
            
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: config.width,
                kCVPixelBufferHeightKey as String: config.height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: attributes
            )
            
            if assetWriter!.canAdd(videoInput!) {
                assetWriter!.add(videoInput!)
            }
            
            if assetWriter!.startWriting() {
                assetWriter!.startSession(atSourceTime: .zero)
                isEncoding = true
                completion(.success(true))
            } else {
                completion(.failure(FlutterError(code: "START_FAILED", message: assetWriter?.error?.localizedDescription ?? "Unknown", details: nil)))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    public func appendFrame(rgbaData: FlutterStandardTypedData, completion: @escaping (Result<Bool, Error>) -> Void) {
        queue.async {
            guard self.isEncoding, let videoInput = self.videoInput else {
                completion(.success(false))
                return
            }
            
            if !videoInput.isReadyForMoreMediaData {
                completion(.success(false)) // Signal backpressure to Dart
                return
            }
            
            self._appendFrame(data: rgbaData.data, completion: completion)
        }
    }
    
    private func _appendFrame(data: Data, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let adaptor = pixelBufferAdaptor else {
            completion(.success(false))
            return
        }
        
        if pixelBufferPool == nil {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(config?.width ?? 1080),
                kCVPixelBufferHeightKey as String: Int(config?.height ?? 1920),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pixelBufferPool)
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool!, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            completion(.failure(FlutterError(code: "POOL_ERROR", message: "Memory pool expansion failed", details: nil)))
            return
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        
        data.withUnsafeBytes { pointer in
            let rawPointer = pointer.baseAddress!
            // Optimised memory swizzle: RGBA to BGRA if necessary, or direct copy for BGRA
            // In a high-scale app, we'd use vImage or Accelerate here if formats differ.
            memcpy(baseAddress, rawPointer, data.count)
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        if adaptor.append(buffer, withPresentationTime: frameTime) {
            framesProcessed += 1
            let fps = config?.fps ?? 30
            frameTime = CMTimeAdd(frameTime, CMTime(value: 1, timescale: Int32(fps)))
            
            let stats = EncodingStats(framesProcessed: framesProcessed, currentFps: Double(fps), progress: 0.0)
            DispatchQueue.main.async {
                self.flutterApi?.onProgress(stats: stats) { _ in }
            }
            completion(.success(true))
        } else {
            completion(.failure(FlutterError(code: "APPEND_FAILED", message: assetWriter?.error?.localizedDescription ?? "Unknown", details: nil)))
        }
    }
    
    public func finish(completion: @escaping (Result<String?, Error>) -> Void) {
        queue.async {
            self.isEncoding = false
            self.videoInput?.markAsFinished()
            self.assetWriter?.finishWriting {
                if self.assetWriter?.status == .completed {
                    completion(.success(self.config?.outputPath))
                } else {
                    completion(.failure(FlutterError(code: "FINISH_FAILED", message: self.assetWriter?.error?.localizedDescription ?? "Unknown", details: nil)))
                }
            }
        }
    }
    
    public func cancel() {
        queue.async {
            self.isEncoding = false
            self.assetWriter?.cancelWriting()
        }
    }
}
