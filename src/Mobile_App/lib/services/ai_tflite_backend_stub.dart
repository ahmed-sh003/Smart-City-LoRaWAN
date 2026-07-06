class AiTfliteBackend {
  bool get hasLoadedModels => false;

  Future<void> load(Map<String, dynamic> config) async {}

  Future<double?> runAnomalyModel({
    required String domain,
    required List<List<double>> sequence,
  }) async {
    return null;
  }

  void dispose() {}
}
