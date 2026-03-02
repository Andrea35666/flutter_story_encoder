import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_story_encoder/flutter_story_encoder.dart';
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

      // Default stubbing for Mockito
      when(mockApi.start(any)).thenAnswer((_) async => true);
      when(mockApi.appendFrame(any)).thenAnswer((_) async => true);
      when(mockApi.finish()).thenAnswer((_) async => 'test.mp4');

      // Set up the mock binary messenger handler for Pigeon host API calls
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

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            'dev.flutter.pigeon.flutter_story_encoder.StoryEncoderHostApi.appendFrame',
            (ByteData? message) async {
              final List<Object?> args =
                  StoryEncoderHostApi.pigeonChannelCodec.decodeMessage(message!)
                      as List<Object?>;
              final Uint8List data = args[0] as Uint8List;
              final result = await mockApi.appendFrame(data);
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

      final result = await FlutterStoryEncoder.start(config: config);
      expect(result, isTrue);
      verify(
        mockApi.start(
          argThat(
            isA<EncoderConfig>()
                .having((c) => c.width, 'width', 1080)
                .having((c) => c.height, 'height', 1920),
          ),
        ),
      ).called(1);
    });

    test('start throws ArgumentError for odd dimensions', () async {
      final config = EncoderConfig(
        width: 1081,
        height: 1920,
        fps: 30,
        bitrate: 10000000,
        outputPath: 'test.mp4',
        addSilentAudio: true,
      );

      expect(
        () => FlutterStoryEncoder.start(config: config),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must be even'),
          ),
        ),
      );
    });

    test('start throws ArgumentError for non-positive values', () async {
      final config = EncoderConfig(
        width: 1080,
        height: 0,
        fps: 30,
        bitrate: 10000000,
        outputPath: 'test.mp4',
        addSilentAudio: true,
      );

      expect(
        () => FlutterStoryEncoder.start(config: config),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must be positive'),
          ),
        ),
      );
    });

    test('appendFrame calls native and returns true', () async {
      final data = Uint8List(10);
      final result = await FlutterStoryEncoder.appendFrame(data);
      expect(result, isTrue);
      verify(mockApi.appendFrame(data)).called(1);
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
