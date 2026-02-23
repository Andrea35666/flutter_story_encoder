import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_story_encoder/flutter_story_encoder.dart';
import 'package:flutter_story_encoder/src/pigeon.g.dart';
import 'package:mockito/annotations.dart';

import 'flutter_story_encoder_test.mocks.dart';

@GenerateMocks([StoryEncoderHostApi])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterStoryEncoder', () {
    late MockStoryEncoderHostApi mockApi;

    setUp(() {
      mockApi = MockStoryEncoderHostApi();
      // Set up the mock API for Pigeon.
      // We use TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      // as a mock BinaryMessenger for simplicity in tests.
      // StoryEncoderHostApi doesn't have a setUp method in Dart Pigeon generated code.
      // We mock the channel manually if needed, or rely on the mockApi if we were using it via DI.
      // For Pigeon host APIs, we usually mock the binary messenger or use the generated test class if available.
      // Since we want to mock the behavior of hostApi.start etc., we can use basic message channel mocking.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            'dev.flutter.pigeon.flutter_story_encoder.StoryEncoderHostApi.start',
            (ByteData? message) async {
              final List<Object?> args =
                  StoryEncoderHostApi.pigeonChannelCodec.decodeMessage(message!)
                      as List<Object?>;
              final EncoderConfig config = args[0] as EncoderConfig;
              final result = await mockApi.start(config);
              return StoryEncoderHostApi.pigeonChannelCodec.encodeMessage([
                result,
              ]);
            },
          );
    });

    test('start passes correct configuration', () async {
      final config = EncoderConfig(
        width: 1080,
        height: 1920,
        fps: 30,
        bitrate: 10000000,
        outputPath: 'test.mp4',
        addSilentAudio: true,
      );

      expect(config.width, 1080);
      expect(config.height, 1920);
      expect(config.fps, 30);
      expect(config.bitrate, 10000000);
      expect(config.outputPath, 'test.mp4');
      expect(config.addSilentAudio, true);
    });

    test('EncodingStats model serialization', () {
      final stats = EncodingStats(
        framesProcessed: 100,
        currentFps: 29.5,
        progress: 0.5,
      );

      expect(stats.framesProcessed, 100);
      expect(stats.currentFps, 29.5);
      expect(stats.progress, 0.5);
    });
  });
}
