import 'package:flutter/foundation.dart';

import '../models/gateway_model.dart';
import 'dashboard_provider.dart';

class GatewayProvider extends ChangeNotifier {
  GatewayModel? _gateway;

  GatewayModel? get gateway => _gateway;
  bool get online => _gateway?.online ?? false;
  int get totalPackets => _gateway?.totalPackets ?? 0;
  int get connectedNodes => _gateway?.onlineNodes ?? 0;
  double get averagePdr => _gateway?.pdr ?? 0;
  double get averageRssi => _gateway?.averageRssi ?? 0;
  double get averageSnr => _gateway?.averageSnr ?? 0;

  void syncFromDashboard(DashboardProvider dashboard) {
    final next = dashboard.gateway;
    if (identical(next, _gateway)) return;
    _gateway = next;
    notifyListeners();
  }
}
