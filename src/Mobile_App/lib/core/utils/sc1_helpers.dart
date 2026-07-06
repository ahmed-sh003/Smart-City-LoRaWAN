import 'package:intl/intl.dart';

const int flagAlert = 0x01;
const int flagBatteryLow = 0x02;
const int flagSensorError = 0x04;
const int flagEvent = 0x08;
const int flagActuatorOn = 0x10;

const Duration nodeOnlineTimeout = Duration(seconds: 90);

List<String> decodeFlags(int flags) {
  final labels = <String>[];
  if ((flags & flagAlert) != 0) labels.add('Alert');
  if ((flags & flagBatteryLow) != 0) labels.add('Low Battery');
  if ((flags & flagSensorError) != 0) labels.add('Sensor Error');
  if ((flags & flagEvent) != 0) labels.add('Event Packet');
  if ((flags & flagActuatorOn) != 0) labels.add('Actuator Active');
  return labels;
}

bool hasAlertFlag(int flags) => (flags & flagAlert) != 0;
bool hasAlert(int flags) => hasAlertFlag(flags);
bool isLowBattery(int flags) => (flags & flagBatteryLow) != 0;
bool hasLowBattery(int flags) => isLowBattery(flags);
bool hasSensorError(int flags) => (flags & flagSensorError) != 0;
bool isEventPacket(int flags) => (flags & flagEvent) != 0;
bool hasEventPacket(int flags) => isEventPacket(flags);
bool isActuatorActive(int flags) => (flags & flagActuatorOn) != 0;
bool hasActuatorActive(int flags) => isActuatorActive(flags);

double batteryMvToPercent(int batteryMv) {
  if (batteryMv <= 0) return 0;
  const minMv = 3000.0;
  const maxMv = 4200.0;
  return ((batteryMv - minMv) / (maxMv - minMv) * 100).clamp(0, 100);
}

String formatTimestamp(int seconds) {
  if (seconds <= 0) return 'Never';
  final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  return DateFormat('dd MMM HH:mm:ss').format(date);
}

String formatTimeAgo(int seconds) {
  if (seconds <= 0) return 'Never';
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  final diff = DateTime.now().difference(updatedAt);
  if (diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String formatUptime(int seconds) {
  if (seconds <= 0) return '--';
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

bool isOnlineFromLastUpdate(
  int lastUpdate, {
  bool reportedOnline = true,
  Duration timeout = nodeOnlineTimeout,
}) {
  if (!reportedOnline || lastUpdate <= 0) return false;
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(lastUpdate * 1000);
  return DateTime.now().difference(updatedAt) <= timeout;
}

bool isNodeOnline(
  int lastUpdate, {
  bool reportedOnline = true,
  int timeoutSeconds = 90,
}) {
  return isOnlineFromLastUpdate(
    lastUpdate,
    reportedOnline: reportedOnline,
    timeout: Duration(seconds: timeoutSeconds),
  );
}

String severityFromFlags(int flags) {
  if (hasAlert(flags) || hasSensorError(flags)) return 'critical';
  if (hasLowBattery(flags) || hasEventPacket(flags)) return 'warning';
  if (hasActuatorActive(flags)) return 'info';
  return 'info';
}

Map<dynamic, dynamic> asMap(dynamic value) {
  if (value is Map) return Map<dynamic, dynamic>.from(value);
  return <dynamic, dynamic>{};
}

List<double> rawValuesFrom(Map<dynamic, dynamic> values) {
  final raw = <double>[];
  final list = values['rawValues'] ?? values['raw'] ?? values['values'];
  if (list is List) {
    for (final item in list) {
      raw.add(parseDouble(item) ?? 0);
    }
  }
  for (var i = 1; i <= 8; i++) {
    final value = values['v$i'] ?? values[i] ?? values['value$i'];
    if (value != null) {
      while (raw.length < i) {
        raw.add(0);
      }
      raw[i - 1] = parseDouble(value) ?? 0;
    }
  }
  return raw;
}

double? mapDouble(
  Map<dynamic, dynamic> values,
  List<Object> keys, {
  List<double>? raw,
  int? rawIndex,
}) {
  for (final key in keys) {
    if (values.containsKey(key)) return parseDouble(values[key]);
  }
  if (raw != null &&
      rawIndex != null &&
      rawIndex >= 0 &&
      rawIndex < raw.length) {
    return raw[rawIndex];
  }
  return null;
}

int? mapInt(
  Map<dynamic, dynamic> values,
  List<Object> keys, {
  List<double>? raw,
  int? rawIndex,
}) {
  final value = mapDouble(values, keys, raw: raw, rawIndex: rawIndex);
  return value?.round();
}

String? mapString(Map<dynamic, dynamic> values, List<Object> keys) {
  for (final key in keys) {
    final value = values[key];
    if (value != null) return value.toString();
  }
  return null;
}

bool mapBool(
  Map<dynamic, dynamic> values,
  List<Object> keys, {
  List<double>? raw,
  int? rawIndex,
  bool defaultValue = false,
}) {
  for (final key in keys) {
    if (values.containsKey(key)) {
      return parseBool(values[key], defaultValue: defaultValue);
    }
  }
  if (raw != null &&
      rawIndex != null &&
      rawIndex >= 0 &&
      rawIndex < raw.length) {
    return parseBool(raw[rawIndex], defaultValue: defaultValue);
  }
  return defaultValue;
}

bool parseBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text.isEmpty) return defaultValue;
  if (['1', 'true', 'yes', 'y', 'on', 'open', 'active', 'alert', 'leak']
      .contains(text)) {
    return true;
  }
  if (['0', 'false', 'no', 'n', 'off', 'closed', 'inactive', 'clear', 'dry']
      .contains(text)) {
    return false;
  }
  return defaultValue;
}

bool parseRain(dynamic value, {bool activeLowAnalog = true}) {
  if (value is bool || value is String) {
    final text = value.toString().trim().toLowerCase();
    if (['rain', 'raining', 'wet'].contains(text)) return true;
    if (['dry', 'clear', 'none'].contains(text)) return false;
    return parseBool(value);
  }
  final number = parseDouble(value);
  if (number == null) return false;
  if (number == 0 || number == 1) return number == 1;
  return activeLowAnalog ? number < 1800 : number > 0;
}

double? parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

int parseInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? defaultValue;
}

int parseFlags(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  final text = value.toString().trim();
  if (text.isEmpty) return 0;
  return int.tryParse(text) ?? int.tryParse(text, radix: 16) ?? 0;
}

int parseTimestamp(dynamic value) {
  if (value == null) return 0;
  if (value is DateTime) return value.millisecondsSinceEpoch ~/ 1000;
  if (value is num) {
    final raw = value.toInt();
    if (raw > 100000000000) return raw ~/ 1000;
    return raw;
  }
  final text = value.toString().trim();
  final number = int.tryParse(text);
  if (number != null) return parseTimestamp(number);
  final parsed = DateTime.tryParse(text);
  return parsed == null ? 0 : parsed.millisecondsSinceEpoch ~/ 1000;
}

String normalizeRoadStatus(String? value) {
  final text = (value ?? '').trim().toUpperCase();
  if (text.contains('DANGER')) return 'DANGER DETECTED';
  if (text.contains('CLOSED') || text.contains('CLOSE')) return 'ROAD CLOSED';
  if (text.contains('OPEN')) return 'ROAD OPEN';
  return '';
}
