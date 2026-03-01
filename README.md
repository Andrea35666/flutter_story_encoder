# flutter_story_encoder

A high-performance, hardware-accelerated video encoding engine for Flutter stories. Supporting 4K and thermal stability.

[![pub package](https://img.shields.io/pub/v/flutter_story_encoder.svg)](https://pub.dev/packages/flutter_story_encoder)

## Features

- **Hardware Accelerated** — Uses `AVFoundation` on iOS/macOS and `MediaCodec` on Android for native-speed encoding.
- **Zero-Copy Pipeline** — Optimized GPU-backed frame transfers on all platforms.
- **Thermal Stability** — Built-in backpressure management to prevent device overheating during long exports.
- **Deterministic Pacing** — Precise frame timestamping for professional-grade, jitter-free video output.
- **Type-Safe IPC** — Leverages [Pigeon](https://pub.dev/packages/pigeon) for compile-time safe communication between Dart and native code.
- **Stats Streaming** — Real-time telemetry: frames processed, throughput (FPS), and progress.
- **Silent Audio Track** — Optional AAC silent audio for universal video player compatibility.

## Platform Support

| Feature           | iOS | macOS | Android |
| ----------------- | :-: | :---: | :-----: |
| Hardware Encoding | ✅  |  ✅   |   ✅    |
| H.264 (AVC)       | ✅  |  ✅   |   ✅    |
| 4K @ 60fps        | ✅  |  ✅   |   ✅    |
| Silent Audio      | ✅  |  ✅   |   ✅    |
| Backpressure      | ✅  |  ✅   |   ✅    |
| SPM Support       | ✅  |  ✅   |    —    |

## Getting Started

### Installation

```yaml
dependencies:
  flutter_story_encoder: ^1.1.6
```

### iOS Requirements

- **iOS 13.0+**
- Optional — add to `Info.plist` if saving to the photo library:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need permission to save your stories.</string>
```

### macOS Requirements

- **macOS 11.0+**

### Android Requirements

- **Min SDK 21** (Lollipop). Recommended **Min SDK 24+** for stable 4K Surface encoding.

## Usage

### 1. Start the encoder

```dart
import 'package:flutter_story_encoder/flutter_story_encoder.dart';

final bool started = await FlutterStoryEncoder.start(
  config: EncoderConfig(
    width: 1080,
    height: 1920,
    fps: 30,
    bitrate: 10000000, // 10 Mbps
    outputPath: '/path/to/output.mp4',
    addSilentAudio: true,
  ),
  onProgress: (EncodingStats stats) {
    print('FPS: ${stats.currentFps} | Frames: ${stats.framesProcessed}');
  },
  onError: (msg, code) => print('Error [$code]: $msg'),
);
```

### 2. Append frames

Capture frames from a `RepaintBoundary` and feed them to the encoder:

```dart
import 'dart:ui' as ui;

final RenderRepaintBoundary boundary =
    key.currentContext!.findRenderObject() as RenderRepaintBoundary;

final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
final ByteData? byteData =
    await image.toByteData(format: ui.ImageByteFormat.rawRgba);

if (byteData != null) {
  await FlutterStoryEncoder.appendFrame(byteData.buffer.asUint8List());
}
```

### 3. Finish and get the output path

```dart
final String? outputPath = await FlutterStoryEncoder.finish();
print('Video saved to: $outputPath');
```

### 4. Cancel (optional)

```dart
await FlutterStoryEncoder.cancel();
```

## API Reference

### `EncoderConfig`

| Property         | Type     | Description                                          |
| ---------------- | -------- | ---------------------------------------------------- |
| `width`          | `int`    | Target video width in pixels.                        |
| `height`         | `int`    | Target video height in pixels.                       |
| `fps`            | `int`    | Frames per second (e.g. 30 or 60).                   |
| `bitrate`        | `int`    | Target bitrate in bits/s (e.g. `10000000` = 10Mbps). |
| `outputPath`     | `String` | Absolute file path for the output `.mp4` file.       |
| `addSilentAudio` | `bool`   | Adds a silent AAC audio track for compatibility.     |

### `EncodingStats`

| Property          | Type     | Description                         |
| ----------------- | -------- | ----------------------------------- |
| `framesProcessed` | `int`    | Number of frames encoded so far.    |
| `currentFps`      | `double` | Current encoding throughput in FPS. |
| `progress`        | `double` | Overall progress (0.0 – 1.0).       |

## Performance Tips

1. **Match resolution**: Set the `RepaintBoundary` pixel ratio to match the target resolution to avoid software scaling.
2. **Bitrate**: 10–15 Mbps recommended for 1080p high-quality stories.
3. **Yield between frames**: Use `await Future.delayed(Duration.zero)` between frame captures to keep the UI thread responsive.

## Technical Specifications

| Property          | Value                  |
| ----------------- | ---------------------- |
| Video Codec       | H.264 / AVC            |
| Audio Codec       | AAC (silent track)     |
| Profile           | High Profile 4.1       |
| Keyframe Interval | 1 second               |
| Rate Control      | VBR (Variable Bitrate) |
| Color Space       | BT.709                 |
| IPC Layer         | Pigeon (type-safe)     |

## License

MIT — see [LICENSE](LICENSE) for details.
