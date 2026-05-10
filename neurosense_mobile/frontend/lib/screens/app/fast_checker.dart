import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class FastCheckerScreen extends StatefulWidget {
  final VoidCallback? onGoHome;
  const FastCheckerScreen({super.key, this.onGoHome});
  @override
  State<FastCheckerScreen> createState() => _FastCheckerScreenState();
}

class _FastCheckerScreenState extends State<FastCheckerScreen> {
  int _current = 0;

  final List<_FastItem> _items = [
    _FastItem(
      letter: 'F',
      title: 'Face Drooping',
      description: 'Ask the person to smile. Is one side of their face drooping or numb? An uneven smile is a warning sign.',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: AppColors.riskHigh,
      checkLabel: 'Face drooping?',
    ),
    _FastItem(
      letter: 'A',
      title: 'Arm Weakness',
      description: 'Ask the person to raise both arms. Does one arm drift downward or feel weak or numb?',
      icon: Icons.back_hand_outlined,
      color: AppColors.riskMedium,
      checkLabel: 'Arm weakness?',
    ),
    _FastItem(
      letter: 'S',
      title: 'Speech Difficulty',
      description: 'Ask the person to repeat a simple sentence. Is their speech slurred, strange, or hard to understand?',
      icon: Icons.record_voice_over_outlined,
      color: AppColors.primaryLight,
      checkLabel: 'Speech difficulty?',
    ),
    _FastItem(
      letter: 'T',
      title: 'Time to Call',
      description: 'If you see ANY of these signs, call emergency services IMMEDIATELY. Time lost is brain lost. Do not wait.',
      icon: Icons.phone_in_talk_rounded,
      color: AppColors.riskCritical,
      checkLabel: 'Call emergency now',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[_current];
    return Scaffold(
      appBar: AppBar(title: const Text('F.A.S.T. Checker'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Step indicator ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_items.length, (i) {
                  final active = i == _current;
                  final done   = i < _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 36 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: done ? AppColors.riskLow : active ? item.color : AppColors.divider,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // ── Card ──
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    key: ValueKey(_current),
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: item.color.withOpacity(0.25), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                          child: Center(
                            child: Text(item.letter,
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Icon(item.icon, size: 56, color: item.color),
                        const SizedBox(height: 16),
                        Text(item.title,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: item.color)),
                        const SizedBox(height: 14),
                        Text(item.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Navigation ──
              if (_current < _items.length - 1)
                ElevatedButton(
                  onPressed: () => setState(() => _current++),
                  child: const Text('Next'),
                )
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri(scheme: 'tel', path: '911');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call Emergency Services'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.riskCritical),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => widget.onGoHome != null
                          ? widget.onGoHome!()
                          : Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),

              if (_current > 0) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _current--),
                  child: const Text('← Previous'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FastItem {
  final String letter, title, description, checkLabel;
  final IconData icon;
  final Color color;
  const _FastItem({required this.letter, required this.title, required this.description,
      required this.icon, required this.color, required this.checkLabel});
}
