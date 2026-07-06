import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/node_status.dart';
import '../theme/app_colors.dart';
import '../utils/sc1_helpers.dart';
import 'battery_indicator.dart';
import 'glass_card.dart';
import 'telemetry_row.dart';

class NodeTelemetryCard extends StatelessWidget {
  final NodeStatus status;
  final Color accentColor;

  const NodeTelemetryCard({
    super.key,
    required this.status,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: accentColor.withOpacity(0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 14,
            alignment: WrapAlignment.spaceBetween,
            children: [
              TelemetryRow(label: 'Node ID', value: '${status.nodeId}'),
              TelemetryRow(label: 'Domain', value: '${status.domain}'),
              TelemetryRow(label: 'Packet', value: status.packetType),
              TelemetryRow(label: 'Seq', value: '#${status.seq}'),
              TelemetryRow(label: 'Uptime', value: status.uptimeLabel),
              TelemetryRow(
                label: 'RSSI',
                value: '${status.rssi.toStringAsFixed(1)} dBm',
              ),
              TelemetryRow(
                label: 'SNR',
                value: '${status.snr.toStringAsFixed(1)} dB',
              ),
              TelemetryRow(label: 'Last Update', value: status.ageLabel),
            ],
          ),
          const Divider(color: AppColors.cardBorder, height: 24),
          Row(
            children: [
              Text(
                'Battery',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (status.hasBattery)
                BatteryIndicator(percent: status.batteryPercent)
              else
                Text(
                  'Not reported',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FlagChips(flags: status.flags),
          if (status.lastRawPacket.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RawPacket(packet: status.lastRawPacket),
          ],
        ],
      ),
    );
  }
}

class FlagChips extends StatelessWidget {
  final int flags;
  final WrapAlignment alignment;

  const FlagChips({
    super.key,
    required this.flags,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final decoded = decodeFlags(flags);
    if (decoded.isEmpty) {
      return _FlagChip(
        label: 'No Flags',
        color: AppColors.successGreen,
        icon: Icons.check_circle_rounded,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: alignment,
      children: [
        for (final label in decoded)
          _FlagChip(
            label: label,
            color: _colorFor(label),
            icon: _iconFor(label),
          ),
      ],
    );
  }

  Color _colorFor(String label) {
    switch (label) {
      case 'Alert':
      case 'Sensor Error':
        return AppColors.dangerRed;
      case 'Low Battery':
      case 'Event Packet':
        return AppColors.warningOrange;
      case 'Actuator Active':
        return AppColors.gatewayColor;
      default:
        return AppColors.neonBlue;
    }
  }

  IconData _iconFor(String label) {
    switch (label) {
      case 'Alert':
        return Icons.warning_rounded;
      case 'Low Battery':
        return Icons.battery_alert_rounded;
      case 'Sensor Error':
        return Icons.sensors_off_rounded;
      case 'Event Packet':
        return Icons.bolt_rounded;
      case 'Actuator Active':
        return Icons.settings_remote_rounded;
      default:
        return Icons.check_rounded;
    }
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _FlagChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RawPacket extends StatelessWidget {
  final String packet;

  const _RawPacket({required this.packet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        packet,
        style: GoogleFonts.sourceCodePro(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
