import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/maintenance_node.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/maintenance_view_service.dart';
import '../../widgets/maintenance/gateway_center_card.dart';
import '../../widgets/maintenance/node_status_card.dart';
import 'node_details_screen.dart';

class MaintenanceNodesScreen extends StatelessWidget {
  const MaintenanceNodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final maintenance = context.watch<MaintenanceViewService>();
    final nodes = maintenance.nodes(dashboard);
    final gateway = nodes.firstWhere((node) => node.domain == 'gateway');
    final fieldNodes =
        nodes.where((node) => node.domain != 'gateway').toList(growable: false);

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nodes',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gateway and field node status at a glance',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            borderRadius: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Network Layout',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gateway is the center of communication.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                GatewayCenterCard(
                  gateway: gateway,
                  onTap: () => _openNode(context, gateway),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 340;
                    final width = twoColumns
                        ? ((constraints.maxWidth - 10) / 2)
                            .clamp(150.0, 260.0)
                            .toDouble()
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final node in fieldNodes)
                          SizedBox(
                            width: width,
                            child: NodeStatusCard(
                              node: node,
                              onTap: () => _openNode(context, node),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openNode(BuildContext context, MaintenanceNode node) {
    Navigator.of(context).push(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) => NodeDetailsScreen(node: node),
      ),
    );
  }
}
