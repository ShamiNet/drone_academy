import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/signup_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:drone_academy/widgets/loading_view.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  // [إضافة] استقبال دوال التحكم
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
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      showCustomSnackBar(context, 'Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);

    final success = await _apiService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              // [تصحيح] تمرير الدوال الحقيقية بدلاً من الطباعة فقط
              setLocale: widget.setLocale ?? (l) {},
              setThemeMode: widget.setThemeMode,
            ),
          ),
        );
      } else {
        showCustomSnackBar(
          context,
          'Login failed. Check credentials or connection.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // استخدام لون الخلفية من الثيم الحالي أو الأسود كاحتياط
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    // إذا كان يحمل، اعرض الشاشة الجميلة
    if (_isLoading) {
      return const LoadingView(
        message: "جاري تحضير الصفحة. اذكر الله بينما تجهز...",
      );
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
                  // color: Colors.white, // إزالة اللون الثابت ليدعم الثيم الفاتح والداكن
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
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
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.login,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
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
            ],
          ),
        ),
      ),
    );
  }
}
