import 'background_ai_workmanager_stub.dart'
    if (dart.library.io) 'background_ai_workmanager_native.dart' as worker;

class BackgroundAiService {
  Future<void> initialize() async {
    await worker.initializeBackgroundAi();
  }

  Future<void> startPeriodicAnalysis() async {
    await worker.registerBackgroundAiTask();
  }

  Future<void> stopPeriodicAnalysis() async {
    await worker.cancelBackgroundAiTask();
  }
}
