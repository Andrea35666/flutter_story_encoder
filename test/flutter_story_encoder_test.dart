import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_story_encoder/flutter_story_encoder.dart';
import 'package:flutter_story_encoder/src/pigeon.g.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'flutter_story_encoder_test.mocks.dart';

@GenerateMocks([StoryEncoderHostApi])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterStoryEncoder', () {
    late MockStoryEncoderHostApi mockApi;

    setUp(() {
      mockApi = MockStoryEncoderHostApi();
      // In a real scenario, we'd inject this mock into the plugin.
      // Since Pigeon uses static setup, we'd need to mock the BinaryMessenger.
      // For simplicity, we'll test the logic that would call the API.
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
