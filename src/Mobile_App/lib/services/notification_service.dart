import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/alert_model.dart';
import 'notification_local_stub.dart'
    if (dart.library.io) 'notification_local_native.dart';

class NotificationService extends ChangeNotifier {
  bool enabled = true;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  bool repeatCriticalAlertSound = true;
  String alertSoundType = 'Default alert';
  AlertModel? latestAlert;
  bool latestAlertAcknowledged = false;

  final Map<String, DateTime> _lastShown = {};
  final LocalNotificationBridge _localNotifications =
      createLocalNotificationBridge();

  Future<void> initialize() async {
    await _localNotifications.initialize();
  }

  void setEnabled(bool value) {
    enabled = value;
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    soundEnabled = value;
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    vibrationEnabled = value;
    notifyListeners();
  }

  void setRepeatCriticalAlertSound(bool value) {
    repeatCriticalAlertSound = value;
    notifyListeners();
  }

  void setAlertSoundType(String value) {
    alertSoundType = value;
    notifyListeners();
  }

  void acknowledgeLatestAlert() {
    latestAlertAcknowledged = true;
    notifyListeners();
  }

  void clearLatestAlert() {
    latestAlert = null;
    latestAlertAcknowledged = false;
    notifyListeners();
  }

  bool showCriticalAlert(AlertModel alert) {
    return _show(alert.copyWithSeverity('critical'));
  }

  bool showWarningAlert(AlertModel alert) {
    return _show(alert.copyWithSeverity('warning'));
  }

  bool showNodeLost(String domain, int nodeId) {
    return _show(AlertModel(
      id: 'notify_node_lost_$domain',
      domain: domain,
      nodeId: nodeId,
      severity: 'critical',
      title: 'Node Lost',
      message: '$domain node stopped sending fresh LoRa packets.',
      timestamp: _now,
      resolved: false,
      flags: 0x01,
    ));
  }

  bool showLeakAlert(AlertModel alert) => _show(alert);
  bool showBridgeDangerAlert(AlertModel alert) => _show(alert);
  bool showGasAlert(AlertModel alert) => _show(alert);

  bool showAlert(AlertModel alert) => _show(alert);

  bool _show(AlertModel alert) {
    if (!enabled || alert.resolved) return false;
    final key = '${alert.domain}_${alert.nodeId}_${alert.id}';
    final last = _lastShown[key];
    final now = DateTime.now();
    if (last != null && now.difference(last).inSeconds < 60) {
      return false;
    }
    _lastShown[key] = now;
    latestAlert = alert;
    latestAlertAcknowledged = false;
    _localNotifications.show(
      id: key.hashCode & 0x7fffffff,
      title: alert.title,
      body: alert.message,
      critical: alert.severity == 'critical',
    );
    _playAlertCue(alert);
    if (!kIsWeb &&
        vibrationEnabled &&
        (alert.severity == 'critical' || alert.severity == 'warning')) {
      HapticFeedback.heavyImpact();
    }
    notifyListeners();
    return true;
  }

  void _playAlertCue(AlertModel alert) {
    if (!soundEnabled || kIsWeb) return;
    final repeatCount = alert.severity == 'critical' && repeatCriticalAlertSound
        ? 4
        : alert.severity == 'warning'
            ? 2
            : 1;
    for (var i = 0; i < repeatCount; i++) {
      Timer(Duration(milliseconds: 450 * i), () {
        if (latestAlert?.id != alert.id || latestAlertAcknowledged) return;
        SystemSound.play(SystemSoundType.alert);
      });
    }
  }

  int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

extension on AlertModel {
  AlertModel copyWithSeverity(String severity) {
    return AlertModel(
      id: id,
      domain: domain,
      nodeId: nodeId,
      severity: severity,
      title: title,
      message: message,
      timestamp: timestamp,
      resolved: resolved,
      flags: flags,
    );
  }
}
