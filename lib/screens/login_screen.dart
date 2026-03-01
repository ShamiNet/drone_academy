import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/signup_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/app_notifications.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:drone_academy/widgets/language_selector.dart';
import 'package:drone_academy/widgets/loading_view.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final void Function(Locale)? setLocale;
  final void Function(ThemeMode)? setThemeMode;

  const LoginScreen({super.key, this.setLocale, this.setThemeMode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // دالة للتحقق من صحة البريد الإلكتروني
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // دالة للتحقق من قوة كلمة المرور
  bool _isValidPassword(String password) {
    // كلمة المرور يجب أن تكون 6 أحرف على الأقل
    return password.length >= 6;
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // التحقق من عدم ترك الحقول فارغة
    if (email.isEmpty || password.isEmpty) {
      AppNotifications.showError(
        context,
        '⚠️ ${l10n.loginFailed}: يرجى ملء جميع الحقول', // Fill all fields
      );
      return;
    }

    // التحقق من صيغة البريد الإلكتروني
    if (!_isValidEmail(email)) {
      AppNotifications.showError(
        context,
        '📧 invalid email format. Please check your email address.',
      );
      return;
    }

    // التحقق من طول كلمة المرور
    if (!_isValidPassword(password)) {
      AppNotifications.showError(
        context,
        '🔐 Password must be at least 6 characters long.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      AppNotifications.showSuccess(
        context,
        l10n.welcome, // "أهلاً بك!"
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(setLocale: (Locale locale) {}),
        ),
      );
    } else {
      // معالجة الأخطاء مع التعريب
      String errorCode = result['error']?.toString() ?? 'Unknown Error';
      String userMessage = l10n.loginFailed;

      if (errorCode.contains('USER_BANNED')) {
        userMessage = l10n.userBannedMessage;
      } else if (errorCode.contains('INVALID_LOGIN_CREDENTIALS')) {
        userMessage =
            '❌ ${l10n.loginFailed}\n\nThe email or password is incorrect.\n\n'
            'Options:\n'
            '1. Double-check your credentials\n'
            '2. Create a new account if you don\'t have one';

        // Show a dialog with helpful options
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('❌ Login Failed'),
              content: const Text(
                'The email or password is incorrect.\n\n'
                'Please check your credentials or create a new account.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Try Again'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
                    );
                  },
                  child: const Text('Create Account'),
                ),
              ],
            ),
          );
        }
        return;
      } else if (errorCode.contains('Connection error') ||
          errorCode.contains('SocketException') ||
          errorCode.contains('Failed host lookup')) {
        userMessage =
            '🌐 Network Error\n\n'
            'Cannot connect to the server.\n\n'
            'Please check your internet connection\n'
            'and try again.';
      } else if (errorCode.contains('DEVICE_BANNED')) {
        // يمكن إضافة نص خاص للجهاز المحظور في ملفات اللغة لاحقاً
        String reason = result['reason'] ?? "";
        userMessage = "⛔ ${l10n.failed}: Device Banned ($reason)";
      } else if (errorCode.contains('EMAIL_NOT_FOUND') ||
          errorCode.contains('INVALID_PASSWORD')) {
        userMessage =
            '❌ Login Failed\n\n'
            'Invalid email or password. Please try again.';
      }

      showCustomSnackBar(context, userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (_isLoading) {
      return LoadingView(message: l10n.loading);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'app_logo',
                child: Image.asset('assets/images/logo.png', height: 120),
              ),
              const SizedBox(height: 40),
              Text(
                l10n.login,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // حقل البريد الإلكتروني
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // حقل كلمة المرور
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // زر تسجيل الدخول
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.login,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // زر إنشاء حساب
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: Text(l10n.createNewAccount),
              ),

              const SizedBox(height: 30),

              // اختيار اللغة
              const LanguageSelector(showTitle: false, isCompact: true),
            ],
          ),
        ),
      ),
    );
  }
}
