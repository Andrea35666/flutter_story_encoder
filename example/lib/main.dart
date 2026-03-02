import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_story_encoder/flutter_story_encoder.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_story_encoder Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const EncoderExample(),
    );
  }
}

/// Example page demonstrating the flutter_story_encoder plugin.
///
/// This page shows how to:
/// 1. Declare a [RepaintBoundary] around the content to export.
/// 2. Start the encoder with [FlutterStoryEncoder.start].
/// 3. Capture frames with [RenderRepaintBoundary.toImage].
/// 4. Append raw RGBA frames with [FlutterStoryEncoder.appendFrame].
/// 5. Finalize the export with [FlutterStoryEncoder.finish].
class EncoderExample extends StatefulWidget {
  const EncoderExample({super.key});

  @override
  State<EncoderExample> createState() => _EncoderExampleState();
}

class _EncoderExampleState extends State<EncoderExample>
    with SingleTickerProviderStateMixin {
  // Key to reference the RepaintBoundary widget.
  final GlobalKey _repaintKey = GlobalKey();

  String _status = 'Ready';
  double _progress = 0.0;
  bool _isEncoding = false;
  String? _outputPath;

  late AnimationController _animController;
  late Animation<Color?> _colorAnimation;

  static const int _totalFrames = 60;
  static const int _width = 1080;
  static const int _height = 1920;
  static const double _fps = 30.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _colorAnimation = ColorTween(
      begin: Colors.deepPurple,
      end: Colors.orange,
    ).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startEncoding() async {
    if (_isEncoding) return;
    setState(() {
      _isEncoding = true;
      _progress = 0.0;
      _outputPath = null;
      _status = 'Initializing...';
    });

    final directory = await getTemporaryDirectory();
    final outputPath = '${directory.path}/example_story.mp4';

    final started = await FlutterStoryEncoder.start(
      config: EncoderConfig(
        width: _width,
        height: _height,
        fps: _fps.toInt(),
        bitrate: 10000000, // 10 Mbps
        outputPath: outputPath,
        addSilentAudio: true,
      ),
      onProgress: (EncodingStats stats) {
        if (mounted) {
          setState(() {
            _progress = stats.framesProcessed / _totalFrames;
            _status =
                'Encoding... ${stats.framesProcessed}/$_totalFrames frames '
                '(${stats.currentFps.toStringAsFixed(1)} fps)';
          });
        }
      },
      onError: (String msg, String code) {
        if (mounted) setState(() => _status = 'Error [$code]: $msg');
      },
    );

    if (!started) {
      setState(() {
        _status = 'Failed to start encoder.';
        _isEncoding = false;
      });
      return;
    }

    // Append frames captured from the RepaintBoundary.
    for (int i = 0; i < _totalFrames; i++) {
      // Capture the widget tree as a raw image.
      final RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary != null) {
        // Best Practice: Capture at exact target dimensions to avoid stride/padding issues.
        final double pixelRatio = _width / boundary.size.width;
        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData != null) {
          final accepted = await FlutterStoryEncoder.appendFrame(
            byteData.buffer.asUint8List(),
          );
          if (!accepted) {
            // Backpressure: yield and retry.
            await Future<void>.delayed(const Duration(milliseconds: 16));
            i--;
            continue;
          }
        }
      } else {
        // Fallback: append a blank RGBA frame.
        final frame = Uint8List(_width * _height * 4);
        await FlutterStoryEncoder.appendFrame(frame);
      }

      // Yield to the UI thread between frames.
      await Future<void>.delayed(Duration.zero);
    }

    final path = await FlutterStoryEncoder.finish();
    setState(() {
      _isEncoding = false;
      _outputPath = path;
      _status = path != null ? 'Done!' : 'Encoding failed.';
      _progress = 1.0;
    });
  }

  Future<void> _cancel() async {
    await FlutterStoryEncoder.cancel();
    setState(() {
      _isEncoding = false;
      _status = 'Cancelled';
      _progress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Encoder Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // ── Content that will be encoded ──────────────────────────────
          RepaintBoundary(
            key: _repaintKey,
            child: AnimatedBuilder(
              animation: _colorAnimation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: 300,
                  color: _colorAnimation.value,
                  child: const Center(
                    child: Text(
                      '🎬 Story Frame',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ── Controls ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 24),
                if (!_isEncoding)
                  FilledButton.icon(
                    onPressed: _startEncoding,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Encode 60 Frames'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _cancel,
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancel'),
                  ),
                if (_outputPath != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Output path:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _outputPath!,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
