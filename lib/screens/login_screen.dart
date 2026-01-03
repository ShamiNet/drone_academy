import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/signup_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/app_notifications.dart';
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

  // داخل كلاس _LoginScreenState

  Future<void> _login() async {
    // 1. التحقق من الإدخال
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      AppNotifications.showError(context, "يرجى إدخال البريد وكلمة المرور!");
      return;
    }

    setState(() => _isLoading = true);

    // 2. استدعاء السيرفر
    final result = await _apiService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 3. التحقق من النتيجة
    if (result['success'] == true) {
      // ✅ نجاح
      AppNotifications.showSuccess(
        context,
        "تم تسجيل الدخول بنجاح، مرحباً بك!",
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(setLocale: (Locale locale) {}),
        ),
      );
    } else {
      // ❌ فشل الدخول
      // تحويل الخطأ إلى نص لضمان عدم حدوث مشاكل Null
      String errorCode = result['error']?.toString() ?? 'Unknown Error';

      // طباعة الخطأ في الكونسول (لك أنت كمبرمج)
      print("🔍 DEBUG: Login Error Code: $errorCode");

      String userMessage = "";

      // تحديد الرسالة المناسبة
      if (errorCode.contains('USER_BANNED')) {
        userMessage = "⛔ تم حظر حسابك من قبل الإدارة.";
      } else if (errorCode.contains('DEVICE_BANNED')) {
        String reason = result['reason'] ?? "مخالفة القوانين";
        userMessage = "⛔ هذا الجهاز محظور من الدخول.\nالسبب: $reason";
      } else if (errorCode.contains('EMAIL_NOT_FOUND') ||
          errorCode.contains('INVALID_PASSWORD') ||
          errorCode.contains('INVALID_LOGIN_CREDENTIALS')) {
        // إضافة كود فايربيس المحتمل
        userMessage = "البريد الإلكتروني أو كلمة المرور غير صحيحة.";
      } else if (errorCode.contains('Connection error') ||
          errorCode.contains('SocketException')) {
        userMessage = "خطأ في الاتصال، تأكد من الإنترنت وتشغيل السيرفر.";
      } else {
        // ⚠️ هام جداً: في حال كان الخطأ غير معروف، نعرضه كما جاء من السيرفر
        // هذا سيساعدك في معرفة "السبب" الذي كان يختفي
        userMessage = "فشل الدخول: $errorCode";
      }

      // عرض الإشعار
      AppNotifications.showError(context, userMessage, title: "تنبيه");
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
