import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_local_stub.dart';
export 'notification_local_stub.dart' show LocalNotificationBridge;

class NativeLocalNotificationBridge implements LocalNotificationBridge {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linux = LinuxInitializationSettings(
      defaultActionName: 'Open SmartCity LPWAN',
    );
    const windows = WindowsInitializationSettings(
      appName: 'SmartCity LPWAN',
      appUserModelId: 'SmartCity.LPWAN.Monitoring',
      guid: '13ce4e34-8db0-4b38-9f67-8d2e78307d7a',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: windows,
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required bool critical,
  }) async {
    final android = AndroidNotificationDetails(
      critical ? 'smartcity_critical' : 'smartcity_warnings',
      critical ? 'Critical SmartCity Alerts' : 'SmartCity Warnings',
      channelDescription:
          'SmartCity LPWAN node and gateway notification channel',
      importance: critical ? Importance.max : Importance.high,
      priority: critical ? Priority.max : Priority.high,
      playSound: true,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final linux = LinuxNotificationDetails(
      urgency: critical ? LinuxNotificationUrgency.critical : null,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
        linux: linux,
      ),
    );
  }
}

LocalNotificationBridge createLocalNotificationBridge() {
  return NativeLocalNotificationBridge();
}
