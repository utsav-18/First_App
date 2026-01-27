import 'package:flutter/material.dart';
import 'exercise_preview_screen.dart';

class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise Library")),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _exerciseCard(context, "Elbow Raise", "Upper Arm"),
          _exerciseCard(context, "Elbow Flexion", "Elbow Joint"),
        ],
      ),
    );
  }

  Widget _exerciseCard(
      BuildContext context, String title, String subtitle) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.play_circle),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ExercisePreviewScreen(),
            ),
          );
        },
      ),
    );
  }
}
