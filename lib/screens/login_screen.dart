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

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      AppNotifications.showError(
        context,
        l10n.loginFailed,
      ); // رسالة عامة أو "أدخل البيانات"
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

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
      } else if (errorCode.contains('DEVICE_BANNED')) {
        // يمكن إضافة نص خاص للجهاز المحظور في ملفات اللغة لاحقاً
        String reason = result['reason'] ?? "";
        userMessage = "⛔ ${l10n.failed}: Device Banned ($reason)";
      } else if (errorCode.contains('EMAIL_NOT_FOUND') ||
          errorCode.contains('INVALID_PASSWORD') ||
          errorCode.contains('INVALID_LOGIN_CREDENTIALS')) {
        userMessage = l10n.loginFailed; // أو رسالة "بيانات خاطئة"
      } else if (errorCode.contains('Connection error') ||
          errorCode.contains('SocketException')) {
        userMessage = l10n.connectionError;
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
