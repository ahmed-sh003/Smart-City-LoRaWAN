class MlopsSummary {
  final DateTime generatedAt;
  final String modelVersion;
  final String status;
  final MlopsMonitoring monitoring;
  final MlopsDrift drift;
  final MlopsMetrics metrics;
  final MlopsExplainability explainability;
  final MlopsRegistry registry;
  final MlopsAbTesting abTesting;
  final MlopsTrainingInfo training;
  final MlopsEnterpriseSummary enterprise;
  final MlopsLpwanSummary lpwan;
  final List<String> recommendations;

  const MlopsSummary({
    required this.generatedAt,
    required this.modelVersion,
    required this.status,
    required this.monitoring,
    required this.drift,
    required this.metrics,
    required this.explainability,
    required this.registry,
    required this.abTesting,
    required this.training,
    required this.enterprise,
    required this.lpwan,
    required this.recommendations,
  });

  bool get needsAttention =>
      status == 'attention' || drift.overallStatus == 'high';
  bool get isHealthy => status == 'healthy' && drift.overallStatus == 'low';

  factory MlopsSummary.fromJson(Map<String, dynamic> json) {
    return MlopsSummary(
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()) ??
          DateTime.now(),
      modelVersion: (json['modelVersion'] ?? 'unknown').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      monitoring: MlopsMonitoring.fromJson(_map(json['monitoring'])),
      drift: MlopsDrift.fromJson(_map(json['drift'])),
      metrics: MlopsMetrics.fromJson(_map(json['metrics'])),
      explainability:
          MlopsExplainability.fromJson(_map(json['explainability'])),
      registry: MlopsRegistry.fromJson(_map(json['registry'])),
      abTesting: MlopsAbTesting.fromJson(_map(json['abTesting'])),
      training: MlopsTrainingInfo.fromJson(_map(json['training'])),
      enterprise: MlopsEnterpriseSummary.fromJson(_map(json['enterprise'])),
      lpwan: MlopsLpwanSummary.fromJson(_map(json['lpwan'])),
      recommendations: _stringList(json['recommendations']),
    );
  }

  factory MlopsSummary.fallback() {
    return MlopsSummary(
      generatedAt: DateTime.now(),
      modelVersion: 'unavailable',
      status: 'unavailable',
      monitoring: const MlopsMonitoring(
        backend: 'unavailable',
        inferenceCount: 0,
        averageScore: 0,
        p95Score: 0,
        threshold: 0.35,
        latencyMs: 0,
        errorRate: 1,
        predictionDistribution: {},
      ),
      drift: const MlopsDrift(
        overallStatus: 'unknown',
        featuresDrifted: 0,
        highDriftFeatures: 0,
        mediumDriftFeatures: 0,
        topFeatureDrift: [],
      ),
      metrics: const MlopsMetrics(
        accuracy: 0,
        precision: 0,
        recall: 0,
        f1: 0,
        brier: 0,
        ece: 0,
        confidenceMean: 0,
      ),
      explainability: const MlopsExplainability(
        method: 'unavailable',
        shapStatus: 'unavailable',
        topFeatures: [],
        topContributingFactors: [],
      ),
      registry: const MlopsRegistry(
        activeVersion: 'unregistered',
        path: 'not initialized',
        latestPath: 'not initialized',
      ),
      abTesting: const MlopsAbTesting(
        status: 'unavailable',
        activeVersion: 'unregistered',
        candidateVersion: '',
        decision: 'No MLOps summary asset was bundled.',
      ),
      training: const MlopsTrainingInfo(
        phase: 'Unavailable',
        trainingRows: 0,
        realRows: 0,
        syntheticRows: 0,
        realRatio: 0,
        featureCount: 0,
        datasetsUsed: {},
      ),
      enterprise: MlopsEnterpriseSummary.fallback(),
      lpwan: MlopsLpwanSummary.fallback(),
      recommendations: const [
        'Regenerate assets/ml_models/mlops_summary.json from scripts/mlops/02_monitoring_and_explainability.py.',
      ],
    );
  }
}

class MlopsLpwanSummary {
  final DateTime generatedAt;
  final String status;
  final MlopsLpwanDataset dataset;
  final int featureCount;
  final Map<String, MlopsLpwanTask> tasks;
  final Map<String, String> tfliteAssets;
  final Map<String, String> reports;

  const MlopsLpwanSummary({
    required this.generatedAt,
    required this.status,
    required this.dataset,
    required this.featureCount,
    required this.tasks,
    required this.tfliteAssets,
    required this.reports,
  });

  bool get hasData => dataset.rowsAvailable > 0 || tasks.isNotEmpty;
  bool get isResearchGrade =>
      status == 'research_grade' && dataset.realRatio >= 0.95;

  factory MlopsLpwanSummary.fromJson(Map<String, dynamic> json) {
    final parsedTasks = <String, MlopsLpwanTask>{};
    _map(json['tasks']).forEach((key, value) {
      parsedTasks[key.toString()] = MlopsLpwanTask.fromJson(_map(value));
    });
    final assets = <String, String>{};
    _map(json['tfliteAssets']).forEach((key, value) {
      assets[key.toString()] = value.toString();
    });
    final reportMap = <String, String>{};
    _map(json['reports']).forEach((key, value) {
      reportMap[key.toString()] = value.toString();
    });
    return MlopsLpwanSummary(
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()) ??
          DateTime.now(),
      status: (json['status'] ?? 'unavailable').toString(),
      dataset: MlopsLpwanDataset.fromJson(_map(json['dataset'])),
      featureCount: _int(json['featureCount']),
      tasks: parsedTasks,
      tfliteAssets: assets,
      reports: reportMap,
    );
  }

  factory MlopsLpwanSummary.fallback() {
    return MlopsLpwanSummary(
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      status: 'unavailable',
      dataset: const MlopsLpwanDataset.empty(),
      featureCount: 0,
      tasks: const {},
      tfliteAssets: const {},
      reports: const {},
    );
  }
}

class MlopsLpwanDataset {
  final int rowsAvailable;
  final int rowsUsedForTraining;
  final int realRows;
  final int syntheticRows;
  final double realRatio;
  final Map<String, int> sourceTypes;
  final Map<String, int> sourceDatasets;

  const MlopsLpwanDataset({
    required this.rowsAvailable,
    required this.rowsUsedForTraining,
    required this.realRows,
    required this.syntheticRows,
    required this.realRatio,
    required this.sourceTypes,
    required this.sourceDatasets,
  });

  const MlopsLpwanDataset.empty()
      : rowsAvailable = 0,
        rowsUsedForTraining = 0,
        realRows = 0,
        syntheticRows = 0,
        realRatio = 0,
        sourceTypes = const {},
        sourceDatasets = const {};

  factory MlopsLpwanDataset.fromJson(Map<String, dynamic> json) {
    final sourceTypes = <String, int>{};
    _map(json['sourceTypes']).forEach((key, value) {
      sourceTypes[key.toString()] = _int(value);
    });
    final sourceDatasets = <String, int>{};
    _map(json['sourceDatasets']).forEach((key, value) {
      sourceDatasets[key.toString()] = _int(value);
    });
    return MlopsLpwanDataset(
      rowsAvailable: _int(json['rowsAvailable']),
      rowsUsedForTraining: _int(json['rowsUsedForTraining']),
      realRows: _int(json['realRows']),
      syntheticRows: _int(json['syntheticRows']),
      realRatio: _double(json['realRatio']),
      sourceTypes: sourceTypes,
      sourceDatasets: sourceDatasets,
    );
  }
}

class MlopsLpwanTask {
  final String title;
  final String bestModel;
  final double bestF1;
  final double bestAccuracy;
  final String tflitePath;
  final int tfliteSizeBytes;
  final String shapStatus;
  final List<MlopsLpwanFeatureDriver> topFeatures;

  const MlopsLpwanTask({
    required this.title,
    required this.bestModel,
    required this.bestF1,
    required this.bestAccuracy,
    required this.tflitePath,
    required this.tfliteSizeBytes,
    required this.shapStatus,
    required this.topFeatures,
  });

  factory MlopsLpwanTask.fromJson(Map<String, dynamic> json) {
    return MlopsLpwanTask(
      title: (json['title'] ?? '').toString(),
      bestModel: (json['bestModel'] ?? 'unknown').toString(),
      bestF1: _double(json['bestF1']),
      bestAccuracy: _double(json['bestAccuracy']),
      tflitePath: (json['tflitePath'] ?? '').toString(),
      tfliteSizeBytes: _int(json['tfliteSizeBytes']),
      shapStatus: (json['shapStatus'] ?? '').toString(),
      topFeatures: _list(json['topFeatures'])
          .map((item) => MlopsLpwanFeatureDriver.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class MlopsLpwanFeatureDriver {
  final String feature;
  final double meanAbsShap;

  const MlopsLpwanFeatureDriver({
    required this.feature,
    required this.meanAbsShap,
  });

  factory MlopsLpwanFeatureDriver.fromJson(Map<String, dynamic> json) {
    return MlopsLpwanFeatureDriver(
      feature: (json['feature'] ?? '').toString(),
      meanAbsShap: _double(json['meanAbsShap']),
    );
  }
}

class MlopsEnterpriseSummary {
  final DateTime generatedAt;
  final String status;
  final Map<String, String> phaseCoverage;
  final int rows;
  final int realRows;
  final int syntheticRows;
  final double realRatio;
  final int catalogedDatasets;
  final int forecastTasks;
  final List<MlopsForecastSummary> bestForecasts;
  final MlopsMaintenanceSummary maintenance;
  final MlopsRootCauseSummary rootCause;
  final MlopsAdvancedMlopsSummary advancedMlops;
  final MlopsEdgeAiSummary edgeAi;
  final MlopsScientificSummary scientificValidation;
  final List<String> honestyNotes;
  final Map<String, String> reports;

  const MlopsEnterpriseSummary({
    required this.generatedAt,
    required this.status,
    required this.phaseCoverage,
    required this.rows,
    required this.realRows,
    required this.syntheticRows,
    required this.realRatio,
    required this.catalogedDatasets,
    required this.forecastTasks,
    required this.bestForecasts,
    required this.maintenance,
    required this.rootCause,
    required this.advancedMlops,
    required this.edgeAi,
    required this.scientificValidation,
    required this.honestyNotes,
    required this.reports,
  });

  bool get hasData => rows > 0 || phaseCoverage.isNotEmpty;
  bool get needsAttention =>
      status == 'attention' ||
      advancedMlops.retrainingTriggered ||
      advancedMlops.featureDriftStatus == 'high';

  factory MlopsEnterpriseSummary.fromJson(Map<String, dynamic> json) {
    final phases = <String, String>{};
    _map(json['phaseCoverage']).forEach((key, value) {
      phases[key.toString()] = value.toString();
    });
    final reportMap = <String, String>{};
    _map(json['reports']).forEach((key, value) {
      reportMap[key.toString()] = value.toString();
    });
    return MlopsEnterpriseSummary(
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()) ??
          DateTime.now(),
      status: (json['status'] ?? 'unavailable').toString(),
      phaseCoverage: phases,
      rows: _int(json['rows']),
      realRows: _int(json['realRows']),
      syntheticRows: _int(json['syntheticRows']),
      realRatio: _double(json['realRatio']),
      catalogedDatasets: _int(json['catalogedDatasets']),
      forecastTasks: _int(json['forecastTasks']),
      bestForecasts: _list(json['bestForecasts'])
          .map((item) => MlopsForecastSummary.fromJson(_map(item)))
          .toList(growable: false),
      maintenance: MlopsMaintenanceSummary.fromJson(_map(json['maintenance'])),
      rootCause: MlopsRootCauseSummary.fromJson(_map(json['rootCause'])),
      advancedMlops:
          MlopsAdvancedMlopsSummary.fromJson(_map(json['advancedMlops'])),
      edgeAi: MlopsEdgeAiSummary.fromJson(_map(json['edgeAi'])),
      scientificValidation:
          MlopsScientificSummary.fromJson(_map(json['scientificValidation'])),
      honestyNotes: _stringList(json['honestyNotes']),
      reports: reportMap,
    );
  }

  factory MlopsEnterpriseSummary.fallback() {
    return MlopsEnterpriseSummary(
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      status: 'unavailable',
      phaseCoverage: const {},
      rows: 0,
      realRows: 0,
      syntheticRows: 0,
      realRatio: 0,
      catalogedDatasets: 0,
      forecastTasks: 0,
      bestForecasts: const [],
      maintenance: MlopsMaintenanceSummary.empty,
      rootCause: MlopsRootCauseSummary.empty,
      advancedMlops: MlopsAdvancedMlopsSummary.empty,
      edgeAi: MlopsEdgeAiSummary.empty,
      scientificValidation: MlopsScientificSummary.empty,
      honestyNotes: const [],
      reports: const {},
    );
  }
}

class MlopsForecastSummary {
  final String task;
  final String model;
  final String status;
  final double rmse;

  const MlopsForecastSummary({
    required this.task,
    required this.model,
    required this.status,
    required this.rmse,
  });

  factory MlopsForecastSummary.fromJson(Map<String, dynamic> json) {
    return MlopsForecastSummary(
      task: (json['task'] ?? '').toString(),
      model: (json['model'] ?? 'none').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      rmse: _double(json['rmse']),
    );
  }
}

class MlopsMaintenanceSummary {
  final int assetsEvaluated;
  final Map<String, int> priorityCounts;
  final List<MlopsMaintenanceAsset> topAssets;

  const MlopsMaintenanceSummary({
    required this.assetsEvaluated,
    required this.priorityCounts,
    required this.topAssets,
  });

  static const empty = MlopsMaintenanceSummary(
    assetsEvaluated: 0,
    priorityCounts: {},
    topAssets: [],
  );

  factory MlopsMaintenanceSummary.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    _map(json['priorityCounts']).forEach((key, value) {
      counts[key.toString()] = _int(value);
    });
    return MlopsMaintenanceSummary(
      assetsEvaluated: _int(json['assetsEvaluated']),
      priorityCounts: counts,
      topAssets: _list(json['topAssets'])
          .map((item) => MlopsMaintenanceAsset.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class MlopsMaintenanceAsset {
  final String domain;
  final String nodeId;
  final double riskScore;
  final double failureProbability;
  final double estimatedRemainingLifeDays;
  final String maintenancePriority;

  const MlopsMaintenanceAsset({
    required this.domain,
    required this.nodeId,
    required this.riskScore,
    required this.failureProbability,
    required this.estimatedRemainingLifeDays,
    required this.maintenancePriority,
  });

  factory MlopsMaintenanceAsset.fromJson(Map<String, dynamic> json) {
    return MlopsMaintenanceAsset(
      domain: (json['domain'] ?? '').toString(),
      nodeId: (json['nodeId'] ?? '').toString(),
      riskScore: _double(json['riskScore']),
      failureProbability: _double(json['failureProbability']),
      estimatedRemainingLifeDays: _double(json['estimatedRemainingLifeDays']),
      maintenancePriority: (json['maintenancePriority'] ?? '').toString(),
    );
  }
}

class MlopsRootCauseSummary {
  final String method;
  final String shapStatus;
  final List<MlopsFeatureImportance> topFeatures;
  final MlopsRootCauseExample example;

  const MlopsRootCauseSummary({
    required this.method,
    required this.shapStatus,
    required this.topFeatures,
    required this.example,
  });

  static const empty = MlopsRootCauseSummary(
    method: 'unavailable',
    shapStatus: 'unavailable',
    topFeatures: [],
    example: MlopsRootCauseExample.empty,
  );

  factory MlopsRootCauseSummary.fromJson(Map<String, dynamic> json) {
    return MlopsRootCauseSummary(
      method: (json['method'] ?? 'unavailable').toString(),
      shapStatus: (json['shapStatus'] ?? 'unavailable').toString(),
      topFeatures: _list(json['topFeatures'])
          .map((item) => MlopsFeatureImportance.fromJson(_map(item)))
          .toList(growable: false),
      example: MlopsRootCauseExample.fromJson(_map(json['example'])),
    );
  }
}

class MlopsRootCauseExample {
  final double riskScore;
  final String primaryCause;
  final String secondaryCause;
  final List<String> contributingFactors;
  final String recommendedAction;

  const MlopsRootCauseExample({
    required this.riskScore,
    required this.primaryCause,
    required this.secondaryCause,
    required this.contributingFactors,
    required this.recommendedAction,
  });

  static const empty = MlopsRootCauseExample(
    riskScore: 0,
    primaryCause: '',
    secondaryCause: '',
    contributingFactors: [],
    recommendedAction: '',
  );

  factory MlopsRootCauseExample.fromJson(Map<String, dynamic> json) {
    return MlopsRootCauseExample(
      riskScore: _double(json['riskScore']),
      primaryCause: (json['primaryCause'] ?? '').toString(),
      secondaryCause: (json['secondaryCause'] ?? '').toString(),
      contributingFactors: _stringList(json['contributingFactors']),
      recommendedAction: (json['recommendedAction'] ?? '').toString(),
    );
  }
}

class MlopsAdvancedMlopsSummary {
  final String featureDriftStatus;
  final String conceptDriftStatus;
  final bool retrainingTriggered;
  final List<MlopsDriftCheck> topDriftChecks;

  const MlopsAdvancedMlopsSummary({
    required this.featureDriftStatus,
    required this.conceptDriftStatus,
    required this.retrainingTriggered,
    required this.topDriftChecks,
  });

  static const empty = MlopsAdvancedMlopsSummary(
    featureDriftStatus: 'unknown',
    conceptDriftStatus: 'unknown',
    retrainingTriggered: false,
    topDriftChecks: [],
  );

  factory MlopsAdvancedMlopsSummary.fromJson(Map<String, dynamic> json) {
    return MlopsAdvancedMlopsSummary(
      featureDriftStatus: (json['featureDriftStatus'] ?? 'unknown').toString(),
      conceptDriftStatus: (json['conceptDriftStatus'] ?? 'unknown').toString(),
      retrainingTriggered: _bool(json['retrainingTriggered']),
      topDriftChecks: _list(json['topDriftChecks'])
          .map((item) => MlopsDriftCheck.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class MlopsDriftCheck {
  final String feature;
  final double psi;
  final double ks;
  final double jensenShannon;
  final String status;

  const MlopsDriftCheck({
    required this.feature,
    required this.psi,
    required this.ks,
    required this.jensenShannon,
    required this.status,
  });

  factory MlopsDriftCheck.fromJson(Map<String, dynamic> json) {
    return MlopsDriftCheck(
      feature: (json['feature'] ?? '').toString(),
      psi: _double(json['psi']),
      ks: _double(json['ks']),
      jensenShannon: _double(json['jensenShannon']),
      status: (json['status'] ?? 'unknown').toString(),
    );
  }
}

class MlopsEdgeAiSummary {
  final String selectedDeployment;
  final List<MlopsEdgeVariant> variants;

  const MlopsEdgeAiSummary({
    required this.selectedDeployment,
    required this.variants,
  });

  static const empty = MlopsEdgeAiSummary(
    selectedDeployment: 'unavailable',
    variants: [],
  );

  factory MlopsEdgeAiSummary.fromJson(Map<String, dynamic> json) {
    return MlopsEdgeAiSummary(
      selectedDeployment:
          (json['selectedDeployment'] ?? 'unavailable').toString(),
      variants: _list(json['variants'])
          .map((item) => MlopsEdgeVariant.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class MlopsEdgeVariant {
  final String name;
  final String path;
  final int sizeBytes;
  final String status;

  const MlopsEdgeVariant({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.status,
  });

  factory MlopsEdgeVariant.fromJson(Map<String, dynamic> json) {
    return MlopsEdgeVariant(
      name: (json['name'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      sizeBytes: _int(json['sizeBytes']),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class MlopsScientificSummary {
  final String publicationReadiness;
  final List<String> artifacts;

  const MlopsScientificSummary({
    required this.publicationReadiness,
    required this.artifacts,
  });

  static const empty = MlopsScientificSummary(
    publicationReadiness: 'unavailable',
    artifacts: [],
  );

  factory MlopsScientificSummary.fromJson(Map<String, dynamic> json) {
    return MlopsScientificSummary(
      publicationReadiness:
          (json['publicationReadiness'] ?? 'unavailable').toString(),
      artifacts: _stringList(json['artifacts']),
    );
  }
}

class MlopsTrainingInfo {
  final String phase;
  final int trainingRows;
  final int realRows;
  final int syntheticRows;
  final double realRatio;
  final int featureCount;
  final Map<String, int> datasetsUsed;

  const MlopsTrainingInfo({
    required this.phase,
    required this.trainingRows,
    required this.realRows,
    required this.syntheticRows,
    required this.realRatio,
    required this.featureCount,
    required this.datasetsUsed,
  });

  bool get hasData => trainingRows > 0 || phase != 'Unavailable';

  factory MlopsTrainingInfo.fromJson(Map<String, dynamic> json) {
    final datasets = <String, int>{};
    _map(json['datasetsUsed']).forEach((key, value) {
      datasets[key.toString()] = _int(value);
    });
    return MlopsTrainingInfo(
      phase: (json['phase'] ?? 'Unavailable').toString(),
      trainingRows: _int(json['trainingRows']),
      realRows: _int(json['realRows']),
      syntheticRows: _int(json['syntheticRows']),
      realRatio: _double(json['realRatio']),
      featureCount: _int(json['featureCount']),
      datasetsUsed: datasets,
    );
  }
}

class MlopsMonitoring {
  final String backend;
  final int inferenceCount;
  final double averageScore;
  final double p95Score;
  final double threshold;
  final double latencyMs;
  final double errorRate;
  final Map<String, int> predictionDistribution;

  const MlopsMonitoring({
    required this.backend,
    required this.inferenceCount,
    required this.averageScore,
    required this.p95Score,
    required this.threshold,
    required this.latencyMs,
    required this.errorRate,
    required this.predictionDistribution,
  });

  int get anomalies => predictionDistribution['anomaly'] ?? 0;
  int get watch => predictionDistribution['watch'] ?? 0;
  int get normal => predictionDistribution['normal'] ?? 0;

  factory MlopsMonitoring.fromJson(Map<String, dynamic> json) {
    final distribution = <String, int>{};
    _map(json['predictionDistribution']).forEach((key, value) {
      distribution[key.toString()] = _int(value);
    });
    return MlopsMonitoring(
      backend: (json['backend'] ?? 'unknown').toString(),
      inferenceCount: _int(json['inferenceCount']),
      averageScore: _double(json['averageScore']),
      p95Score: _double(json['p95Score']),
      threshold: _double(json['threshold']),
      latencyMs: _double(json['latencyMs']),
      errorRate: _double(json['errorRate']),
      predictionDistribution: distribution,
    );
  }
}

class MlopsDrift {
  final String overallStatus;
  final int featuresDrifted;
  final int highDriftFeatures;
  final int mediumDriftFeatures;
  final List<MlopsFeatureDrift> topFeatureDrift;

  const MlopsDrift({
    required this.overallStatus,
    required this.featuresDrifted,
    required this.highDriftFeatures,
    required this.mediumDriftFeatures,
    required this.topFeatureDrift,
  });

  factory MlopsDrift.fromJson(Map<String, dynamic> json) {
    return MlopsDrift(
      overallStatus: (json['overallStatus'] ?? 'unknown').toString(),
      featuresDrifted: _int(json['featuresDrifted']),
      highDriftFeatures: _int(json['highDriftFeatures']),
      mediumDriftFeatures: _int(json['mediumDriftFeatures']),
      topFeatureDrift: _list(json['topFeatureDrift'])
          .map((item) => MlopsFeatureDrift.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class MlopsFeatureDrift {
  final String feature;
  final double psi;
  final double ks;
  final double referenceMean;
  final double liveMean;
  final String status;

  const MlopsFeatureDrift({
    required this.feature,
    required this.psi,
    required this.ks,
    required this.referenceMean,
    required this.liveMean,
    required this.status,
  });

  factory MlopsFeatureDrift.fromJson(Map<String, dynamic> json) {
    return MlopsFeatureDrift(
      feature: (json['feature'] ?? '').toString(),
      psi: _double(json['psi']),
      ks: _double(json['ks']),
      referenceMean: _double(json['referenceMean']),
      liveMean: _double(json['liveMean']),
      status: (json['status'] ?? 'unknown').toString(),
    );
  }
}

class MlopsMetrics {
  final double accuracy;
  final double precision;
  final double recall;
  final double f1;
  final double brier;
  final double ece;
  final double confidenceMean;

  const MlopsMetrics({
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.brier,
    required this.ece,
    required this.confidenceMean,
  });

  factory MlopsMetrics.fromJson(Map<String, dynamic> json) {
    return MlopsMetrics(
      accuracy: _double(json['accuracy']),
      precision: _double(json['precision']),
      recall: _double(json['recall']),
      f1: _double(json['f1']),
      brier: _double(json['brier']),
      ece: _double(json['ece']),
      confidenceMean: _double(json['confidenceMean']),
    );
  }
}

class MlopsExplainability {
  final String method;
  final String shapStatus;
  final List<MlopsFeatureImportance> topFeatures;
  final List<MlopsContributor> topContributingFactors;

  const MlopsExplainability({
    required this.method,
    required this.shapStatus,
    required this.topFeatures,
    required this.topContributingFactors,
  });

  factory MlopsExplainability.fromJson(Map<String, dynamic> json) {
    return MlopsExplainability(
      method: (json['method'] ?? 'unknown').toString(),
      shapStatus: (json['shapStatus'] ?? 'unknown').toString(),
      topFeatures: _list(json['topFeatures'])
          .map((item) => MlopsFeatureImportance.fromJson(_map(item)))
          .toList(growable: false),
      topContributingFactors: _list(json['topContributingFactors'])
          .map((item) => MlopsContributor.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class MlopsFeatureImportance {
  final String feature;
  final double importance;
  final String direction;

  const MlopsFeatureImportance({
    required this.feature,
    required this.importance,
    required this.direction,
  });

  factory MlopsFeatureImportance.fromJson(Map<String, dynamic> json) {
    return MlopsFeatureImportance(
      feature: (json['feature'] ?? '').toString(),
      importance: _double(json['importance']),
      direction: (json['direction'] ?? '').toString(),
    );
  }
}

class MlopsContributor {
  final String feature;
  final double value;
  final double referenceMedian;
  final double deviation;

  const MlopsContributor({
    required this.feature,
    required this.value,
    required this.referenceMedian,
    required this.deviation,
  });

  factory MlopsContributor.fromJson(Map<String, dynamic> json) {
    return MlopsContributor(
      feature: (json['feature'] ?? '').toString(),
      value: _double(json['value']),
      referenceMedian: _double(json['referenceMedian']),
      deviation: _double(json['deviation']),
    );
  }
}

class MlopsRegistry {
  final String activeVersion;
  final String path;
  final String latestPath;

  const MlopsRegistry({
    required this.activeVersion,
    required this.path,
    required this.latestPath,
  });

  factory MlopsRegistry.fromJson(Map<String, dynamic> json) {
    return MlopsRegistry(
      activeVersion: (json['activeVersion'] ?? 'unregistered').toString(),
      path: (json['path'] ?? 'not initialized').toString(),
      latestPath: (json['latestPath'] ?? 'not initialized').toString(),
    );
  }
}

class MlopsAbTesting {
  final String status;
  final String activeVersion;
  final String candidateVersion;
  final String decision;

  const MlopsAbTesting({
    required this.status,
    required this.activeVersion,
    required this.candidateVersion,
    required this.decision,
  });

  factory MlopsAbTesting.fromJson(Map<String, dynamic> json) {
    return MlopsAbTesting(
      status: (json['status'] ?? 'unknown').toString(),
      activeVersion: (json['activeVersion'] ?? '').toString(),
      candidateVersion: (json['candidateVersion'] ?? '').toString(),
      decision: (json['decision'] ?? '').toString(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const [];
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().toLowerCase().trim();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
