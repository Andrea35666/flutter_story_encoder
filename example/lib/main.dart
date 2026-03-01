import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_story_encoder/flutter_story_encoder.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: EncoderExample());
  }
}

class EncoderExample extends StatefulWidget {
  const EncoderExample({super.key});

  @override
  State<EncoderExample> createState() => _EncoderExampleState();
}

class _EncoderExampleState extends State<EncoderExample> {
  String _status = 'Idle';
  double _progress = 0.0;

  Future<void> _startEncoding() async {
    final directory = await getTemporaryDirectory();
    final outputPath = '${directory.path}/example_story.mp4';

    final success = await FlutterStoryEncoder.start(
      config: EncoderConfig(
        width: 1080,
        height: 1920,
        fps: 30,
        bitrate: 5000000,
        outputPath: outputPath,
        addSilentAudio: true,
      ),
      onProgress: (stats) {
        setState(() {
          _progress = stats.progress;
          _status = 'Encoding... ${(stats.progress * 100).toStringAsFixed(1)}%';
        });
      },
      onError: (msg, code) {
        setState(() => _status = 'Error: $msg');
      },
    );

    if (success) {
      // Simulate frame production
      for (int i = 0; i < 60; i++) {
        final frame = Uint8List(1080 * 1920 * 4); // Dummy RGBA data
        await FlutterStoryEncoder.appendFrame(frame);
      }

      final path = await FlutterStoryEncoder.finish();
      setState(() => _status = 'Finished: $path');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Story Encoder Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startEncoding,
              child: const Text('Start Dummy Encode'),
            ),
          ],
        ),
      ),
    );
  }
}
