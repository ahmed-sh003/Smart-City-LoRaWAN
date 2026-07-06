import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/mlops_models.dart';

class MlopsReportService {
  const MlopsReportService();

  Future<MlopsSummary> loadSummary() async {
    try {
      final raw =
          await rootBundle.loadString('assets/ml_models/mlops_summary.json');
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return MlopsSummary.fromJson(json);
      }
      if (json is Map) {
        return MlopsSummary.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {
      return MlopsSummary.fallback();
    }
    return MlopsSummary.fallback();
  }
}
