import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/register.dart';
import 'screens/auth/otp_page.dart';
import 'screens/auth/forgot_password.dart';
import 'screens/app/main_shell.dart';
import 'screens/app/result_screen.dart';

void main() {
  runApp(const NeuroSenseApp());
}

class NeuroSenseApp extends StatelessWidget {
  const NeuroSenseApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroSense',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/':               (_) => const SplashScreen(),
        '/login':          (_) => const LoginScreen(),
        '/register':       (_) => const RegisterScreen(),
        '/otp':            (_) => const OtpScreen(),
        '/forgot-password':(_) => const ForgotPasswordScreen(),
        '/home':           (_) => const MainShell(),
        '/result':         (_) => const ResultScreen(),
      },
    );
  }
}
