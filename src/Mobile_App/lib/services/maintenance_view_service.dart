import 'package:flutter/foundation.dart';

import '../core/utils/sc1_helpers.dart';
import '../models/alert_model.dart';
import '../models/maintenance_alert.dart';
import '../models/maintenance_node.dart';
import '../providers/dashboard_provider.dart';

enum MaintenanceAlertFilter {
  all,
  critical,
  warning,
  building,
  bridge,
  water,
  gateway,
  resolved,
}

extension MaintenanceAlertFilterLabel on MaintenanceAlertFilter {
  String get label {
    switch (this) {
      case MaintenanceAlertFilter.all:
        return 'All';
      case MaintenanceAlertFilter.critical:
        return 'Critical';
      case MaintenanceAlertFilter.warning:
        return 'Warning';
      case MaintenanceAlertFilter.building:
        return 'Building';
      case MaintenanceAlertFilter.bridge:
        return 'Bridge';
      case MaintenanceAlertFilter.water:
        return 'Water';
      case MaintenanceAlertFilter.gateway:
        return 'Gateway';
      case MaintenanceAlertFilter.resolved:
        return 'Resolved';
    }
  }
}

class MaintenanceViewService extends ChangeNotifier {
  final Set<String> _inProgressAlertIds = {};
  final Set<String> _acknowledgedAlertIds = {};
  final Map<String, List<String>> _notesByAlert = {};

  Set<String> get acknowledgedAlertIds =>
      Set.unmodifiable(_acknowledgedAlertIds);

  List<String> notesFor(String alertId) =>
      List.unmodifiable(_notesByAlert[alertId] ?? const []);

  void acknowledge(String alertId) {
    if (_acknowledgedAlertIds.add(alertId)) notifyListeners();
  }

  void markInProgress(String alertId) {
    if (_inProgressAlertIds.add(alertId)) notifyListeners();
  }

  void markResolvedLocal(String alertId) {
    _inProgressAlertIds.remove(alertId);
    _acknowledgedAlertIds.add(alertId);
    notifyListeners();
  }

  void addNote(String alertId, String note) {
    final cleaned = note.trim();
    if (cleaned.isEmpty) return;
    _notesByAlert.putIfAbsent(alertId, () => []).add(cleaned);
    notifyListeners();
  }

  List<MaintenanceAlert> alerts(DashboardProvider dashboard) {
    final alerts = dashboard.effectiveAlerts
        .map((alert) => _maintenanceAlert(alert, dashboard))
        .toList();
    alerts.sort((a, b) {
      final activeA = a.isActive ? 1 : 0;
      final activeB = b.isActive ? 1 : 0;
      if (activeA != activeB) return activeB.compareTo(activeA);
      final severityCompare =
          _severityRank(b.severity).compareTo(_severityRank(a.severity));
      if (severityCompare != 0) return severityCompare;
      return b.detectedAt.compareTo(a.detectedAt);
    });
    return alerts;
  }

  List<MaintenanceAlert> filteredAlerts(
    DashboardProvider dashboard,
    MaintenanceAlertFilter filter,
  ) {
    final all = alerts(dashboard);
    return all.where((alert) {
      switch (filter) {
        case MaintenanceAlertFilter.all:
          return alert.isActive;
        case MaintenanceAlertFilter.critical:
          return alert.isActive &&
              alert.severity == MaintenanceSeverity.critical;
        case MaintenanceAlertFilter.warning:
          return alert.isActive &&
              alert.severity == MaintenanceSeverity.warning;
        case MaintenanceAlertFilter.building:
          return alert.isActive && alert.domain == 'building';
        case MaintenanceAlertFilter.bridge:
          return alert.isActive && alert.domain == 'bridge';
        case MaintenanceAlertFilter.water:
          return alert.isActive && alert.domain == 'water';
        case MaintenanceAlertFilter.gateway:
          return alert.isActive && alert.domain == 'gateway';
        case MaintenanceAlertFilter.resolved:
          return alert.status == MaintenanceAlertStatus.resolved;
      }
    }).toList(growable: false);
  }

  List<MaintenanceNode> nodes(DashboardProvider dashboard) {
    final activeAlerts = alerts(dashboard).where((alert) => alert.isActive);
    MaintenanceAlert? latestFor(String domain) {
      final matching = activeAlerts.where((alert) => alert.domain == domain);
      if (matching.isEmpty) return null;
      return matching.reduce((a, b) =>
          _severityRank(a.severity) >= _severityRank(b.severity) ? a : b);
    }

    final buildingAlert = latestFor('building');
    final bridgeAlert = latestFor('bridge');
    final waterAlert = latestFor('water');
    final gatewayAlert = latestFor('gateway');
    final building = dashboard.building;
    final bridge = dashboard.bridge;
    final water = dashboard.water;
    final gateway = dashboard.gateway;

    return [
      MaintenanceNode(
        key: 'building',
        name: 'Node 1',
        domain: 'building',
        domainLabel: 'Building',
        location: locationForDomain('building'),
        severity: _nodeSeverity(
          online: building?.online ?? false,
          hasAlert: building?.hasAlert == true || buildingAlert != null,
          critical: buildingAlert?.isCritical == true,
        ),
        statusLabel: _nodeStatusLabel(
          online: building?.online ?? false,
          hasAlert: building?.hasAlert == true || buildingAlert != null,
          critical: buildingAlert?.isCritical == true,
        ),
        online: building?.online ?? false,
        latestProblem: buildingAlert?.problem ?? 'No active problem',
        lastSeen: formatTimeAgo(building?.lastUpdate ?? 0),
        batteryPercent: building?.batteryPercent ?? 0,
        batteryLabel: batteryLabel(building?.batteryPercent ?? 0),
        signalLabel: signalLabel(building?.rssi ?? 0, building?.snr ?? 0),
        latestAlert: buildingAlert,
        technicalValues: {
          'RSSI': _dbm(building?.rssi),
          'SNR': _db(building?.snr),
          'Battery': _percent(building?.batteryPercent),
          'Packet': building?.lastRawPacket ?? 'Not available',
        },
      ),
      MaintenanceNode(
        key: 'bridge',
        name: 'Node 2',
        domain: 'bridge',
        domainLabel: 'Bridge',
        location: locationForDomain('bridge'),
        severity: _nodeSeverity(
          online: bridge?.online ?? false,
          hasAlert: bridge?.hasAlert == true || bridgeAlert != null,
          critical: bridgeAlert?.isCritical == true,
        ),
        statusLabel: _nodeStatusLabel(
          online: bridge?.online ?? false,
          hasAlert: bridge?.hasAlert == true || bridgeAlert != null,
          critical: bridgeAlert?.isCritical == true,
        ),
        online: bridge?.online ?? false,
        latestProblem: bridgeAlert?.problem ?? 'No active problem',
        lastSeen: formatTimeAgo(bridge?.lastUpdate ?? 0),
        batteryPercent: bridge?.batteryPercent ?? 0,
        batteryLabel: batteryLabel(bridge?.batteryPercent ?? 0),
        signalLabel: signalLabel(bridge?.rssi ?? 0, bridge?.snr ?? 0),
        latestAlert: bridgeAlert,
        technicalValues: {
          'RSSI': _dbm(bridge?.rssi),
          'SNR': _db(bridge?.snr),
          'Battery': _percent(bridge?.batteryPercent),
          'Road': bridge?.roadStatus ?? 'Not available',
          'Packet': bridge?.lastRawPacket ?? 'Not available',
        },
      ),
      MaintenanceNode(
        key: 'water',
        name: 'Node 3',
        domain: 'water',
        domainLabel: 'Water',
        location: locationForDomain('water'),
        severity: _nodeSeverity(
          online: water?.online ?? false,
          hasAlert: water?.hasAlert == true || waterAlert != null,
          critical: waterAlert?.isCritical == true,
        ),
        statusLabel: _nodeStatusLabel(
          online: water?.online ?? false,
          hasAlert: water?.hasAlert == true || waterAlert != null,
          critical: waterAlert?.isCritical == true,
        ),
        online: water?.online ?? false,
        latestProblem: waterAlert?.problem ?? 'No active problem',
        lastSeen: formatTimeAgo(water?.lastUpdate ?? 0),
        batteryPercent: water?.batteryPercent ?? 0,
        batteryLabel: batteryLabel(water?.batteryPercent ?? 0),
        signalLabel: signalLabel(water?.rssi ?? 0, water?.snr ?? 0),
        latestAlert: waterAlert,
        technicalValues: {
          'RSSI': _dbm(water?.rssi),
          'SNR': _db(water?.snr),
          'Battery': _percent(water?.batteryPercent),
          'Leak probability': _percent(water?.leakProbability),
          'Packet': water?.lastRawPacket ?? 'Not available',
        },
      ),
      MaintenanceNode(
        key: 'gateway',
        name: 'Gateway',
        domain: 'gateway',
        domainLabel: 'Gateway / Network',
        location: locationForDomain('gateway'),
        severity: _nodeSeverity(
          online: gateway?.online ?? false,
          hasAlert: gatewayAlert != null || (gateway?.lostNodes ?? 0) > 0,
          critical:
              gateway?.online == false || gatewayAlert?.isCritical == true,
        ),
        statusLabel: _nodeStatusLabel(
          online: gateway?.online ?? false,
          hasAlert: gatewayAlert != null || (gateway?.lostNodes ?? 0) > 0,
          critical:
              gateway?.online == false || gatewayAlert?.isCritical == true,
        ),
        online: gateway?.online ?? false,
        latestProblem: gatewayAlert?.problem ?? 'Gateway receiving packets',
        lastSeen: gateway?.ageLabel ?? 'Not available',
        batteryPercent: 100,
        batteryLabel: 'Powered',
        signalLabel:
            signalLabel(gateway?.averageRssi ?? 0, gateway?.averageSnr ?? 0),
        latestAlert: gatewayAlert,
        technicalValues: {
          'RSSI': _dbm(gateway?.averageRssi),
          'SNR': _db(gateway?.averageSnr),
          'Packet loss':
              '${(100 - (gateway?.pdr ?? 0)).clamp(0, 100).toStringAsFixed(1)}%',
          'Delivery ratio': '${(gateway?.pdr ?? 0).toStringAsFixed(1)}%',
          'Last packet': gateway?.lastRawPacket ?? 'Not available',
        },
      ),
    ];
  }

  MaintenanceAlert? highestPriorityAlert(DashboardProvider dashboard) {
    final active = alerts(dashboard).where((alert) => alert.isActive).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) {
      final severityCompare =
          _severityRank(b.severity).compareTo(_severityRank(a.severity));
      if (severityCompare != 0) return severityCompare;
      return b.detectedAt.compareTo(a.detectedAt);
    });
    return active.first;
  }

  MaintenanceSeverity citySeverity(DashboardProvider dashboard) {
    if (dashboard.gateway?.online == false) return MaintenanceSeverity.critical;
    final active = alerts(dashboard).where((alert) => alert.isActive);
    if (active.any((alert) => alert.severity == MaintenanceSeverity.critical)) {
      return MaintenanceSeverity.critical;
    }
    if (active.any((alert) => alert.severity == MaintenanceSeverity.warning)) {
      return MaintenanceSeverity.warning;
    }
    if (dashboard.totalOnlineNodes < 3) return MaintenanceSeverity.warning;
    return MaintenanceSeverity.normal;
  }

  String cityStatusTitle(DashboardProvider dashboard) {
    switch (citySeverity(dashboard)) {
      case MaintenanceSeverity.normal:
        return 'All Systems Normal';
      case MaintenanceSeverity.warning:
        return 'Attention Required';
      case MaintenanceSeverity.critical:
        return 'Critical Alert';
    }
  }

  MaintenanceAlert _maintenanceAlert(
    AlertModel alert,
    DashboardProvider dashboard,
  ) {
    final domain = normalizeDomain(alert.domain);
    final resolved = alert.resolved;
    final status = resolved
        ? MaintenanceAlertStatus.resolved
        : _inProgressAlertIds.contains(alert.id)
            ? MaintenanceAlertStatus.inProgress
            : MaintenanceAlertStatus.newAlert;
    return MaintenanceAlert(
      id: alert.id,
      title: simpleTitle(alert),
      nodeName: domain == 'gateway' ? 'Gateway' : 'Node ${alert.nodeId}',
      nodeId: alert.nodeId,
      domain: domain,
      domainLabel: domainLabel(domain),
      location: locationForDomain(domain),
      severity: severityFor(alert),
      status: status,
      problem: simpleProblem(alert),
      reason: simpleReason(alert),
      recommendedAction: recommendedAction(alert),
      detectedAt: alert.dateTime,
      source: alert,
      technicalValues: _technicalValues(alert, dashboard),
    );
  }
}

String normalizeDomain(String domain) {
  switch (domain) {
    case '1':
    case 'building':
      return 'building';
    case '2':
    case 'bridge':
      return 'bridge';
    case '3':
    case 'water':
      return 'water';
    case '4':
    case 'gateway':
      return 'gateway';
    default:
      return domain.isEmpty ? 'gateway' : domain;
  }
}

String domainLabel(String domain) {
  switch (normalizeDomain(domain)) {
    case 'building':
      return 'Building';
    case 'bridge':
      return 'Bridge';
    case 'water':
      return 'Water';
    case 'gateway':
      return 'Gateway / Network';
    default:
      return 'System';
  }
}

String locationForDomain(String domain) {
  switch (normalizeDomain(domain)) {
    case 'building':
      return 'Building A - Floor 2';
    case 'bridge':
      return 'Bridge Sensor 1';
    case 'water':
      return 'Water Tank Area';
    case 'gateway':
      return 'Gateway Roof';
    default:
      return 'Location not set';
  }
}

String simpleTitle(AlertModel alert) {
  final text = '${alert.title} ${alert.message}'.toLowerCase();
  if (text.contains('leak')) return 'Possible Water Leak';
  if (text.contains('bridge') || text.contains('danger')) {
    return 'Bridge Safety Alert';
  }
  if (text.contains('gas') || text.contains('smoke')) {
    return 'Smoke or Gas Alert';
  }
  if (text.contains('battery')) return 'Low Battery';
  if (text.contains('sensor')) return 'Sensor Problem';
  if (text.contains('offline') || text.contains('lost')) return 'Node Offline';
  if (text.contains('signal') || text.contains('packet')) {
    return 'Network Signal Warning';
  }
  return alert.title.isEmpty ? 'System Alert' : alert.title;
}

String simpleProblem(AlertModel alert) {
  final text = '${alert.title} ${alert.message}'.toLowerCase();
  if (text.contains('leak')) return 'Possible leak detected';
  if (text.contains('bridge') || text.contains('danger')) {
    return 'Bridge sensor reported danger';
  }
  if (text.contains('gas') || text.contains('smoke')) {
    return 'Smoke or gas reading is high';
  }
  if (text.contains('battery')) return 'Battery is low';
  if (text.contains('sensor')) return 'Sensor values are unreliable';
  if (text.contains('offline') || text.contains('lost')) {
    return 'Node stopped sending data';
  }
  if (text.contains('packet')) return 'Packet delivery is weak';
  if (text.contains('signal')) return 'Node signal is weak';
  return alert.message.isEmpty ? 'Reason unavailable' : alert.message;
}

String simpleReason(AlertModel alert) {
  final text = '${alert.title} ${alert.message}'.toLowerCase();
  if (text.contains('leak')) {
    return 'Water levels changed and soil around the pipe is wet.';
  }
  if (text.contains('bridge') || text.contains('danger')) {
    return 'Bridge safety input changed or the road was closed.';
  }
  if (text.contains('gas') || text.contains('smoke')) {
    return 'Air safety sensors reported high gas or smoke values.';
  }
  if (text.contains('battery')) return 'Battery voltage is below normal.';
  if (text.contains('sensor')) {
    return 'Sensor stopped sending reliable values.';
  }
  if (text.contains('offline') || text.contains('lost')) {
    return 'No fresh packets arrived before the timeout.';
  }
  if (text.contains('packet') || text.contains('signal')) {
    return 'Signal became weak or packet delivery dropped.';
  }
  return alert.message.isEmpty ? 'Reason unavailable' : alert.message;
}

String recommendedAction(AlertModel alert) {
  final text = '${alert.title} ${alert.message}'.toLowerCase();
  if (text.contains('leak')) {
    return 'Inspect the pipe, valve, and tank area for water leakage.';
  }
  if (text.contains('bridge') || text.contains('danger')) {
    return 'Inspect the bridge sensor area and keep the road closed if needed.';
  }
  if (text.contains('gas') || text.contains('smoke')) {
    return 'Ventilate the area and check smoke/gas sensors immediately.';
  }
  if (text.contains('battery')) {
    return 'Replace or recharge the node battery.';
  }
  if (text.contains('sensor')) {
    return 'Check sensor wiring and power.';
  }
  if (text.contains('offline') || text.contains('lost')) {
    return 'Check node power, antenna, and gateway distance.';
  }
  if (text.contains('packet') || text.contains('signal')) {
    return 'Check antenna direction and remove obstacles near the gateway.';
  }
  return 'Inspect the node and confirm the sensor is working.';
}

MaintenanceSeverity severityFor(AlertModel alert) {
  final text =
      '${alert.title} ${alert.message} ${alert.severity}'.toLowerCase();
  if (text.contains('critical') ||
      text.contains('leak') ||
      text.contains('danger') ||
      text.contains('smoke') ||
      text.contains('gas') ||
      text.contains('offline') ||
      text.contains('lost')) {
    return MaintenanceSeverity.critical;
  }
  if (text.contains('warning') ||
      text.contains('battery') ||
      text.contains('sensor') ||
      text.contains('signal') ||
      text.contains('packet')) {
    return MaintenanceSeverity.warning;
  }
  return MaintenanceSeverity.warning;
}

String batteryLabel(double percent) {
  if (percent <= 0) return 'Not available';
  if (percent < 15) return 'Critical';
  if (percent < 30) return 'Low';
  return 'Good';
}

String signalLabel(double rssi, double snr) {
  if (rssi == 0 && snr == 0) return 'Not available';
  if (rssi < -105 || snr < 0) return 'Weak';
  if (rssi < -95 || snr < 5) return 'Good';
  return 'Strong';
}

MaintenanceSeverity _nodeSeverity({
  required bool online,
  required bool hasAlert,
  required bool critical,
}) {
  if (!online || critical) return MaintenanceSeverity.critical;
  if (hasAlert) return MaintenanceSeverity.warning;
  return MaintenanceSeverity.normal;
}

String _nodeStatusLabel({
  required bool online,
  required bool hasAlert,
  required bool critical,
}) {
  if (!online) return 'Offline';
  if (critical) return 'Critical';
  if (hasAlert) return 'Warning';
  return 'Normal';
}

int _severityRank(MaintenanceSeverity severity) {
  switch (severity) {
    case MaintenanceSeverity.normal:
      return 0;
    case MaintenanceSeverity.warning:
      return 1;
    case MaintenanceSeverity.critical:
      return 2;
  }
}

Map<String, String> _technicalValues(
  AlertModel alert,
  DashboardProvider dashboard,
) {
  final domain = normalizeDomain(alert.domain);
  switch (domain) {
    case 'building':
      return {
        'RSSI': _dbm(dashboard.building?.rssi),
        'SNR': _db(dashboard.building?.snr),
        'Battery': _percent(dashboard.building?.batteryPercent),
        'Last packet': dashboard.building?.lastRawPacket ?? 'Not available',
      };
    case 'bridge':
      return {
        'RSSI': _dbm(dashboard.bridge?.rssi),
        'SNR': _db(dashboard.bridge?.snr),
        'Battery': _percent(dashboard.bridge?.batteryPercent),
        'Road': dashboard.bridge?.roadStatus ?? 'Not available',
        'Last packet': dashboard.bridge?.lastRawPacket ?? 'Not available',
      };
    case 'water':
      return {
        'RSSI': _dbm(dashboard.water?.rssi),
        'SNR': _db(dashboard.water?.snr),
        'Battery': _percent(dashboard.water?.batteryPercent),
        'Leak probability': _percent(dashboard.water?.leakProbability),
        'Last packet': dashboard.water?.lastRawPacket ?? 'Not available',
      };
    default:
      return {
        'RSSI': _dbm(dashboard.gateway?.averageRssi),
        'SNR': _db(dashboard.gateway?.averageSnr),
        'Delivery ratio':
            '${(dashboard.gateway?.pdr ?? 0).toStringAsFixed(1)}%',
        'Last packet': dashboard.gateway?.lastRawPacket ?? 'Not available',
      };
  }
}

String _dbm(double? value) => value == null || value == 0
    ? 'Not available'
    : '${value.toStringAsFixed(0)} dBm';

String _db(double? value) => value == null || value == 0
    ? 'Not available'
    : '${value.toStringAsFixed(1)} dB';

String _percent(double? value) => value == null || value <= 0
    ? 'Not available'
    : '${value.toStringAsFixed(0)}%';
