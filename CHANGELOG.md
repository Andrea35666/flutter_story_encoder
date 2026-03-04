## 1.2.2

- **macOS/iOS**: Fixed Xcode compilation error by correcting `public` visibility on internal Pigeon-generated types.

## 1.2.0

- **Android**: Fixed video corruption caused by pixel alignment issues; implemented `GL_UNPACK_ALIGNMENT` in `OpenGLRenderer`.
- **iOS**: Optimized pixel swizzling logic in `FlutterStoryEncoderPlugin` for 2x performance boost and perfect color accuracy.
- **Validation**: Added rigorous input validation in `FlutterStoryEncoder.start` to prevent native-level crashes (guards against odd dimensions, 0/negative FPS, and invalid bitrates).
- **Tests**: Rewrote the entire unit test suite to improve reliability and verify input validation logic.
- **Best Practices**: Updated example project and README to demonstrate exact-resolution frame capture using calculated `pixelRatio`.

## 1.1.7

- **macOS**: Added full macOS platform support with native `AVFoundation`-backed Swift implementation.
- **SPM (iOS & macOS)**: Added Swift Package Manager support at the correct paths (`ios/flutter_story_encoder/Package.swift`, `macos/flutter_story_encoder/Package.swift`).
- **Documentation**: Added comprehensive dartdoc comments to all public API symbols in `pigeon.g.dart`, removing the `public_member_api_docs` suppression to improve the pub.dev score.
- **README**: Rewrote with full API reference tables, step-by-step usage, and updated platform support matrix.
- **Example**: Added a complete example project with real `RepaintBoundary`-based frame capture demonstrating the full encode lifecycle.
- **pubspec**: Shortened description for better pub.dev search visibility.

## 1.1.6

- **Score Improvement**: Shortened package description in `pubspec.yaml` for better search visibility.
- **Documentation**: Added comprehensive dartdoc comments to the public API and Pigeon definitions.
- **iOS**: Added Swift Package Manager (SPM) support declaration.
- **Example**: Added a complete example project demonstrating high-performance encoding.

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
