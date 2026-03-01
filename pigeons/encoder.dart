import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon.g.dart',
    dartTestOut: 'test/pigeon.g.dart',
    swiftOut: 'ios/Classes/Pigeon.g.swift',
    kotlinOut:
        'android/src/main/kotlin/com/lucasveneno/flutter_story_encoder/Pigeon.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.lucasveneno.flutter_story_encoder',
    ),
  ),
)
/// Configuration parameters for the video encoder.
class EncoderConfig {
  /// The target width of the exported video.
  late int width;

  /// The target height of the exported video.
  late int height;

  /// Target frames per second (e.g., 30 or 60).
  late int fps;

  /// Target bitrate in bits per second (e.g., 10,000,000 for 10 Mbps).
  late int bitrate;

  /// The destination path for the encoded MP4 file.
  late String outputPath;

  /// Whether to include a silent AAC audio track for broader compatibility.
  late bool addSilentAudio;
}

/// Real-time statistics produced during the encoding process.
class EncodingStats {
  /// Total number of frames successfully processed and written.
  late int framesProcessed;

  /// Current throughput of the encoder in frames per second.
  late double currentFps;

  /// Estimated progress of the encoding session (0.0 to 1.0).
  late double progress;
}

@HostApi()
abstract class StoryEncoderHostApi {
  @async
  bool start(EncoderConfig config);

  @async
  bool appendFrame(Uint8List rgbaData);

  @async
  String? finish();

  void cancel();
}

@FlutterApi()
abstract class StoryEncoderFlutterApi {
  void onProgress(EncodingStats stats);
  void onError(String message, String code);
}
