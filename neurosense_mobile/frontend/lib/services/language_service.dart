import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// One supported display language.
class LanguageOption {
  final String code;        // e.g. 'es'
  final String englishName; // e.g. 'Spanish'
  final String nativeName;  // e.g. 'Español'
  const LanguageOption(this.code, this.englishName, this.nativeName);
}

/// Centralised language preference + translation cache.
///
/// On [setLanguage], translates the fixed [kTranslatableStrings] catalog via
/// the backend (OpenRouter) in a single batched call, then persists the
/// resulting English→target map in SharedPreferences keyed by language.
/// Subsequent app launches read from the cache so there's no network round
/// trip.
class LanguageService extends ChangeNotifier {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  static const _kLangKey      = 'current_language';
  static const _kCachePrefix  = 'translation_cache:';

  /// The list of languages exposed in the picker. Order is preserved in the UI.
  static const List<LanguageOption> supportedLanguages = [
    LanguageOption('en', 'English',     'English'),
    LanguageOption('pt', 'Portuguese',  'Português'),
    LanguageOption('zh', 'Chinese',     '中文'),
    LanguageOption('na', 'Nauruan',     'Dorerin Naoero'),
    LanguageOption('mh', 'Marshallese', 'Kajin M̧ajeļ'),
  ];

  String _currentLanguage = 'English';
  Map<String, String> _translations = const {};
  bool _isLoading = false;
  String? _lastError;

  String get currentLanguage => _currentLanguage;
  bool   get isLoading       => _isLoading;
  String? get lastError      => _lastError;

  LanguageOption get currentOption => supportedLanguages.firstWhere(
        (l) => l.englishName == _currentLanguage,
        orElse: () => supportedLanguages[0],
      );

  /// Look up a translation; falls back to the English original if not cached.
  String tr(String english) {
    if (_currentLanguage == 'English') return english;
    return _translations[english] ?? english;
  }

  /// Call once at app startup. Restores the user's preference + cached
  /// translations from disk so the very first frame is already localized.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_kLangKey) ?? 'English';
    if (_currentLanguage != 'English') {
      final cached = prefs.getString('$_kCachePrefix$_currentLanguage');
      if (cached != null) {
        try {
          _translations = Map<String, String>.from(jsonDecode(cached));
        } catch (_) {/* corrupt cache; fall back to English text */}
      }
    }
    notifyListeners();
  }

  /// Switch to a new language. If we have a cached translation for it we use
  /// that immediately; otherwise we batch-translate via the backend.
  Future<void> setLanguage(String englishName) async {
    if (englishName == _currentLanguage && !_isLoading) return;

    final prefs = await SharedPreferences.getInstance();

    // English: nothing to translate, just clear and persist.
    if (englishName == 'English') {
      _currentLanguage = englishName;
      _translations = const {};
      _isLoading = false;
      _lastError = null;
      await prefs.setString(_kLangKey, englishName);
      notifyListeners();
      return;
    }

    // Cached hit — instant switch.
    final cached = prefs.getString('$_kCachePrefix$englishName');
    if (cached != null) {
      try {
        _translations = Map<String, String>.from(jsonDecode(cached));
        _currentLanguage = englishName;
        _isLoading = false;
        _lastError = null;
        await prefs.setString(_kLangKey, englishName);
        notifyListeners();
        return;
      } catch (_) {/* fall through to re-fetch */}
    }

    // Network fetch.
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final translated = await ApiService.translate(kTranslatableStrings, englishName);
      final map = <String, String>{};
      for (var i = 0; i < kTranslatableStrings.length && i < translated.length; i++) {
        map[kTranslatableStrings[i]] = translated[i];
      }
      _translations = map;
      _currentLanguage = englishName;
      await prefs.setString(_kLangKey, englishName);
      await prefs.setString('$_kCachePrefix$englishName', jsonEncode(map));
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('LanguageService: translation failed → $e\n$st');
      _isLoading = false;
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

/// Convenience top-level wrapper so screens can write `tr('Email')`.
String tr(String english) => LanguageService.instance.tr(english);

/// Mixin for screens that call `tr(...)` in their `build`. Subscribes to
/// [LanguageService] in `initState` and calls `setState` when the language
/// changes, forcing the screen to re-evaluate translations even if its parent
/// (or the Navigator) is reusing a const widget instance for the route.
mixin LanguageAware<T extends StatefulWidget> on State<T> {
  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    LanguageService.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }
}

/// Every English UI string the app translates. Add new strings here when you
/// wrap them with `tr(...)`. Order doesn't matter for translation, but keep it
/// readable so it's easy to audit.
const List<String> kTranslatableStrings = [
  // Common buttons / actions
  'OK', 'Cancel', 'Close', 'Copy', 'Retry', 'Submit', 'Update',
  'Save', 'Continue', 'Back', 'Done',

  // Auth — labels & buttons
  'Email', 'Password', 'Phone', 'Name', 'Confirm Password',
  'Current password', 'New password', 'Confirm new password',
  'Sign Up', 'Log In', 'Sign In', 'Log Out',
  'Create Account',
  "Don't have an account?",
  'Already have an account?',
  'Forgot Password?',
  'Verify', 'Verify Email',
  'Resend Code',
  'Send Temporary Password',
  'Enter your registered email and we will send a temporary password.',
  'A 6-digit code has been sent to your email. Enter it below to verify.',
  'OTP Verification',
  'Forgot Password',

  // Validation / errors
  'Enter your email', 'Enter a valid email', 'Enter your password',
  'Enter your name', 'Enter your phone number', 'Enter a valid phone number',
  'Passwords do not match', 'Required', 'Must be at least 6 characters',
  'Network error. Please try again.',
  'Login Failed', 'Account Locked', 'Email Not Verified', 'Account Deactivated',
  'Password updated',

  // Main shell tabs
  'Assess', 'AI Chat', 'Analytics',

  // Profile sheet
  'Profile', 'Change Password', 'Language', 'NeuroSense User',

  // Risk assessment screen
  'Risk Assessment', 'Personal Information', 'Work & Lifestyle',
  'Health Conditions', 'Medical Measurements',
  'Gender', 'Age', 'Ever Married',
  'Work Type', 'Residence Type', 'Smoking Status',
  'Hypertension', 'Heart Disease',
  'Avg Glucose Level (mg/dL)', 'BMI (kg/m²)',
  'Get My Risk Score',
  'Fill in your details accurately for the best prediction.',
  'Yes', 'No',
  'Male', 'Female',
  'Private', 'Self-employed', 'Govt_job', 'children', 'Never_worked',
  'Urban', 'Rural',
  'never smoked', 'formerly smoked', 'smokes', 'Unknown',
  'Prediction failed',

  // Result screen
  'Your Risk Result', 'Stroke risk score',
  'What this means', 'Recommended next steps', 'Key risk factors', 'Risk scale',
  'Looking healthy', 'Some areas to watch',
  'Your risk is elevated', 'Immediate attention recommended',
  'LOW RISK', 'MEDIUM RISK', 'HIGH RISK', 'CRITICAL RISK',

  // Chat screen
  'NeuroSense AI', 'Clear chat',
  'Ask about stroke, risk factors…',
  'Ask me anything about stroke awareness, risk factors, symptoms, and prevention.',
  'Sorry, I could not connect to the server. Please check your connection.',

  // Analytics screen
  'Risk Score Trend', 'Risk Band Distribution',
  'Vitals vs Healthy Range', 'Risk Factor Breakdown (Latest)',
  'Assessments', 'Avg Risk', 'Trend',
  'No data yet',
  'Complete your first risk assessment to see your personal analytics here.',
  'Failed to load analytics.',
  'Healthy reference', 'Your value',
  'Modifiable', 'Non-Modifiable',
  'BMI', 'Glucose', 'Glucose (mg/dL)',
  'Your BMI', 'Healthy BMI', 'Your Glucose', 'Healthy Glucose',

  // FAST checker
  'F.A.S.T. Checker',
  'Face Drooping', 'Arm Weakness', 'Speech Difficulty', 'Time to Call',

  // Splash
  'Stroke Awareness & Prediction',
];
