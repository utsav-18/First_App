import 'package:tflite_flutter/tflite_flutter.dart';

class StrokeRecoveryModel {
  static Interpreter? _interpreter;
  static late List<int> _inputShape;
  static late List<int> _outputShape;

  static Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/stroke_recovery_classifier.tflite',
    );

    _inputShape = _interpreter!.getInputTensor(0).shape;
    _outputShape = _interpreter!.getOutputTensor(0).shape;

    print('✅ Model loaded');
    print('📥 Input shape: $_inputShape');
    print('📤 Output shape: $_outputShape'); // should be [1,3]
  }

  /// Returns:
  /// {
  ///   "class": int (0,1,2),
  ///   "scores": List<double>
  /// }
  static Map<String, dynamic> run(List<double> features) {
    if (_interpreter == null) {
      throw Exception('Interpreter not initialized');
    }

    final expectedSize = _inputShape.reduce((a, b) => a * b);
    if (features.length != expectedSize) {
      throw Exception(
        'Input size mismatch. Expected $expectedSize values, got ${features.length}',
      );
    }

    final input = features.reshape(_inputShape);

    final output = List.generate(
      _outputShape[0],
      (_) => List.filled(_outputShape[1], 0.0),
    );

    _interpreter!.run(input, output);

    final scores = List<double>.from(output[0]);

    int predictedClass = 0;
    double maxScore = scores[0];

    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        predictedClass = i;
      }
    }

    return {
      'class': predictedClass,
      'scores': scores,
    };
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    print('🧹 Model disposed');
  }
}
