import 'package:flutter/material.dart';
import 'exercise_library_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Role")),
      body: Column(
        children: [
          _roleTile(context, "Patient"),
          _roleTile(context, "Doctor"),
          _roleTile(context, "Caregiver"),
        ],
      ),
    );
  }

  Widget _roleTile(BuildContext context, String role) {
    return ListTile(
      title: Text(role),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ExerciseLibraryScreen(),
          ),
        );
      },
    );
  }
}
