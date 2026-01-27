import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'result_screen.dart';

late List<CameraDescription> cameras;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late PoseDetector _poseDetector;

  bool _ready = false;
  bool _processing = false;

  int _secondsLeft = 6;
  Timer? _timer;

  // ===== BASELINE (first ~1.5s) =====
  static const int BASELINE_FRAMES = 15;
  final List<double> _leftBaselineBuf = [];
  final List<double> _rightBaselineBuf = [];
  double? _baselineLeft;
  double? _baselineRight;

  // ===== DEVIATION =====
  double _leftDeviationSum = 0.0;
  double _rightDeviationSum = 0.0;
  int _deviationFrames = 0;

  // ===== THRESHOLDS (🔥 key to Improving) =====
  static const double NO_MOTION_MAX = 10.0;
  static const double IMPROVING_MAX = 22.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller.initialize();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    await _controller.startImageStream(_onFrame);

    if (!mounted) return;
    setState(() => _ready = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
        _finishSession();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  // ===== ANGLE =====
  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ab = Point(a.x - b.x, a.y - b.y);
    final cb = Point(c.x - b.x, c.y - b.y);
    final dot = ab.x * cb.x + ab.y * cb.y;
    final mag =
        sqrt(ab.x * ab.x + ab.y * ab.y) * sqrt(cb.x * cb.x + cb.y * cb.y);
    if (mag == 0) return 0.0;
    return acos(dot / mag) * 180 / pi;
  }

  Uint8List _toNV21(CameraImage img) {
    final ySize = img.width * img.height;
    final uvSize = img.width * img.height ~/ 2;
    final out = Uint8List(ySize + uvSize);
    int o = 0;

    for (int r = 0; r < img.height; r++) {
      out.setRange(
        o,
        o + img.width,
        img.planes[0].bytes,
        r * img.planes[0].bytesPerRow,
      );
      o += img.width;
    }

    final u = img.planes[1];
    final v = img.planes[2];

    for (int r = 0; r < img.height ~/ 2; r++) {
      for (int c = 0; c < img.width ~/ 2; c++) {
        out[o++] = v.bytes[r * v.bytesPerRow + c * v.bytesPerPixel!];
        out[o++] = u.bytes[r * u.bytesPerRow + c * u.bytesPerPixel!];
      }
    }
    return out;
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_processing) return;
    _processing = true;

    try {
      final input = InputImage.fromBytes(
        bytes: _toNV21(img),
        metadata: InputImageMetadata(
          size: Size(img.width.toDouble(), img.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: img.width,
        ),
      );

      final poses = await _poseDetector.processImage(input);
      if (poses.isEmpty) {
        _processing = false;
        return;
      }

      final p = poses.first;
      final ls = p.landmarks[PoseLandmarkType.leftShoulder];
      final le = p.landmarks[PoseLandmarkType.leftElbow];
      final lw = p.landmarks[PoseLandmarkType.leftWrist];
      final rs = p.landmarks[PoseLandmarkType.rightShoulder];
      final re = p.landmarks[PoseLandmarkType.rightElbow];
      final rw = p.landmarks[PoseLandmarkType.rightWrist];

      if (ls == null || le == null || lw == null ||
          rs == null || re == null || rw == null) {
        _processing = false;
        return;
      }

      final leftAngle = _angle(ls, le, lw);
      final rightAngle = _angle(rs, re, rw);

      // ===== BASELINE PHASE =====
      if (_baselineLeft == null || _baselineRight == null) {
        _leftBaselineBuf.add(leftAngle);
        _rightBaselineBuf.add(rightAngle);

        if (_leftBaselineBuf.length >= BASELINE_FRAMES) {
          _baselineLeft =
              _leftBaselineBuf.reduce((a, b) => a + b) / BASELINE_FRAMES;
          _baselineRight =
              _rightBaselineBuf.reduce((a, b) => a + b) / BASELINE_FRAMES;
        }

        _processing = false;
        return;
      }

      // ===== DEVIATION PHASE =====
      _leftDeviationSum += (leftAngle - _baselineLeft!).abs();
      _rightDeviationSum += (rightAngle - _baselineRight!).abs();
      _deviationFrames++;
    } catch (_) {}

    _processing = false;
  }

  Future<void> _finishSession() async {
    await _controller.stopImageStream();
    await _controller.dispose();
    _poseDetector.close();

    final avgLeftDev =
        _deviationFrames == 0 ? 0.0 : _leftDeviationSum / _deviationFrames;
    final avgRightDev =
        _deviationFrames == 0 ? 0.0 : _rightDeviationSum / _deviationFrames;

    // 🔥 auto-detect active arm
    final activeDev = max(avgLeftDev, avgRightDev);

    String finalResult;

    if (activeDev < NO_MOTION_MAX) {
      finalResult = "Not Improved";
    } else if (activeDev < IMPROVING_MAX) {
      finalResult = "Improving";
    } else {
      finalResult = "Improved";
    }

    // 🧪 one-time debug (optional)
    print("Left dev: $avgLeftDev");
    print("Right dev: $avgRightDev");
    print("Active dev: $activeDev");
    print("Result: $finalResult");

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: finalResult),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _ready
          ? Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  top: 40,
                  left: 20,
                  child: Text(
                    (_baselineLeft == null)
                        ? "Calibrating..."
                        : "Recording... $_secondsLeft s",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
