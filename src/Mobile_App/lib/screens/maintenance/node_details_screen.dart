import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mobile_app_frame.dart';
import '../../models/maintenance_node.dart';
import '../../widgets/maintenance/maintenance_style.dart';

class NodeDetailsScreen extends StatelessWidget {
  final MaintenanceNode node;

  const NodeDetailsScreen({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    final color = maintenanceSeverityColor(node.severity);
    return MobileAppFrame(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(node.name),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              GlassCard(
                borderRadius: 8,
                borderColor: color.withValues(alpha: 0.22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            maintenanceDomainIcon(node.domain),
                            color: color,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                node.name,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${node.domainLabel} - ${node.statusLabel}',
                                style: GoogleFonts.inter(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailLine(label: 'Status', value: node.statusLabel),
                    _DetailLine(label: 'Domain', value: node.domainLabel),
                    _DetailLine(label: 'Location', value: node.location),
                    _DetailLine(label: 'Battery', value: node.batteryLabel),
                    _DetailLine(label: 'Signal', value: node.signalLabel),
                    _DetailLine(
                        label: 'Connection',
                        value: node.online ? 'Online' : 'Offline'),
                    _DetailLine(label: 'Last seen', value: node.lastSeen),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active alerts',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      node.latestAlert?.problem ?? 'No active alerts',
                      style: GoogleFonts.inter(
                        color: node.latestAlert == null
                            ? AppColors.successGreen
                            : color,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (node.latestAlert != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        node.latestAlert!.recommendedAction,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent history',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      node.hasProblem
                          ? 'This node needs a technician check.'
                          : 'This node has been working normally.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 8,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    'Technical values',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'RSSI, SNR, packet loss, battery, and last packet',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    for (final entry in node.technicalValues.entries)
                      _DetailLine(label: entry.key, value: entry.value),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
