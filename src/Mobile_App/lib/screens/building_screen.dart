import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/ai_insight_card.dart';
import '../core/widgets/alert_banner.dart';
import '../core/widgets/domain_header.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/node_flow_card.dart';
import '../core/widgets/node_telemetry_card.dart';
import '../core/widgets/section_title.dart';
import '../core/widgets/sensor_gauge.dart';
import '../core/widgets/visual_asset_card.dart';
import '../models/building_model.dart';
import '../providers/ai_provider.dart';
import '../providers/dashboard_provider.dart';

class BuildingScreen extends StatelessWidget {
  const BuildingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardProvider>().building;
    if (model == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _BuildingBody(model: model);
  }
}

class _BuildingBody extends StatelessWidget {
  final BuildingModel model;

  const _BuildingBody({required this.model});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 188,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: DomainHeader(
                title: 'Building & Irrigation',
                subtitle: 'BMP280, DHT11, MQ sensors, soil, rain, battery',
                icon: Icons.apartment_rounded,
                color: AppColors.buildingColor,
                gradient: AppColors.buildingGradient,
                online: model.status.online,
                imageAsset: 'assets/images/building_aiot.png',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                AlertBanner(
                  message: model.hasAlert
                      ? 'Building node requires attention. Check decoded flags and sensor readings.'
                      : 'Building and irrigation node is operating normally.',
                  type: model.hasAlert
                      ? AlertBannerType.critical
                      : AlertBannerType.normal,
                ),
                const SizedBox(height: 20),
                const VisualAssetCard(
                  title: 'Building & Irrigation Node Diagram',
                  subtitle:
                      'Smart building systems mapped to DHT11, BMP280, MQ sensors, soil, and rain',
                  imageAsset: 'assets/images/building_aiot.png',
                  icon: Icons.apartment_rounded,
                  color: AppColors.buildingColor,
                  aspectRatio: 1.45,
                  fit: BoxFit.contain,
                  badges: [
                    'Building',
                    'Irrigation',
                    'MQ2/MQ5/MQ135',
                    'Soil/Rain'
                  ],
                ),
                const SizedBox(height: 14),
                const NodeFlowCard(
                  title: 'Node Shape',
                  subtitle:
                      'Real hardware inputs are packed into SC1 values, flags, battery, RSSI, and SNR.',
                  icon: Icons.memory_rounded,
                  color: AppColors.buildingColor,
                  steps: [
                    NodeFlowStep(
                      title: 'Air Node',
                      subtitle: 'DHT11 + BMP280',
                      icon: Icons.thermostat_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Safety',
                      subtitle: 'MQ2, MQ5, MQ135',
                      icon: Icons.air_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Irrigation',
                      subtitle: 'Soil + rain sensor',
                      icon: Icons.water_drop_rounded,
                    ),
                    NodeFlowStep(
                      title: 'SC1 Packet',
                      subtitle: 'v1..v7 + flags',
                      icon: Icons.code_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Gateway',
                      subtitle: 'LoRa to Firebase',
                      icon: Icons.cell_tower_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Environmental Sensors',
                  icon: Icons.thermostat_rounded,
                  iconColor: AppColors.buildingColor,
                ),
                GlassCard(
                  borderColor: AppColors.buildingColor.withOpacity(0.2),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    alignment: WrapAlignment.spaceAround,
                    children: [
                      SensorGauge(
                        label: 'Temperature',
                        value: model.temperature,
                        maxValue: 50,
                        unit: 'C',
                        color: model.temperature > 35
                            ? AppColors.dangerRed
                            : AppColors.warningOrange,
                        size: 102,
                      ),
                      SensorGauge(
                        label: 'Humidity',
                        value: model.humidity,
                        maxValue: 100,
                        unit: '%',
                        color: AppColors.neonBlue,
                        size: 102,
                      ),
                      _ValueTile(
                        label: 'Pressure',
                        value: model.pressure > 0
                            ? model.pressure.toStringAsFixed(1)
                            : '--',
                        unit: 'hPa',
                        icon: Icons.compress_rounded,
                        color: AppColors.buildingColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Air Safety',
                  icon: Icons.air_rounded,
                  iconColor: AppColors.warningOrange,
                ),
                GlassCard(
                  borderColor: (model.hasAlert
                          ? AppColors.dangerRed
                          : AppColors.warningOrange)
                      .withOpacity(0.22),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 18,
                        alignment: WrapAlignment.spaceAround,
                        children: [
                          SensorGauge(
                            label: 'Air Quality MQ135',
                            value: model.airQuality,
                            maxValue: 2000,
                            unit: 'ppm',
                            color: model.airQuality > 1000
                                ? AppColors.dangerRed
                                : AppColors.successGreen,
                            size: 96,
                          ),
                          SensorGauge(
                            label: 'Smoke MQ2',
                            value: model.smoke,
                            maxValue: 1000,
                            unit: 'ppm',
                            color: model.smoke > 400
                                ? AppColors.dangerRed
                                : AppColors.warningOrange,
                            size: 96,
                          ),
                          _GasTile(model: model),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusPill(
                            label: 'Air: ${model.airQualityLabel}',
                            color: model.airQuality > 1000
                                ? AppColors.dangerRed
                                : AppColors.successGreen,
                          ),
                          _StatusPill(
                            label: 'Smoke: ${model.smokeLabel}',
                            color: model.smoke > 400
                                ? AppColors.dangerRed
                                : AppColors.successGreen,
                          ),
                          _StatusPill(
                            label: 'MQ5: ${model.gasLabel}',
                            color: (model.gas ?? 0) > 450
                                ? AppColors.dangerRed
                                : AppColors.neonBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Irrigation & Rain',
                  icon: Icons.water_drop_rounded,
                  iconColor: AppColors.successGreen,
                ),
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        borderColor: AppColors.successGreen.withOpacity(0.22),
                        child: Column(
                          children: [
                            SensorGauge(
                              label: 'Soil Moisture',
                              value: model.soilMoisture,
                              maxValue: 100,
                              unit: '%',
                              color: model.soilMoisture < 30
                                  ? AppColors.dangerRed
                                  : AppColors.successGreen,
                              size: 104,
                            ),
                            const SizedBox(height: 6),
                            _StatusPill(
                              label: model.soilLabel,
                              color: model.soilMoisture < 30
                                  ? AppColors.dangerRed
                                  : AppColors.successGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        borderColor: AppColors.neonBlue.withOpacity(0.22),
                        child: _BinaryFeature(
                          active: model.rain,
                          activeLabel: 'Raining',
                          inactiveLabel: 'No Rain',
                          label: 'Rain Sensor',
                          activeIcon: Icons.grain_rounded,
                          inactiveIcon: Icons.wb_sunny_rounded,
                          color: AppColors.neonBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'SC1 Telemetry',
                  icon: Icons.settings_input_antenna_rounded,
                  iconColor: AppColors.neonBlue,
                ),
                NodeTelemetryCard(
                  status: model.status,
                  accentColor: AppColors.buildingColor,
                ),
                const SizedBox(height: 14),
                Consumer<AiProvider>(
                  builder: (context, ai, _) => AiInsightCard(
                    anomaly: ai.getNodeAnomaly('building'),
                    maintenance: ai.getMaintenancePrediction('building'),
                    signal: ai.getSignalPrediction('gateway'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GasTile extends StatelessWidget {
  final BuildingModel model;

  const _GasTile({required this.model});

  @override
  Widget build(BuildContext context) {
    final gas = model.gas;
    if (gas == null) {
      return _ValueTile(
        label: 'Gas MQ5',
        value: '--',
        unit: 'optional',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.textMuted,
      );
    }
    return SensorGauge(
      label: 'Gas MQ5',
      value: gas,
      maxValue: 1000,
      unit: 'ppm',
      color: gas > 450 ? AppColors.dangerRed : AppColors.neonBlue,
      size: 96,
    );
  }
}

class _BinaryFeature extends StatelessWidget {
  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color color;

  const _BinaryFeature({
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = active ? color : AppColors.warningOrange;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? activeIcon : inactiveIcon,
            color: effectiveColor,
            size: 30,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          active ? activeLabel : inactiveLabel,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ValueTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _ValueTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.inter(color: color, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style:
                GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
