import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int)? onSwitchTab;
  const HomeScreen({super.key, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/neurosense_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('NeuroSense'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ApiService.deleteToken();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Know Your Risk',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('Early detection saves lives. Check your stroke risk now.',
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/assess'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(140, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: const Text('Start Assessment', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.favorite_outline_rounded, size: 64, color: Colors.white24),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.1,
                children: [
                  _QuickCard(
                    icon: Icons.monitor_heart_rounded,
                    label: 'Risk Assessment',
                    color: AppColors.primary,
                    onTap: () => onSwitchTab?.call(1) ?? Navigator.pushNamed(context, '/assess'),
                  ),
                  _QuickCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'FAST Checker',
                    color: AppColors.riskHigh,
                    onTap: () => onSwitchTab?.call(3) ?? Navigator.pushNamed(context, '/fast'),
                  ),
                  _QuickCard(
                    icon: Icons.chat_bubble_rounded,
                    label: 'AI Chat',
                    color: AppColors.primaryLight,
                    onTap: () => onSwitchTab?.call(2),
                  ),
                  _QuickCard(
                    icon: Icons.history_rounded,
                    label: 'My History',
                    color: AppColors.accent,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History coming soon'), backgroundColor: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── FAST reminder card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.riskMedium.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.riskMedium.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_rounded, color: AppColors.riskMedium, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Act F.A.S.T.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Know the signs of a stroke. Time lost is brain lost.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => onSwitchTab?.call(3) ?? Navigator.pushNamed(context, '/fast'),
                            child: const Text('Learn more →',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
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
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 26),
            ),
            const Spacer(),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
