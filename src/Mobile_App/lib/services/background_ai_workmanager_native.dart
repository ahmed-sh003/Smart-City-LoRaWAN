import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

const backgroundAiTaskName = 'smartcity_background_ai_analysis';

@pragma('vm:entry-point')
void backgroundAiCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('Background AI task executed: $task');
    return true;
  });
}

Future<void> initializeBackgroundAi() async {
  try {
    await Workmanager().initialize(
      backgroundAiCallbackDispatcher,
      isInDebugMode: false,
    );
  } catch (error) {
    debugPrint('Background AI initialization skipped: $error');
  }
}

Future<void> registerBackgroundAiTask() async {
  try {
    await Workmanager().registerPeriodicTask(
      backgroundAiTaskName,
      backgroundAiTaskName,
      frequency: const Duration(minutes: 5),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  } catch (error) {
    debugPrint('Background AI registration skipped: $error');
  }
}

Future<void> cancelBackgroundAiTask() async {
  try {
    await Workmanager().cancelByUniqueName(backgroundAiTaskName);
  } catch (error) {
    debugPrint('Background AI cancellation skipped: $error');
  }
}
