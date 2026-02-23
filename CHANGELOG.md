## 1.1.5

- iOS: Switched Pigeon to Swift generation to resolve scope visibility issues.
- iOS: Fixed `CMSampleBufferCreateReady` parameters for silent audio generation.
- iOS: Improved error handling by using `PigeonError` for better type compatibility.

## 1.1.4

- **Android Hotfix**: Fixed `IllegalStateException: Can't write, muxer is not started` by implementing track synchronization and muxer lifecycle safeguards.
- **Improved Stability**: Ensured that video and audio tracks are fully registered before the muxer begins writing sample data.

## 1.1.3

- **Android Hotfix**: Fixed unresolved `program` and `textureId` references in `OpenGLRenderer.kt`.
- **Android Gradle Hotfix**: Added `settings.gradle` to give the plugin's Android project a unique name, resolving IDE project collisions.
- **Unit Tests**: Corrected Pigeon mock implementation and fixed missing imports in `flutter_story_encoder_test.dart`.

## 1.1.2

- **iOS Hotfix**: Fixed color channel swap (Blue/Red) when encoding from Flutter raw RGBA frames.
- **iOS Stability**: Fixed potential crash by resetting memory pools between encoding sessions.
- **Android Performance**: Optimized silent audio track generation by reusing zero-buffers.

## 1.1.1

- **Android Optimization**: Implemented buffer reuse in `OpenGLRenderer` to eliminate frame-level allocations and reduce GC pressure during high-resolution exports.
- **Improved Lifecycle**: Properly shut down background executor on Android when plugin is detached.

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
