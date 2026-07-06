import '../core/utils/sc1_helpers.dart';
import 'node_status.dart';

class BuildingModel {
  final NodeStatus status;
  final double temperature;
  final double humidity;
  final double airQuality;
  final double smoke;
  final double? gas;
  final double soilMoisture;
  final bool rain;
  final double pressure;

  const BuildingModel({
    required this.status,
    required this.temperature,
    required this.humidity,
    required this.airQuality,
    required this.smoke,
    required this.gas,
    required this.soilMoisture,
    required this.rain,
    required this.pressure,
  });

  bool get hasGas => gas != null;
  int get batteryMv => status.batteryMv;
  double get batteryPercent => status.batteryPercent;
  double get rssi => status.rssi;
  double get snr => status.snr;
  int get seq => status.seq;
  int get uptimeSec => status.uptimeSec;
  int get flags => status.flags;
  bool get online => status.online;
  bool get alert => status.alert;
  int get lastUpdate => status.lastUpdate;
  String get lastRawPacket => status.lastRawPacket;

  bool get hasAlert =>
      status.effectiveAlert ||
      airQuality >= 1000 ||
      smoke >= 400 ||
      (gas ?? 0) >= 450 ||
      soilMoisture < 20;

  String get airQualityLabel {
    if (airQuality <= 0) return 'No Data';
    if (airQuality < 400) return 'Excellent';
    if (airQuality < 700) return 'Good';
    if (airQuality < 1000) return 'Moderate';
    return 'Poor';
  }

  String get smokeLabel {
    if (smoke <= 0) return 'No Data';
    if (smoke < 200) return 'Clear';
    if (smoke < 400) return 'Elevated';
    return 'Danger';
  }

  String get gasLabel {
    final gasValue = gas;
    if (gasValue == null) return 'Not reported';
    if (gasValue < 250) return 'Clear';
    if (gasValue < 450) return 'Elevated';
    return 'Danger';
  }

  String get soilLabel {
    if (soilMoisture < 30) return 'Dry';
    if (soilMoisture < 70) return 'Moist';
    return 'Wet';
  }

  factory BuildingModel.fromMap(Map<dynamic, dynamic> map) {
    final values = asMap(map['values']);
    final raw = rawValuesFrom(values);
    final hasExtendedRaw = raw.length >= 8;
    final explicitGas =
        mapDouble(values, ['gas', 'mq5', 'gasMq5']) ?? parseDouble(map['gas']);

    final gas = explicitGas ?? (hasExtendedRaw ? raw[4] : null);
    final soilRawIndex = hasExtendedRaw ? 5 : 4;
    final rainRawIndex = hasExtendedRaw ? 6 : 5;
    final pressureRawIndex = hasExtendedRaw ? 7 : 6;
    final rainValue = values.containsKey('rain')
        ? values['rain']
        : (rainRawIndex < raw.length ? raw[rainRawIndex] : null);

    return BuildingModel(
      status: NodeStatus.fromMap(
        map,
        defaultNodeId: 1,
        defaultDomain: 1,
      ),
      temperature: mapDouble(values, ['temperature', 'temp', 'dhtTemperature'],
              raw: raw, rawIndex: 0) ??
          0,
      humidity: mapDouble(values, ['humidity', 'dhtHumidity'],
              raw: raw, rawIndex: 1) ??
          0,
      airQuality:
          mapDouble(values, ['airQuality', 'mq135'], raw: raw, rawIndex: 2) ??
              0,
      smoke: mapDouble(values, ['smoke', 'mq2'], raw: raw, rawIndex: 3) ?? 0,
      gas: gas,
      soilMoisture: mapDouble(values, ['soilMoisture', 'soil'],
              raw: raw, rawIndex: soilRawIndex) ??
          0,
      rain: parseRain(rainValue),
      pressure: mapDouble(values, ['pressure', 'bmp280Pressure'],
              raw: raw, rawIndex: pressureRawIndex) ??
          0,
    );
  }

  factory BuildingModel.mock({
    bool alertMode = false,
    bool lowBattery = false,
    bool sensorError = false,
    bool gasSmokeAlert = false,
    int seq = 42,
  }) {
    var flags = 0;
    if (alertMode || gasSmokeAlert) flags |= flagAlert;
    if (lowBattery) flags |= flagBatteryLow;
    if (sensorError) flags |= flagSensorError;
    if (alertMode || gasSmokeAlert || sensorError) flags |= flagEvent;
    final gasValue = gasSmokeAlert ? 680.0 : 220.0;
    return BuildingModel(
      status: NodeStatus.mock(
        alert: alertMode || gasSmokeAlert || sensorError || lowBattery,
        nodeId: 1,
        domain: 1,
        seq: seq,
        uptimeSec: 18640,
        batteryMv: lowBattery ? 3180 : 3890,
        flags: flags,
        rssi: -68,
        snr: 9.1,
        lastRawPacket:
            'SC1|P|1|1|$seq|18640|${flags.toRadixString(16).padLeft(2, '0').toUpperCase()}|27.3|55|450|120|${gasValue.toStringAsFixed(0)}|48|2500|1008.5|A41F',
      ),
      temperature: sensorError ? -1 : (alertMode ? 38.5 : 27.3),
      humidity: sensorError ? -1 : 55.0,
      airQuality: gasSmokeAlert ? 1320 : (alertMode ? 980 : 450),
      smoke: gasSmokeAlert ? 640 : (alertMode ? 360 : 120),
      gas: gasValue,
      soilMoisture: alertMode ? 18 : 48,
      rain: false,
      pressure: sensorError ? -1 : 1008.5,
    );
  }
}
