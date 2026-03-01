import FlutterMacOS
import AppKit
import AVFoundation

public class FlutterStoryEncoderPlugin: NSObject, FlutterMacOSPlugin, StoryEncoderHostApi {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var pixelBufferPool: CVPixelBufferPool?
    
    private var frameTime: CMTime = .zero
    private var audioTime: CMTime = .zero
    private var isEncoding = false
    private let queue = DispatchQueue(label: "com.lucasveneno.flutter_story_encoder.macos.queue")
    
    private var flutterApi: StoryEncoderFlutterApi?
    private var config: EncoderConfig?
    private var framesProcessed: Int64 = 0
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterStoryEncoderPlugin()
        StoryEncoderHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
        instance.flutterApi = StoryEncoderFlutterApi(binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(instance, channel: FlutterMethodChannel(name: "flutter_story_encoder_macos", binaryMessenger: registrar.messenger))
    }
    
    public func start(config: EncoderConfig, completion: @escaping (Result<Bool, Error>) -> Void) {
        queue.async {
            self._start(config: config, completion: completion)
        }
    }
    
    private func _start(config: EncoderConfig, completion: @escaping (Result<Bool, Error>) -> Void) {
        self.config = config
        self.framesProcessed = 0
        self.pixelBufferPool = nil
        self.frameTime = .zero
        self.audioTime = .zero
        
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
            
            if config.addSilentAudio {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44100.0,
                    AVEncoderBitRateKey: 128000
                ]
                audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput?.expectsMediaDataInRealTime = false
            }
            
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
            
            if let audioInput = audioInput, assetWriter!.canAdd(audioInput) {
                assetWriter!.add(audioInput)
            }
            
            if assetWriter!.startWriting() {
                assetWriter!.startSession(atSourceTime: .zero)
                isEncoding = true
                completion(.success(true))
            } else {
                let error = PigeonError(code: "START_FAILED", message: assetWriter?.error?.localizedDescription ?? "Unknown", details: nil)
                completion(.failure(error))
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
                completion(.success(false))
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
            let error = PigeonError(code: "POOL_ERROR", message: "Memory pool expansion failed", details: nil)
            completion(.failure(error))
            return
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let rawPointer = pointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let bgrPointer = baseAddress!.assumingMemoryBound(to: UInt8.self)
            
            for i in stride(from: 0, to: data.count, by: 4) {
                bgrPointer[i] = rawPointer[i + 2]     // Blue
                bgrPointer[i + 1] = rawPointer[i + 1] // Green
                bgrPointer[i + 2] = rawPointer[i]     // Red
                bgrPointer[i + 3] = rawPointer[i + 3] // Alpha
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        if adaptor.append(buffer, withPresentationTime: frameTime) {
            framesProcessed += 1
            let fps = config?.fps ?? 30
            frameTime = CMTimeAdd(frameTime, CMTime(value: 1, timescale: Int32(fps)))
            
            if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                self.appendSilentAudio(until: self.frameTime)
            }
            
            let stats = EncodingStats(framesProcessed: framesProcessed, currentFps: Double(fps), progress: 0.0)
            DispatchQueue.main.async {
                self.flutterApi?.onProgress(stats: stats) { _ in }
            }
            completion(.success(true))
        } else {
            let error = PigeonError(code: "APPEND_FAILED", message: assetWriter?.error?.localizedDescription ?? "Unknown", details: nil)
            completion(.failure(error))
        }
    }
    
    private func appendSilentAudio(until pts: CMTime) {
        guard let audioInput = audioInput else { return }
        
        while audioTime < pts && audioInput.isReadyForMoreMediaData {
            let samplesCount = 1024
            let duration = CMTime(value: CMTimeValue(samplesCount), timescale: 44100)
            
            var blockBuffer: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: samplesCount * 2 * 2,
                blockAllocator: nil,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: samplesCount * 2 * 2,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            
            var sampleBuffer: CMSampleBuffer?
            var formatDesc: CMAudioFormatDescription?
            var asbd = AudioStreamBasicDescription(
                mSampleRate: 44100.0,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4,
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,
                mChannelsPerFrame: 2,
                mBitsPerChannel: 16,
                mReserved: 0
            )
            CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc)
            
            CMSampleBufferCreateReady(
                allocator: kCFAllocatorDefault,
                dataBuffer: blockBuffer,
                formatDescription: formatDesc,
                sampleCount: samplesCount,
                sampleTimingEntryCount: 0,
                sampleTimingArray: nil,
                sampleSizeEntryCount: 0,
                sampleSizeArray: nil,
                sampleBufferOut: &sampleBuffer
            )
            
            if let sampleBuffer = sampleBuffer {
                audioInput.append(sampleBuffer)
                audioTime = CMTimeAdd(audioTime, duration)
            }
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
                    let error = PigeonError(code: "FINISH_FAILED", message: self.assetWriter?.error?.localizedDescription ?? "Unknown", details: nil)
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func cancel() throws {
        queue.async {
            self.isEncoding = false
            self.assetWriter?.cancelWriting()
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterMethodNotImplemented)
    }
}
