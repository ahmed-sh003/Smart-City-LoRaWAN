abstract class LocalNotificationBridge {
  Future<void> initialize();
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required bool critical,
  });
}

class NoopLocalNotificationBridge implements LocalNotificationBridge {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required bool critical,
  }) async {}
}

LocalNotificationBridge createLocalNotificationBridge() {
  return NoopLocalNotificationBridge();
}
