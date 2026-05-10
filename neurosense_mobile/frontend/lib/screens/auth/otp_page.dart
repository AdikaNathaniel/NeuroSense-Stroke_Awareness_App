import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with LanguageAware {
  String _otp = '';
  bool _loading = false;
  bool _resending = false;
  late String _email;
  bool _emailLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_emailLoaded) {
      _email = ModalRoute.of(context)!.settings.arguments as String;
      _emailLoaded = true;
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.verifyEmail(_otp, _email);
      if (!mounted) return;
      if (res['message'] != null && res['message'].toString().toLowerCase().contains('verified')) {
        _showSuccess();
      } else {
        _showError(res['message'] ?? 'Invalid OTP');
      }
    } catch (_) {
      _showError('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ApiService.resendOtp(_email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent to your email'), backgroundColor: AppColors.primary),
      );
    } catch (_) {
      _showError('Could not resend OTP.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.riskLow, size: 56),
            ),
            const SizedBox(height: 16),
            const Text('Email Verified!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Your account is ready. Log in to continue.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verification Failed'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Verify Email')), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.12), blurRadius: 20)],
                ),
                child: const Icon(Icons.mark_email_unread_outlined, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text('Check your email', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text('We sent a 6-digit code to\n$_email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 36),

              // ── 6-digit OTP fields (Craftelle style) ──
              PinCodeTextField(
                appContext: context,
                length: 6,
                onChanged: (v) => setState(() => _otp = v),
                onCompleted: (_) => _verify(),
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(10),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: AppColors.surface,
                  inactiveFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surface,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.divider,
                  selectedColor: AppColors.primary,
                ),
                enableActiveFill: true,
              ),
              const SizedBox(height: 28),

              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _otp.length == 6 ? _verify : null,
                      child: Text(tr('Verify')),
                    ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr("Didn't receive it?"), style: Theme.of(context).textTheme.bodyMedium),
                  _resending
                      ? const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : TextButton(onPressed: _resend, child: Text(tr('Resend Code'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
