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
class EncoderConfig {
  late int width;
  late int height;
  late int fps;
  late int bitrate;
  late String outputPath;
  late bool addSilentAudio;
}

class EncodingStats {
  late int framesProcessed;
  late double currentFps;
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
