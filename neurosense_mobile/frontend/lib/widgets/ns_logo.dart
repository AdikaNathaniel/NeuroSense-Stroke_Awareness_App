import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Circular NeuroSense logo — same placement pattern as Craftelle.
/// Used at the top of all auth screens and on the splash screen.
class NsLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const NsLogo({super.key, this.size = 150, this.showShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 3),
        boxShadow: showShadow
            ? [BoxShadow(color: AppColors.primary.withOpacity(0.18), blurRadius: 20, spreadRadius: 4)]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/neurosense_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surface,
            child: Icon(Icons.psychology_rounded, size: size * 0.55, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
