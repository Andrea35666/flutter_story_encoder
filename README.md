# flutter_story_encoder

A production-grade, hardware-accelerated video export engine for Flutter. Specifically designed for high-scale social media story editors requiring premium performance, thermal stability, and 4K capability.

[![pub package](https://img.shields.io/pub/v/flutter_story_encoder.svg)](https://pub.dev/packages/flutter_story_encoder)

## Features

- **Hardware Accelerated**: Uses iOS `AVFoundation` and Android `MediaCodec` with Surface input for native-speed encoding.
- **Zero-Copy Pipeline**: Optimized GPU-backed frame transfers on both platforms.
- **Thermal Stability**: Built-in backpressure management to prevent device overheating during long exports.
- **Deterministic Pacing**: Precise frame timestamping for professional-grade, jitter-free video output.
- **Type-Safe IPC**: Leverages Pigeon for efficient, compile-time safe communication between Dart and Native code.
- **Stats Streaming**: Real-time telemetry for frames processed, throughput (FPS), and progress.

## Platform Support

| Feature           | iOS (AVFoundation) | Android (MediaCodec) |
| ----------------- | :----------------: | :------------------: |
| Hardware Encoding |         ✅         |          ✅          |
| H.264 (AVC)       |         ✅         |          ✅          |
| High Profile 4.1  |         ✅         |          ✅          |
| 4K @ 60fps        |         ✅         |          ✅          |
| Silent Audio      |         ✅         |          ✅          |
| Backpressure      |         ✅         |          ✅          |

## Getting Started

### Installation

Add `flutter_story_encoder` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_story_encoder: ^1.1.5
```

### iOS Requirements

- **iOS 13.0+**
- Add following keys to `Info.plist` if you intend to save directly to library (optional for preview):

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need permission to save your stories.</string>
```

### Android Requirements

- **Min SDK 21+** (Lollipop)
- Recommended **Min SDK 24+** for stable 4K Surface encoding.

## Usage

### Simple Export

```dart
final bool started = await FlutterStoryEncoder.start(
  config: EncoderConfig(
    width: 1080,
    height: 1920,
    fps: 30,
    bitrate: 10000000, // 10 Mbps
    outputPath: '/path/to/output.mp4',
    addSilentAudio: true,
  ),
  onProgress: (stats) {
    print("Progress: ${stats.progress}% - FPS: ${stats.currentFps}");
  },
  onError: (msg, code) => print("Error [$code]: $msg"),
);

// Capture frames from a RepaintBoundary
final image = await boundary.toImage();
final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
await FlutterStoryEncoder.appendFrame(byteData.buffer.asUint8List());

final String? finalPath = await FlutterStoryEncoder.finish();
```

## Performance Tuning

For the best results in high-scale apps:

1. **Resolution**: Match your `RepaintBoundary` pixel ratio to the target resolution to avoid expensive software scaling.
2. **Bitrate**: 10-15 Mbps is recommended for 1080p high-quality stories.
3. **Pacing**: Use `Future.delayed(Duration.zero)` between frame captures to allow the Flutter UI thread to breathe.

## Technical Specifications

- **Video Codec**: H.264 / AVC
- **Audio Codec**: AAC (Silent track for compatibility)
- **Profile**: High Profile 4.1
- **Keyframe Interval**: 1 second
- **Rate Control**: VBR (Variable Bitrate) with target matching
- **Color Space**: BT.709

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
