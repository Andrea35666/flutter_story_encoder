import 'package:flutter/services.dart';
import 'src/pigeon.g.dart';

export 'src/pigeon.g.dart';

class FlutterStoryEncoder implements StoryEncoderFlutterApi {
  static final FlutterStoryEncoder _instance = FlutterStoryEncoder._internal();
  static final StoryEncoderHostApi _hostApi = StoryEncoderHostApi();

  factory FlutterStoryEncoder() => _instance;

  FlutterStoryEncoder._internal() {
    StoryEncoderFlutterApi.setUp(this);
  }

  static Function(EncodingStats)? _onProgressCallback;
  static Function(String, String)? _onErrorCallback;

  /// Starts the high-performance encoding process.
  ///
  /// [config] defines the encoder parameters including bitrate, resolution, and output path.
  static Future<bool> start({
    required EncoderConfig config,
    Function(EncodingStats)? onProgress,
    Function(String, String)? onError,
  }) async {
    _onProgressCallback = onProgress;
    _onErrorCallback = onError;
    return await _hostApi.start(config);
  }

  /// Appends a raw RGBA frame to the encoder.
  ///
  /// This method is optimized for high-throughput and uses backpressure management
  /// on the native side. Returns false if the encoder is busy or not ready.
  static Future<bool> appendFrame(Uint8List rgbaData) async {
    return await _hostApi.appendFrame(rgbaData);
  }

  /// Finalizes the encoding process and returns the final file path.
  static Future<String?> finish() async {
    final path = await _hostApi.finish();
    _onProgressCallback = null;
    _onErrorCallback = null;
    return path;
  }

  /// Cancels the current encoding process and releases resources.
  static Future<void> cancel() async {
    await _hostApi.cancel();
    _onProgressCallback = null;
    _onErrorCallback = null;
  }

  @override
  void onProgress(EncodingStats stats) {
    _onProgressCallback?.call(stats);
  }

  @override
  void onError(String message, String code) {
    _onErrorCallback?.call(message, code);
  }
}
