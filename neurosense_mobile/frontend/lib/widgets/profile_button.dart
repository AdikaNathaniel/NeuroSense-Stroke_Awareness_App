import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProfileIconButton extends StatelessWidget {
  const ProfileIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.person_outline),
      tooltip: 'Profile',
      onPressed: () => showProfileSheet(context),
    );
  }
}

Future<void> showProfileSheet(BuildContext context) async {
  final name  = await ApiService.getUserName()  ?? 'NeuroSense User';
  final email = await ApiService.getUserEmail() ?? '—';
  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: const Icon(Icons.person, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(name, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(email, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetCtx);
                _showChangePasswordDialog(context, email);
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Change Password'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 2),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(sheetCtx);
                await ApiService.logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              },
              icon: const Icon(Icons.logout, color: AppColors.riskHigh),
              label: const Text('Log Out', style: TextStyle(color: AppColors.riskHigh)),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showChangePasswordDialog(BuildContext context, String email) {
  final formKey   = GlobalKey<FormState>();
  final oldCtrl   = TextEditingController();
  final newCtrl   = TextEditingController();
  final confCtrl  = TextEditingController();
  bool obscureOld = true, obscureNew = true, obscureConf = true;
  bool busy = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setLocal) {
        final btnStyle = ElevatedButton.styleFrom(
          minimumSize: const Size(96, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        );
        final cancelStyle = TextButton.styleFrom(
          minimumSize: const Size(96, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        );
        InputDecoration field(String label, IconData prefix, bool obscure, VoidCallback toggle) =>
            InputDecoration(
              labelText: label,
              isDense: true,
              prefixIcon: Icon(prefix, size: 20),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: toggle,
                splashRadius: 20,
              ),
            );
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: const Text('Change Password'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldCtrl,
                    obscureText: obscureOld,
                    decoration: field('Current password', Icons.lock_outline, obscureOld,
                        () => setLocal(() => obscureOld = !obscureOld)),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    decoration: field('New password', Icons.lock_reset_outlined, obscureNew,
                        () => setLocal(() => obscureNew = !obscureNew)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'Must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confCtrl,
                    obscureText: obscureConf,
                    decoration: field('Confirm new password', Icons.lock_outline, obscureConf,
                        () => setLocal(() => obscureConf = !obscureConf)),
                    validator: (v) => v != newCtrl.text ? 'Passwords do not match' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              style: cancelStyle,
              onPressed: busy ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: btnStyle,
              onPressed: busy ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setLocal(() => busy = true);
                final dialogNav = Navigator.of(dialogCtx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final res = await ApiService.updatePassword(
                    email: email,
                    oldPassword: oldCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (!context.mounted) return;
                  dialogNav.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text(res['message']?.toString() ?? 'Password updated')),
                  );
                } catch (_) {
                  setLocal(() => busy = false);
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Network error. Please try again.')),
                  );
                }
              },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update'),
            ),
          ],
        );
      },
    ),
  );
}
