import 'package:firebase_database/firebase_database.dart';

import '../core/constants/firebase_paths.dart';
import '../core/utils/sc1_helpers.dart';
import '../models/alert_model.dart';
import '../models/bridge_model.dart';
import '../models/building_model.dart';
import '../models/gateway_model.dart';
import '../models/water_model.dart';

class FirebaseService {
  FirebaseDatabase get _db => FirebaseDatabase.instance;

  Stream<BuildingModel> buildingStream() {
    return _db.ref(FirebasePaths.building).onValue.map((event) {
      final data = asMap(event.snapshot.value);
      if (data.isEmpty) return BuildingModel.mock();
      return BuildingModel.fromMap(data);
    });
  }

  Stream<BridgeModel> bridgeStream() {
    return _db.ref(FirebasePaths.bridge).onValue.map((event) {
      final data = asMap(event.snapshot.value);
      if (data.isEmpty) return BridgeModel.mock();
      return BridgeModel.fromMap(data);
    });
  }

  Stream<WaterModel> waterStream() {
    return _db.ref(FirebasePaths.water).onValue.map((event) {
      final data = asMap(event.snapshot.value);
      if (data.isEmpty) return WaterModel.mock();
      return WaterModel.fromMap(data);
    });
  }

  Stream<GatewayModel> gatewayStream() {
    return _db.ref(FirebasePaths.gateway).onValue.map((event) {
      final data = asMap(event.snapshot.value);
      if (data.isEmpty) return GatewayModel.mock();
      return GatewayModel.fromMap(data);
    });
  }

  Stream<List<AlertModel>> alertsStream() {
    return _db
        .ref(FirebasePaths.alerts)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = asMap(event.snapshot.value);
      if (data.isEmpty) return <AlertModel>[];
      final alerts = <AlertModel>[];
      for (final entry in data.entries) {
        final value = asMap(entry.value);
        if (value.isEmpty) continue;
        alerts.add(AlertModel.fromMap(entry.key.toString(), value));
      }
      alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return alerts;
    });
  }

  Stream<Map<dynamic, dynamic>> settingsStream() {
    return _db.ref(FirebasePaths.settings).onValue.map((event) {
      return asMap(event.snapshot.value);
    });
  }

  Future<void> resolveAlert(String alertId) async {
    await _db.ref('${FirebasePaths.alerts}/$alertId/resolved').set(true);
  }
}
