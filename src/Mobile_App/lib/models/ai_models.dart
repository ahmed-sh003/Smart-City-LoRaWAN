class AnomalyResult {
  final bool isAnomaly;
  final double anomalyScore;
  final String anomalyType;
  final double confidence;
  final String explanation;
  final List<String> affectedFeatures;
  final DateTime analyzedAt;

  const AnomalyResult({
    required this.isAnomaly,
    required this.anomalyScore,
    required this.anomalyType,
    required this.confidence,
    required this.explanation,
    required this.affectedFeatures,
    required this.analyzedAt,
  });

  factory AnomalyResult.normal(
      {String explanation =
          'Current readings are stable and do not show a clear anomaly pattern.'}) {
    return AnomalyResult(
      isAnomaly: false,
      anomalyScore: 0.08,
      anomalyType: 'normal',
      confidence: 0.82,
      explanation: explanation,
      affectedFeatures: const [],
      analyzedAt: DateTime.now(),
    );
  }

  factory AnomalyResult.fromJson(Map<String, dynamic> json) {
    return AnomalyResult(
      isAnomaly: json['isAnomaly'] == true,
      anomalyScore: _double(json['anomalyScore']),
      anomalyType: (json['anomalyType'] ?? 'normal').toString(),
      confidence: _double(json['confidence']),
      explanation: (json['explanation'] ?? '').toString(),
      affectedFeatures: _stringList(json['affectedFeatures']),
      analyzedAt: DateTime.tryParse((json['analyzedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAnomaly': isAnomaly,
      'anomalyScore': anomalyScore,
      'anomalyType': anomalyType,
      'confidence': confidence,
      'explanation': explanation,
      'affectedFeatures': affectedFeatures,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }
}

class MaintenancePrediction {
  final bool willFailIn24h;
  final bool willFailIn48h;
  final double failureProbability;
  final String recommendedAction;
  final String urgencyLevel;
  final List<String> riskFactors;
  final DateTime analyzedAt;

  const MaintenancePrediction({
    required this.willFailIn24h,
    required this.willFailIn48h,
    required this.failureProbability,
    required this.recommendedAction,
    required this.urgencyLevel,
    required this.riskFactors,
    required this.analyzedAt,
  });

  factory MaintenancePrediction.lowRisk() {
    return MaintenancePrediction(
      willFailIn24h: false,
      willFailIn48h: false,
      failureProbability: 0.12,
      recommendedAction:
          'Continue routine monitoring; no urgent maintenance action is needed.',
      urgencyLevel: 'low',
      riskFactors: const [],
      analyzedAt: DateTime.now(),
    );
  }

  factory MaintenancePrediction.fromJson(Map<String, dynamic> json) {
    return MaintenancePrediction(
      willFailIn24h: json['willFailIn24h'] == true,
      willFailIn48h: json['willFailIn48h'] == true,
      failureProbability: _double(json['failureProbability']),
      recommendedAction: (json['recommendedAction'] ?? '').toString(),
      urgencyLevel: (json['urgencyLevel'] ?? 'low').toString(),
      riskFactors: _stringList(json['riskFactors']),
      analyzedAt: DateTime.tryParse((json['analyzedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'willFailIn24h': willFailIn24h,
      'willFailIn48h': willFailIn48h,
      'failureProbability': failureProbability,
      'recommendedAction': recommendedAction,
      'urgencyLevel': urgencyLevel,
      'riskFactors': riskFactors,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }
}

class AlertScore {
  final int severityLevel;
  final String severityLabel;
  final double confidenceScore;
  final bool requiresImmediateAction;
  final String suggestedResponse;

  const AlertScore({
    required this.severityLevel,
    required this.severityLabel,
    required this.confidenceScore,
    required this.requiresImmediateAction,
    required this.suggestedResponse,
  });

  bool get requiresImmedateAction => requiresImmediateAction;

  factory AlertScore.info() {
    return const AlertScore(
      severityLevel: 1,
      severityLabel: 'info',
      confidenceScore: 0.72,
      requiresImmediateAction: false,
      suggestedResponse: 'Review this alert during normal operations.',
    );
  }

  factory AlertScore.fromJson(Map<String, dynamic> json) {
    return AlertScore(
      severityLevel: _int(json['severityLevel']),
      severityLabel: (json['severityLabel'] ?? 'info').toString(),
      confidenceScore: _double(json['confidenceScore']),
      requiresImmediateAction: json['requiresImmediateAction'] == true ||
          json['requiresImmedateAction'] == true,
      suggestedResponse: (json['suggestedResponse'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'severityLevel': severityLevel,
      'severityLabel': severityLabel,
      'confidenceScore': confidenceScore,
      'requiresImmediateAction': requiresImmediateAction,
      'suggestedResponse': suggestedResponse,
    };
  }
}

class SignalPrediction {
  final double predictedRssi;
  final double predictedSnr;
  final String signalQuality;
  final String recommendation;
  final DateTime analyzedAt;

  const SignalPrediction({
    required this.predictedRssi,
    required this.predictedSnr,
    required this.signalQuality,
    required this.recommendation,
    required this.analyzedAt,
  });

  factory SignalPrediction.fromJson(Map<String, dynamic> json) {
    return SignalPrediction(
      predictedRssi: _double(json['predictedRssi']),
      predictedSnr: _double(json['predictedSnr']),
      signalQuality: (json['signalQuality'] ?? 'fair').toString(),
      recommendation: (json['recommendation'] ?? '').toString(),
      analyzedAt: DateTime.tryParse((json['analyzedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predictedRssi': predictedRssi,
      'predictedSnr': predictedSnr,
      'signalQuality': signalQuality,
      'recommendation': recommendation,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }
}

class AnomalyHistoryPoint {
  final DateTime timestamp;
  final String nodeId;
  final String domain;
  final double score;

  const AnomalyHistoryPoint({
    required this.timestamp,
    required this.nodeId,
    required this.domain,
    required this.score,
  });
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}
