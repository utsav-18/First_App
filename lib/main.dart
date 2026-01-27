import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/tflite_inference.dart';

Future<void> main() async {
  // ✅ Required for async work before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Load TFLite model once at app start
  await StrokeRecoveryModel.loadModel();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stroke Recovery',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}
