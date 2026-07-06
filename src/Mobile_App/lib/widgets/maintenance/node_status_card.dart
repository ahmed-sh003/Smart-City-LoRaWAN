import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/maintenance_node.dart';
import 'maintenance_style.dart';

class NodeStatusCard extends StatelessWidget {
  final MaintenanceNode node;
  final VoidCallback? onTap;

  const NodeStatusCard({
    super.key,
    required this.node,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = node.online
        ? maintenanceSeverityColor(node.severity)
        : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 156),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: node.online ? 0.07 : 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(maintenanceDomainIcon(node.domain),
                    color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusDot(color: color),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              node.domainLabel,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              node.statusLabel,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              node.latestProblem,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              node.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Last seen ${node.lastSeen}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NodeTopologyGrid extends StatelessWidget {
  final MaintenanceNode gateway;
  final List<MaintenanceNode> nodes;
  final ValueChanged<MaintenanceNode>? onNodeTap;
  final VoidCallback? onGatewayTap;

  const NodeTopologyGrid({
    super.key,
    required this.gateway,
    required this.nodes,
    this.onNodeTap,
    this.onGatewayTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width =
            ((constraints.maxWidth - (columns - 1) * 10) / columns).toDouble();
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: NodeStatusCard(
                    node: nodes[0],
                    onTap: () => onNodeTap?.call(nodes[0]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NodeStatusCard(
                    node: nodes[1],
                    onTap: () => onNodeTap?.call(nodes[1]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GatewayWrapper(gateway: gateway, onGatewayTap: onGatewayTap),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final node in nodes.skip(2))
                  SizedBox(
                    width: width,
                    child: NodeStatusCard(
                      node: node,
                      onTap: () => onNodeTap?.call(node),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _GatewayWrapper extends StatelessWidget {
  final MaintenanceNode gateway;
  final VoidCallback? onGatewayTap;

  const _GatewayWrapper({
    required this.gateway,
    required this.onGatewayTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = maintenanceSeverityColor(gateway.severity);
    return InkWell(
      onTap: onGatewayTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Column(
          children: [
            Icon(Icons.cell_tower_rounded, color: color, size: 34),
            const SizedBox(height: 8),
            Text(
              'Gateway',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${gateway.statusLabel} - ${gateway.signalLabel}',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
