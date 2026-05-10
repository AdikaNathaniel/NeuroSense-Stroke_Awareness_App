import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/ns_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with LanguageAware {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.signup(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      if (res['message'] != null && res['message'].toString().contains('OTP')) {
        Navigator.pushNamed(context, '/otp', arguments: _emailCtrl.text.trim());
      } else {
        _showError(res['message'] ?? 'Registration failed');
      }
    } catch (_) {
      _showError(tr('Network error. Please try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registration Failed'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('OK')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Language picker chip at the top right
                    const Align(
                      alignment: Alignment.centerRight,
                      child: LanguageChipButton(),
                    ),
                    const SizedBox(height: 8),
                    const NsLogo(size: 150),
                    const SizedBox(height: 24),
                    Text(tr('Create Account'), style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(labelText: tr('Name'), prefixIcon: const Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.trim().isEmpty ? tr('Enter your name') : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: tr('Email'), prefixIcon: const Icon(Icons.email_outlined)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return tr('Enter your email');
                        if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) return tr('Enter a valid email');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: tr('Phone'), prefixIcon: const Icon(Icons.phone_outlined)),
                      validator: (v) => v == null || v.trim().isEmpty ? tr('Enter your phone number') : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: tr('Password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return tr('Required');
                        if (v.length < 6) return tr('Must be at least 6 characters');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: tr('Confirm Password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != _passCtrl.text ? tr('Passwords do not match') : null,
                    ),
                    const SizedBox(height: 28),

                    _loading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(onPressed: _submit, child: Text(tr('Create Account'))),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(tr('Already have an account?'), style: Theme.of(context).textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(tr('Log In')),
                        ),
                      ],
                    ),
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
