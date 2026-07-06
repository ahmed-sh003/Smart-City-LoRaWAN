import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../models/ai_models.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class AiInsightCard extends StatelessWidget {
  final AnomalyResult? anomaly;
  final MaintenancePrediction? maintenance;
  final SignalPrediction? signal;
  final String title;

  const AiInsightCard({
    super.key,
    required this.anomaly,
    required this.maintenance,
    this.signal,
    this.title = 'AI Insights',
  });

  @override
  Widget build(BuildContext context) {
    final result = anomaly ?? AnomalyResult.normal();
    final prediction = maintenance ?? MaintenancePrediction.lowRisk();
    final color = _scoreColor(result.anomalyScore);
    return GlassCard(
      borderRadius: 8,
      borderColor: color.withOpacity(0.26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: color, size: 24),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniBadge(
                label: result.isAnomaly ? 'ANOMALY' : 'NORMAL',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircularPercentIndicator(
                radius: 42,
                lineWidth: 8,
                percent: result.anomalyScore.clamp(0.0, 1.0),
                animation: true,
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: AppColors.gaugeTrack,
                progressColor: color,
                center: Text(
                  '${(result.anomalyScore * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.explanation,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ConfidenceBar(
                      confidence: result.confidence,
                      color: color,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                label: prediction.urgencyLevel.toUpperCase(),
                color: _urgencyColor(prediction.urgencyLevel),
              ),
              if (signal != null)
                _MiniBadge(
                  label: signal!.signalQuality.toUpperCase(),
                  color: _signalColor(signal!.signalQuality),
                ),
              _MiniBadge(
                label: DateFormat('HH:mm').format(result.analyzedAt),
                color: AppColors.neonBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prediction.recommendedAction,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (prediction.riskFactors.isNotEmpty ||
              result.affectedFeatures.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final factor in {
                  ...prediction.riskFactors,
                  ...result.affectedFeatures,
                })
                  _FeatureChip(label: factor),
              ],
            ),
          ],
          if (signal != null) ...[
            const Divider(color: AppColors.cardBorder, height: 24),
            Row(
              children: [
                const Icon(
                  Icons.signal_cellular_alt_rounded,
                  color: AppColors.gatewayColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${signal!.predictedRssi.toStringAsFixed(0)} dBm / ${signal!.predictedSnr.toStringAsFixed(1)} dB',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              signal!.recommendation,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.32,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.75) return AppColors.dangerRed;
    if (score >= 0.42) return AppColors.warningOrange;
    return AppColors.successGreen;
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'critical':
      case 'high':
        return AppColors.dangerRed;
      case 'medium':
        return AppColors.warningOrange;
      default:
        return AppColors.successGreen;
    }
  }

  Color _signalColor(String quality) {
    switch (quality) {
      case 'excellent':
      case 'good':
        return AppColors.successGreen;
      case 'fair':
        return AppColors.warningOrange;
      default:
        return AppColors.dangerRed;
    }
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  final Color color;

  const _ConfidenceBar({
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Confidence',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${(confidence * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0),
            minHeight: 7,
            color: color,
            backgroundColor: AppColors.gaugeTrack,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
