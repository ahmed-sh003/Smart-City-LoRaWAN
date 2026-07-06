import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/ai_command_center_widgets.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/status_chip.dart';
import '../core/widgets/system_architecture_section.dart';
import '../models/bridge_model.dart';
import '../models/building_model.dart';
import '../models/mlops_models.dart';
import '../models/water_model.dart';
import '../providers/ai_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/mlops_report_service.dart';
import 'alerts_screen.dart';
import 'bridge_screen.dart';
import 'building_screen.dart';
import 'gateway_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'water_screen.dart';

enum CityDomain { building, bridge, water, gateway }

const _cityImage = 'assets/images/lorawan_city_topology.webp';
const _buildingImage = 'assets/images/building_aiot.png';
const _bridgeImage = 'assets/images/bridge_lora_monitoring.webp';
const _waterImage = 'assets/images/water_treatment_network.png';
const _gatewayImage = 'assets/images/lorawan_city_topology.webp';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final pages = [
      _HomeTab(onOpenAiCenter: () => setState(() => _index = 3)),
      const _DomainsTab(),
      const AlertsScreen(isEmbedded: true),
      const ReportsScreen(isEmbedded: true),
      const GatewayScreen(isEmbedded: true),
      const SettingsScreen(isEmbedded: true),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: pages[_index],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 8,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(
            icon: Icon(Icons.dashboard_customize_rounded),
            label: 'Domains',
          ),
          NavigationDestination(
            icon: provider.activeAlertCount > 0
                ? Badge(
                    label: Text('${provider.activeAlertCount}'),
                    child: const Icon(Icons.notification_important_rounded),
                  )
                : const Icon(Icons.notification_important_rounded),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_rounded),
            label: 'Reports',
          ),
          const NavigationDestination(
            icon: Icon(Icons.cell_tower_rounded),
            label: 'Gateway',
          ),
          const NavigationDestination(
              icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final VoidCallback onOpenAiCenter;

  const _HomeTab({required this.onOpenAiCenter});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _Hero(provider: provider)),
        SliverToBoxAdapter(
          child: _ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: _AiInsightsPanel(
              provider: provider,
              onOpenAiCenter: onOpenAiCenter,
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeaderDelegate(
            height: 72,
            child: _ResponsiveContent(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: _SectionHeader(
                title: 'Domain Nodes',
                subtitle: 'Real SC1 field nodes mapped to Firebase',
                trailing: StatusChip(
                  label: '${provider.totalOnlineNodes}/3 ONLINE',
                  type: provider.totalOnlineNodes == 3
                      ? StatusType.online
                      : StatusType.warning,
                  animated: false,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: _DomainGrid(
              configs: [
                _buildingConfig(provider),
                _bridgeConfig(provider),
                _waterConfig(provider),
                _gatewayConfig(provider),
              ],
              onSelected: (config) => _openDomain(context, config.domain),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: SystemArchitectureSection(provider: provider),
          ),
        ),
        SliverToBoxAdapter(
          child: _ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: _SystemSummary(provider: provider),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _DomainsTab extends StatelessWidget {
  const _DomainsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final configs = [
      _buildingConfig(provider),
      _bridgeConfig(provider),
      _waterConfig(provider),
      _gatewayConfig(provider),
    ];
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: _ResponsiveContent(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Infrastructure OS',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Building, road, water, and gateway views',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            child: _DomainGrid(
              configs: configs,
              onSelected: (config) => _openDomain(context, config.domain),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final DashboardProvider provider;

  const _Hero({required this.provider});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final heroHeight = screenWidth > 700 ? 246.0 : 228.0;
    final statusColor = provider.cityStatus == 'SAFE'
        ? AppColors.successGreen
        : provider.cityStatus == 'WARNING'
            ? AppColors.warningOrange
            : AppColors.dangerRed;
    return SafeArea(
      bottom: false,
      child: _ResponsiveContent(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              SizedBox(
                height: heroHeight,
                width: double.infinity,
                child: Image.asset(
                  _cityImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.neonBlue.withOpacity(0.12),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.72),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                      label: provider.cityStatus,
                      type: provider.cityStatus == 'SAFE'
                          ? StatusType.online
                          : provider.cityStatus == 'WARNING'
                              ? StatusType.warning
                              : StatusType.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SmartCity LPWAN',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: screenWidth > 520 ? 28 : 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Real-time mobile monitoring for the SC1 sender nodes and ESP32 gateway.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _HeroStat(
                          label: 'Nodes',
                          value: '${provider.totalOnlineNodes}/3',
                          color: AppColors.successGreen,
                        ),
                        const SizedBox(width: 10),
                        _HeroStat(
                          label: 'Alerts',
                          value: '${provider.activeAlertCount}',
                          color: statusColor,
                        ),
                        const SizedBox(width: 10),
                        _HeroStat(
                          label: 'Packets',
                          value: '${provider.gateway?.totalPackets ?? 0}',
                          color: AppColors.neonBlue,
                        ),
                      ],
                    ),
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

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.78),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInsightsPanel extends StatefulWidget {
  final DashboardProvider provider;
  final VoidCallback onOpenAiCenter;

  const _AiInsightsPanel({
    required this.provider,
    required this.onOpenAiCenter,
  });

  @override
  State<_AiInsightsPanel> createState() => _AiInsightsPanelState();
}

class _AiInsightsPanelState extends State<_AiInsightsPanel> {
  late final Future<MlopsSummary> _summaryFuture =
      const MlopsReportService().loadSummary();

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    return FutureBuilder<MlopsSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        return AiHomeInsightCard(
          dashboard: widget.provider,
          ai: ai,
          summary: snapshot.data ?? MlopsSummary.fallback(),
          onOpenAiCenter: widget.onOpenAiCenter,
          onRunAnalysis: ai.isAnalyzing
              ? null
              : () => context.read<AiProvider>().runFullAnalysis(
                    widget.provider,
                  ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _PinnedHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

class _ResponsiveContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ResponsiveContent({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _DomainConfig {
  final CityDomain domain;
  final String title;
  final String subtitle;
  final String image;
  final IconData icon;
  final Color color;
  final bool online;
  final bool alert;
  final String batteryMetric;
  final String signalMetric;
  final String lastUpdateMetric;
  final bool isLoading;
  final int lineSeed;

  const _DomainConfig({
    required this.domain,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.icon,
    required this.color,
    required this.online,
    required this.alert,
    required this.batteryMetric,
    required this.signalMetric,
    required this.lastUpdateMetric,
    required this.isLoading,
    required this.lineSeed,
  });
}

class _DomainGrid extends StatelessWidget {
  final List<_DomainConfig> configs;
  final ValueChanged<_DomainConfig> onSelected;

  const _DomainGrid({
    required this.configs,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1020
            ? 4
            : width >= 680
                ? 2
                : 1;
        return GridView.builder(
          itemCount: configs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: columns == 1 ? 330 : 342,
          ),
          itemBuilder: (context, index) {
            final config = configs[index];
            return _DomainCard(
              config: config,
              onTap: () => onSelected(config),
              index: index,
            );
          },
        );
      },
    );
  }
}

class _DomainCard extends StatefulWidget {
  final _DomainConfig config;
  final VoidCallback onTap;
  final int index;

  const _DomainCard({
    required this.config,
    required this.onTap,
    required this.index,
  });

  @override
  State<_DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends State<_DomainCard> {
  bool _hovered = false;

  _DomainConfig get config => widget.config;

  void _setHover(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = config.alert
        ? AppColors.dangerRed
        : config.online
            ? AppColors.successGreen
            : AppColors.textMuted;
    final statusLabel = config.alert
        ? 'ALERT'
        : config.online
            ? config.domain == CityDomain.gateway
                ? 'ONLINE'
                : 'SAFE'
            : 'LOST';
    final statusIcon = config.alert
        ? Icons.warning_rounded
        : config.online
            ? Icons.check_rounded
            : Icons.cloud_off_rounded;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 480 + widget.index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: AnimatedScale(
          scale: _hovered ? 1.018 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovered
                    ? config.color.withOpacity(0.46)
                    : config.alert
                        ? AppColors.dangerRed.withOpacity(0.38)
                        : AppColors.cardBorder,
                width: _hovered || config.alert ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_hovered
                          ? config.color
                          : config.alert
                              ? AppColors.dangerRed
                              : Colors.black)
                      .withOpacity(_hovered || config.alert ? 0.15 : 0.08),
                  blurRadius: _hovered ? 34 : 24,
                  offset: Offset(0, _hovered ? 18 : 12),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.72),
                  blurRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                splashColor: config.color.withOpacity(0.06),
                highlightColor: config.color.withOpacity(0.04),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DomainImageHeader(
                          config: config,
                          statusColor: statusColor,
                          statusIcon: statusIcon,
                          statusLabel: statusLabel,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                    height: 1.38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 46,
                                  width: double.infinity,
                                  child: _TelemetrySparkline(
                                    color: config.alert
                                        ? AppColors.dangerRed
                                        : config.color,
                                    seed: config.lineSeed,
                                    alert: config.alert,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DomainMetric(
                                        icon:
                                            Icons.battery_charging_full_rounded,
                                        label:
                                            config.domain == CityDomain.gateway
                                                ? 'Nodes'
                                                : 'Battery',
                                        value: config.batteryMetric,
                                        color: config.online
                                            ? AppColors.successGreen
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _DomainMetric(
                                        icon: Icons.network_check_rounded,
                                        label: 'RSSI / SNR',
                                        value: config.signalMetric,
                                        color: config.color,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _DomainMetric(
                                        icon: Icons.schedule_rounded,
                                        label: 'Updated',
                                        value: config.lastUpdateMetric,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (config.isLoading) const _DomainShimmerOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DomainImageHeader extends StatelessWidget {
  final _DomainConfig config;
  final Color statusColor;
  final IconData statusIcon;
  final String statusLabel;

  const _DomainImageHeader({
    required this.config,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
  });

  static const _contrast = 1.08;
  static const _brightness = 7.0;
  static const _translate = 128 * (1 - _contrast) + _brightness;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: 142,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  _contrast,
                  0,
                  0,
                  0,
                  _translate,
                  0,
                  _contrast,
                  0,
                  0,
                  _translate,
                  0,
                  0,
                  _contrast,
                  0,
                  _translate,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Image.asset(
                  config.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          config.color.withOpacity(0.92),
                          config.color.withOpacity(0.62),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.35),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DomainIconOrb(
                        icon: config.icon,
                        color: config.color,
                        onImage: true,
                      ),
                      const Spacer(),
                      _LivePulse(color: statusColor, active: config.online),
                      const SizedBox(width: 9),
                      _DomainStatusChip(
                        label: statusLabel,
                        icon: statusIcon,
                        color: statusColor,
                        onImage: true,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    config.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.06,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.24),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainIconOrb extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool onImage;

  const _DomainIconOrb({
    required this.icon,
    required this.color,
    this.onImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: onImage
              ? [
                  Colors.white.withOpacity(0.94),
                  Colors.white.withOpacity(0.78),
                ]
              : [
                  color.withOpacity(0.16),
                  color.withOpacity(0.06),
                ],
        ),
        border: Border.all(
          color: onImage
              ? Colors.white.withOpacity(0.64)
              : color.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: (onImage ? Colors.black : color).withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _DomainStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool onImage;

  const _DomainStatusChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color:
            onImage ? Colors.white.withOpacity(0.88) : color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onImage
              ? Colors.white.withOpacity(0.58)
              : color.withOpacity(0.20),
        ),
        boxShadow: onImage
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
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
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePulse extends StatefulWidget {
  final Color color;
  final bool active;

  const _LivePulse({
    required this.color,
    required this.active,
  });

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.color : AppColors.textMuted;
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pulse = widget.active ? _controller.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 10 + pulse * 8,
                height: 10 + pulse * 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity((1 - pulse) * 0.20),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.42),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TelemetrySparkline extends StatefulWidget {
  final Color color;
  final int seed;
  final bool alert;

  const _TelemetrySparkline({
    required this.color,
    required this.seed,
    required this.alert,
  });

  @override
  State<_TelemetrySparkline> createState() => _TelemetrySparklineState();
}

class _TelemetrySparklineState extends State<_TelemetrySparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _TelemetrySparklinePainter(
            color: widget.color,
            progress: _controller.value,
            seed: widget.seed,
            alert: widget.alert,
          ),
        );
      },
    );
  }
}

class _TelemetrySparklinePainter extends CustomPainter {
  final Color color;
  final double progress;
  final int seed;
  final bool alert;

  const _TelemetrySparklinePainter({
    required this.color,
    required this.progress,
    required this.seed,
    required this.alert,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.cardBorder.withOpacity(0.65)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final fillPath = Path();
    final path = Path();
    final points = <Offset>[];
    final count = 9;
    for (var i = 0; i < count; i++) {
      final x = size.width * i / (count - 1);
      final wave = math.sin((i + seed * 0.7 + progress * 2.0) * math.pi / 2.2);
      final micro = math.cos((i * 1.6 + seed + progress * 3.0) * math.pi / 3.0);
      final alertLift = alert && i > 4 ? -8.0 : 0.0;
      final y = size.height * 0.52 -
          wave * size.height * 0.18 -
          micro * size.height * 0.07 +
          alertLift;
      points.add(Offset(x, y.clamp(8.0, size.height - 8)));
    }
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
        fillPath.moveTo(points[i].dx, size.height);
        fillPath.lineTo(points[i].dx, points[i].dy);
      } else {
        final previous = points[i - 1];
        final current = points[i];
        final controlX = (previous.dx + current.dx) / 2;
        path.cubicTo(controlX, previous.dy, controlX, current.dy, current.dx,
            current.dy);
        fillPath.cubicTo(controlX, previous.dy, controlX, current.dy,
            current.dx, current.dy);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.14),
            color.withOpacity(0.01),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round,
    );

    final dotIndex =
        ((progress * (points.length - 1)).floor()).clamp(0, points.length - 1);
    final dot = points[dotIndex];
    canvas.drawCircle(
      dot,
      4.5,
      Paint()..color = color.withOpacity(0.18),
    );
    canvas.drawCircle(dot, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TelemetrySparklinePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        alert != oldDelegate.alert;
  }
}

class _DomainMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DomainMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainShimmerOverlay extends StatefulWidget {
  const _DomainShimmerOverlay();

  @override
  State<_DomainShimmerOverlay> createState() => _DomainShimmerOverlayState();
}

class _DomainShimmerOverlayState extends State<_DomainShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FractionalTranslation(
              translation: Offset(-1.2 + _controller.value * 2.4, 0),
              child: Container(
                width: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.34),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SystemSummary extends StatelessWidget {
  final DashboardProvider provider;

  const _SystemSummary({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SC1 Protocol Coverage',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _SummaryLine(
              text:
                  'Flags decoded: Alert, Low Battery, Sensor Error, Event Packet, Actuator Active'),
          _SummaryLine(
              text:
                  'Firebase paths: nodes/building, nodes/bridge, nodes/water, gateway, alerts'),
          _SummaryLine(
              text: provider.useMockData
                  ? 'Mock mode is active: ${provider.mockScenario.label}'
                  : 'Firebase live mode is active'),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String text;

  const _SummaryLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.successGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_DomainConfig _buildingConfig(DashboardProvider provider) {
  final BuildingModel? building = provider.building;
  final status = building?.status;
  return _DomainConfig(
    domain: CityDomain.building,
    title: 'Building & Irrigation',
    subtitle: 'Climate, air quality, soil moisture, rain, and power telemetry',
    image: _buildingImage,
    icon: Icons.apartment_rounded,
    color: AppColors.buildingColor,
    online: status?.online ?? false,
    alert: building?.hasAlert ?? false,
    batteryMetric: status?.batteryPercentStr ?? '--',
    signalMetric: status == null
        ? '--'
        : '${status.rssi.toStringAsFixed(0)} / ${status.snr.toStringAsFixed(1)}',
    lastUpdateMetric: status?.ageLabel ?? '--',
    isLoading: building == null,
    lineSeed: status?.seq ?? 11,
  );
}

_DomainConfig _bridgeConfig(DashboardProvider provider) {
  final BridgeModel? bridge = provider.bridge;
  final status = bridge?.status;
  return _DomainConfig(
    domain: CityDomain.bridge,
    title: 'Bridge / Road',
    subtitle: 'Traffic counting, danger switches, servo gates, and buzzer',
    image: _bridgeImage,
    icon: Icons.alt_route_rounded,
    color: AppColors.bridgeColor,
    online: status?.online ?? false,
    alert: bridge?.hasAlert ?? false,
    batteryMetric: status?.batteryPercentStr ?? '--',
    signalMetric: status == null
        ? '--'
        : '${status.rssi.toStringAsFixed(0)} / ${status.snr.toStringAsFixed(1)}',
    lastUpdateMetric: status?.ageLabel ?? '--',
    isLoading: bridge == null,
    lineSeed: status?.seq ?? 22,
  );
}

_DomainConfig _waterConfig(DashboardProvider provider) {
  final WaterModel? water = provider.water;
  final status = water?.status;
  return _DomainConfig(
    domain: CityDomain.water,
    title: 'Water Network',
    subtitle: 'Rain, pipe soil, dual tank levels, difference, and leak risk',
    image: _waterImage,
    icon: Icons.water_drop_rounded,
    color: AppColors.waterColor,
    online: status?.online ?? false,
    alert: water?.hasAlert ?? false,
    batteryMetric: status?.batteryPercentStr ?? '--',
    signalMetric: status == null
        ? '--'
        : '${status.rssi.toStringAsFixed(0)} / ${status.snr.toStringAsFixed(1)}',
    lastUpdateMetric: status?.ageLabel ?? '--',
    isLoading: water == null,
    lineSeed: status?.seq ?? 33,
  );
}

_DomainConfig _gatewayConfig(DashboardProvider provider) {
  final gateway = provider.gateway;
  return _DomainConfig(
    domain: CityDomain.gateway,
    title: 'Gateway Health',
    subtitle: 'ESP32 LoRa receiver, PDR, Firebase sync, WiFi state',
    image: _gatewayImage,
    icon: Icons.cell_tower_rounded,
    color: AppColors.gatewayColor,
    online: gateway?.online ?? false,
    alert: gateway?.online == false,
    batteryMetric: gateway == null ? '--' : '${gateway.onlineNodes}/3',
    signalMetric: gateway == null
        ? '--'
        : '${gateway.averageRssi.toStringAsFixed(0)} / ${gateway.averageSnr.toStringAsFixed(1)}',
    lastUpdateMetric: gateway?.ageLabel ?? '--',
    isLoading: gateway == null,
    lineSeed: gateway?.totalPackets ?? 44,
  );
}

void _openDomain(BuildContext context, CityDomain domain) {
  switch (domain) {
    case CityDomain.building:
      _open(context, const BuildingScreen());
      break;
    case CityDomain.bridge:
      _open(context, const BridgeScreen());
      break;
    case CityDomain.water:
      _open(context, const WaterScreen());
      break;
    case CityDomain.gateway:
      _open(context, const GatewayScreen());
      break;
  }
}

void _open(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    MaterialPageRoute(
      allowSnapshotting: false,
      builder: (_) => screen,
    ),
  );
}
