import 'package:flutter/material.dart';
import 'camera_screen.dart';

class ExercisePreviewScreen extends StatelessWidget {
  const ExercisePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          },
          child: const Text("Start Exercise"),
        ),
      ),
    );
  }
}
