import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AiTfliteBackend {
  Interpreter? _productionAnomalyInterpreter;

  bool get hasLoadedModels => _productionAnomalyInterpreter != null;

  Future<void> load(Map<String, dynamic> config) async {
    if (_productionAnomalyInterpreter != null) return;
    if (!_hasDesktopRuntime()) {
      debugPrint(
          'TFLite desktop runtime is not bundled; using fallback AI scoring.');
      return;
    }
    final models = config['models'];
    final configuredPath = models is Map ? models['production_anomaly'] : null;
    final candidates = {
      if (configuredPath != null) configuredPath.toString(),
      'assets/ml_models/production_model.tflite',
      'ml_models/production_model.tflite',
      'production_model.tflite',
    };
    for (final asset in candidates) {
      try {
        _productionAnomalyInterpreter = await Interpreter.fromAsset(asset);
        debugPrint('Loaded production anomaly TFLite model: $asset');
        return;
      } catch (error) {
        debugPrint('TFLite load skipped for $asset: $error');
      }
    }
  }

  bool _hasDesktopRuntime() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    if (Platform.isWindows) {
      return File('${executableDir.path}/blobs/libtensorflowlite_c-win.dll')
          .existsSync();
    }
    if (Platform.isLinux) {
      return File('${executableDir.path}/blobs/libtensorflowlite_c-linux.so')
          .existsSync();
    }
    if (Platform.isMacOS) {
      return File(
        '${executableDir.parent.path}/resources/libtensorflowlite_c-mac.dylib',
      ).existsSync();
    }
    return true;
  }

  Future<double?> runAnomalyModel({
    required String domain,
    required List<List<double>> sequence,
  }) async {
    final interpreter = _productionAnomalyInterpreter;
    if (interpreter == null || sequence.isEmpty) return null;
    try {
      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);
      final inputShape = input.shape;
      final outputShape = output.shape;
      final featureCount =
          inputShape.isNotEmpty ? inputShape.last : sequence.last.length;
      final inputData = [_fitLatestRow(sequence, featureCount)];
      final outputData = _zeros(outputShape);
      interpreter.run(inputData, outputData);
      final scores = <double>[];
      _flatten(outputData, scores);
      if (scores.isEmpty) return null;
      return scores.first.clamp(0.0, 1.0).toDouble();
    } catch (error) {
      debugPrint('TFLite inference failed for $domain: $error');
      return null;
    }
  }

  List<double> _fitLatestRow(
    List<List<double>> sequence,
    int featureCount,
  ) {
    final latest = sequence.last;
    final values = List<double>.filled(featureCount, 0);
    for (var i = 0; i < math.min(featureCount, latest.length); i++) {
      values[i] = latest[i].isFinite ? latest[i] : 0;
    }
    return values;
  }

  dynamic _zeros(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    if (shape.length == 1) {
      return List<double>.filled(shape.first, 0);
    }
    return List.generate(shape.first, (_) => _zeros(shape.sublist(1)));
  }

  void _flatten(dynamic value, List<double> output) {
    if (value is num) {
      output.add(value.toDouble());
    } else if (value is Iterable) {
      for (final item in value) {
        _flatten(item, output);
      }
    }
  }

  void dispose() {
    _productionAnomalyInterpreter?.close();
    _productionAnomalyInterpreter = null;
  }
}
