import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  Color _bandColor(String band) {
    switch (band) {
      case 'LOW':      return AppColors.riskLow;
      case 'MEDIUM':   return AppColors.riskMedium;
      case 'HIGH':     return AppColors.riskHigh;
      case 'CRITICAL': return AppColors.riskCritical;
      default:         return AppColors.primary;
    }
  }

  IconData _bandIcon(String band) {
    switch (band) {
      case 'LOW':      return Icons.check_circle_rounded;
      case 'MEDIUM':   return Icons.warning_amber_rounded;
      case 'HIGH':     return Icons.dangerous_rounded;
      case 'CRITICAL': return Icons.emergency_rounded;
      default:         return Icons.analytics_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final double probability = (result['probability'] as num).toDouble();
    final String band        = result['riskBand'] ?? 'LOW';
    final String recommendation = result['recommendation'] ?? '';
    final color = _bandColor(band);
    final percent = (probability * 100).clamp(0, 100).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Your Risk Result'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Gauge ──
              CircularPercentIndicator(
                radius: 110,
                lineWidth: 14,
                percent: percent / 100,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${percent.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(height: 4),
                    Text('Risk Score', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                progressColor: color,
                backgroundColor: color.withOpacity(0.12),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 1200,
              ),
              const SizedBox(height: 24),

              // ── Band badge ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: color.withOpacity(0.4))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_bandIcon(band), color: color, size: 22),
                    const SizedBox(width: 8),
                    Text('$band RISK',
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Recommendation ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text('Recommendation',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(recommendation,
                        style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Risk scale legend ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Risk Scale', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    ...[
                      ['LOW',      '0–25%',  AppColors.riskLow],
                      ['MEDIUM',   '25–50%', AppColors.riskMedium],
                      ['HIGH',     '50–75%', AppColors.riskHigh],
                      ['CRITICAL', '75–100%',AppColors.riskCritical],
                    ].map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: e[2] as Color, shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Text('${e[0]}  ', style: TextStyle(fontWeight: FontWeight.w600, color: e[2] as Color, fontSize: 13)),
                              Text(e[1] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (band == 'CRITICAL' || band == 'HIGH')
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/fast'),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Check FAST Symptoms'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.riskHigh),
                ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
