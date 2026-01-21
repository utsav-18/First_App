import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'tflite_inference.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late PoseDetector _poseDetector;

  bool _processing = false;
  bool _ready = false;

  double? _prevLeftElbow;
  double? _prevRightElbow;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await StrokeRecoveryModel.loadModel();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    _controller = CameraController(
      cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      ),
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller.initialize();
    await _controller.startImageStream(_processCameraImage);

    setState(() => _ready = true);
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = width * height ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    int offset = 0;

    for (int row = 0; row < height; row++) {
      nv21.setRange(
        offset,
        offset + width,
        image.planes[0].bytes,
        row * image.planes[0].bytesPerRow,
      );
      offset += width;
    }

    final u = image.planes[1];
    final v = image.planes[2];

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        nv21[offset++] =
            v.bytes[row * v.bytesPerRow + col * v.bytesPerPixel!];
        nv21[offset++] =
            u.bytes[row * u.bytesPerRow + col * u.bytesPerPixel!];
      }
    }

    return nv21;
  }

  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ab = Point(a.x - b.x, a.y - b.y);
    final cb = Point(c.x - b.x, c.y - b.y);
    final dot = ab.x * cb.x + ab.y * cb.y;
    final mag = sqrt(ab.x * ab.x + ab.y * ab.y) *
        sqrt(cb.x * cb.x + cb.y * cb.y);
    return acos(dot / mag) * 180 / pi;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processing) return;
    _processing = true;

    try {
      final inputImage = InputImage.fromBytes(
        bytes: _yuv420ToNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;

        final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
        final le = pose.landmarks[PoseLandmarkType.leftElbow];
        final lw = pose.landmarks[PoseLandmarkType.leftWrist];

        final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
        final re = pose.landmarks[PoseLandmarkType.rightElbow];
        final rw = pose.landmarks[PoseLandmarkType.rightWrist];

        if (ls != null && le != null && lw != null) {
          final leftElbow = _angle(ls, le, lw);
          final rightElbow =
              (rs != null && re != null && rw != null)
                  ? _angle(rs, re, rw)
                  : 0.0;

          final leftDelta =
              _prevLeftElbow == null ? 0 : (leftElbow - _prevLeftElbow!).abs();
          final rightDelta =
              _prevRightElbow == null ? 0 : (rightElbow - _prevRightElbow!).abs();

          _prevLeftElbow = leftElbow;
          _prevRightElbow = rightElbow;

final input = <double>[
  leftElbow / 180,
  rightElbow / 180,
  leftDelta / 180,
  rightDelta / 180,
  (leftElbow - rightElbow).abs() / 180,

  // padding to 18
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0,
];


final result = StrokeRecoveryModel.run(input);

print('📊 Scores: ${result['scores']}');
print('🏷️ Predicted Class: ${result['class']}');
        }
      }
    } catch (e) {
      print('⚠️ Error: $e');
    }

    _processing = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    _poseDetector.close();
    StrokeRecoveryModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(body: CameraPreview(_controller));
  }
}
