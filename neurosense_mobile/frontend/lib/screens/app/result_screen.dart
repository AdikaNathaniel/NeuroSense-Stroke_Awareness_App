import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../services/language_service.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin, LanguageAware {
  late final AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double start, double end) =>
      CurvedAnimation(parent: _entryCtrl, curve: Interval(start, end, curve: Curves.easeOutCubic));

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

  String _bandHeadline(String band) {
    switch (band) {
      case 'LOW':      return 'Looking healthy';
      case 'MEDIUM':   return 'Some areas to watch';
      case 'HIGH':     return 'Your risk is elevated';
      case 'CRITICAL': return 'Immediate attention recommended';
      default:         return 'Risk Assessment';
    }
  }

  List<String> _actionsForBand(String band) {
    switch (band) {
      case 'LOW':
        return [
          'Stay physically active — aim for 30+ minutes most days',
          'Maintain a balanced diet rich in fruits and vegetables',
          'Schedule annual health check-ups to stay on track',
        ];
      case 'MEDIUM':
        return [
          'Reduce salt intake to under 5g per day',
          'Aim for 150 minutes of moderate exercise per week',
          'Monitor your blood pressure regularly',
          'Cut back on processed and high-sugar foods',
        ];
      case 'HIGH':
        return [
          'Schedule a General Practitioner appointment within 2 weeks',
          'Track blood pressure and glucose daily',
          'If you smoke, talk to your General Practitioner about quitting support',
          'Limit alcohol and follow a heart-healthy diet',
        ];
      case 'CRITICAL':
        return [
          'Seek immediate medical evaluation',
          'If you experience FAST symptoms, call emergency services',
          'Have a list of medications and conditions ready for the doctor',
          'Avoid strenuous activity until cleared by a clinician',
        ];
      default:
        return [];
    }
  }

  List<_RiskFactor> _identifyRiskFactors(Map<String, dynamic> inputs) {
    final factors = <_RiskFactor>[];
    final age = (inputs['age'] as num?)?.toDouble() ?? 0;
    final glu = (inputs['avg_glucose_level'] as num?)?.toDouble() ?? 0;
    final bmi = (inputs['bmi'] as num?)?.toDouble() ?? 0;
    final hyp = inputs['hypertension'] == 1;
    final hd  = inputs['heart_disease'] == 1;
    final smk = (inputs['smoking_status'] as String?) ?? 'never smoked';

    if (age >= 65) {
      factors.add(_RiskFactor('Age ${age.toStringAsFixed(0)} · older adult', Icons.elderly_rounded, AppColors.riskHigh));
    } else if (age >= 50) {
      factors.add(_RiskFactor('Age ${age.toStringAsFixed(0)}', Icons.person_outline, AppColors.riskMedium));
    }
    if (hyp) factors.add(_RiskFactor('Hypertension', Icons.monitor_heart_outlined, AppColors.riskHigh));
    if (hd)  factors.add(_RiskFactor('Heart disease', Icons.favorite_border, AppColors.riskHigh));

    if (glu >= 200) {
      factors.add(_RiskFactor('Glucose ${glu.toStringAsFixed(0)} · severe', Icons.bloodtype_outlined, AppColors.riskHigh));
    } else if (glu >= 126) {
      factors.add(_RiskFactor('Glucose ${glu.toStringAsFixed(0)} · diabetic', Icons.bloodtype_outlined, AppColors.riskHigh));
    } else if (glu >= 100) {
      factors.add(_RiskFactor('Glucose ${glu.toStringAsFixed(0)} · pre-diabetic', Icons.bloodtype_outlined, AppColors.riskMedium));
    }

    if (bmi >= 35) {
      factors.add(_RiskFactor('BMI ${bmi.toStringAsFixed(1)} · severe', Icons.monitor_weight_outlined, AppColors.riskHigh));
    } else if (bmi >= 30) {
      factors.add(_RiskFactor('BMI ${bmi.toStringAsFixed(1)} · obese', Icons.monitor_weight_outlined, AppColors.riskMedium));
    } else if (bmi < 18.5 && bmi > 0) {
      factors.add(_RiskFactor('BMI ${bmi.toStringAsFixed(1)} · underweight', Icons.monitor_weight_outlined, AppColors.riskMedium));
    }

    if (smk == 'smokes') {
      factors.add(_RiskFactor('Active smoker', Icons.smoking_rooms_outlined, AppColors.riskHigh));
    } else if (smk == 'formerly smoked') {
      factors.add(_RiskFactor('Former smoker', Icons.smoke_free_outlined, AppColors.riskMedium));
    }

    return factors;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final probability = (args['probability'] as num).toDouble();
    final band = (args['riskBand'] ?? 'LOW') as String;
    final recommendation = (args['recommendation'] ?? '') as String;
    final inputs = (args['inputs'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final color = _bandColor(band);
    final percent = (probability * 100).clamp(0, 100).toDouble();
    final factors = _identifyRiskFactors(inputs);
    final actions = _actionsForBand(band);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Risk Result'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            children: [
              _AnimatedSection(
                animation: _stagger(0.0, 0.5),
                child: _GaugeHero(
                  percent: percent,
                  color: color,
                  band: band,
                  bandIcon: _bandIcon(band),
                  headline: _bandHeadline(band),
                ),
              ),
              const SizedBox(height: 18),

              _AnimatedSection(
                animation: _stagger(0.15, 0.65),
                child: _Card(
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'What this means',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recommendation,
                          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Recommended next steps',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 0.4)),
                        const SizedBox(height: 10),
                        ...actions.map((a) => _Bullet(text: a, color: color)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (factors.isNotEmpty) ...[
                _AnimatedSection(
                  animation: _stagger(0.3, 0.8),
                  child: _Card(
                    icon: Icons.flag_circle_outlined,
                    iconColor: AppColors.primary,
                    title: 'Key risk factors',
                    child: Column(
                      children: factors
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34, height: 34,
                                      decoration: BoxDecoration(color: f.color.withOpacity(0.12), shape: BoxShape.circle),
                                      child: Icon(f.icon, color: f.color, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(
                                      f.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                                    )),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              _AnimatedSection(
                animation: _stagger(0.45, 0.95),
                child: _Card(
                  icon: Icons.bar_chart_rounded,
                  iconColor: AppColors.primary,
                  title: 'Risk scale',
                  child: Column(
                    children: [
                      _ScaleRow(label: 'LOW',      range: '0–25%',   color: AppColors.riskLow,      isActive: band == 'LOW'),
                      _ScaleRow(label: 'MEDIUM',   range: '25–50%',  color: AppColors.riskMedium,   isActive: band == 'MEDIUM'),
                      _ScaleRow(label: 'HIGH',     range: '50–75%',  color: AppColors.riskHigh,     isActive: band == 'HIGH'),
                      _ScaleRow(label: 'CRITICAL', range: '75–100%', color: AppColors.riskCritical, isActive: band == 'CRITICAL'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskFactor {
  final String label;
  final IconData icon;
  final Color color;
  const _RiskFactor(this.label, this.icon, this.color);
}

class _AnimatedSection extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedSection({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 24),
          child: child,
        ),
      ),
    );
  }
}

class _GaugeHero extends StatelessWidget {
  final double percent;
  final Color color;
  final String band;
  final IconData bandIcon;
  final String headline;
  const _GaugeHero({
    required this.percent,
    required this.color,
    required this.band,
    required this.bandIcon,
    required this.headline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.07), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow
              Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 40, spreadRadius: 4)],
                ),
              ),
              CircularPercentIndicator(
                radius: 120,
                lineWidth: 18,
                percent: percent / 100,
                center: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: percent),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${value.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: color, height: 1.0)),
                      const SizedBox(height: 6),
                      const Text('Stroke risk score',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 0.4)),
                    ],
                  ),
                ),
                progressColor: color,
                backgroundColor: color.withOpacity(0.10),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 1200,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(bandIcon, color: color, size: 20),
                const SizedBox(width: 8),
                Text('$band RISK',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.2)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(headline,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.iconColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color color;
  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text,
              style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _ScaleRow extends StatelessWidget {
  final String label;
  final String range;
  final Color color;
  final bool isActive;
  const _ScaleRow({required this.label, required this.range, required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 0, vertical: isActive ? 8 : 0),
        decoration: isActive
            ? BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.4)),
              )
            : null,
        child: Row(
          children: [
            Container(width: 12, height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: color, fontSize: 13)),
            const SizedBox(width: 8),
            Text(range, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (isActive) ...[
              const Spacer(),
              Icon(Icons.check_circle, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
