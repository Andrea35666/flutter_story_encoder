## 1.1.0

- **Commercial Grade Release**: Refactored both platforms for hardware-accelerated production use.
- **Audio Support**: Added silent AAC audio track generation on iOS (AVFoundation) and Android (MediaCodec).
- **iOS (AVFoundation)**: Implemented `CVPixelBufferPool` and `requestMediaDataWhenReady` for zero-allocation, thermal-stable encoding.
- **Android (MediaCodec)**: Switched to Surface-based input with EGL/OpenGL ES for GPU-backed encoding.
- **Improved API**: Migrated to Pigeon for type-safe, high-throughput IPC.
- **Unified Telemetry**: Real-time stats (FPS, frames processed) streamed back to Flutter.

- Fixed Android `@UiThread` exception by ensuring progress updates and completion callbacks run on the main thread.

## 1.0.3

- Renamed Android package to `com.lucasveneno.flutter_story_encoder`.

## 1.0.2

- Fixed Android Kotlin compilation error ("Property must be initialized").

## 1.0.1

- Updated repository metadata and documentation.

## 1.0.0

- Initial release of the high-performance video export engine.
- Type-safe IPC implementation using Pigeon.
- iOS: Hardware-accelerated pipeline with `AVAssetWriter` and `CVPixelBufferPool`.
- Android: GPU-backed `MediaCodec` Surface encoding with EGL/OpenGL renderer.
- Real-time encoding statistics and progress callbacks.
- Support for 1080p and 4K @ 30/60fps.
- Thermal stability and backpressure management.
