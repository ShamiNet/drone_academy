import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/signup_screen.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  // 1. متغير جديد لحالة التحميل
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // [DEBUG] بداية المحاولة
    debugPrint('🟢 [LOGIN FLOW] Start: Login button pressed.');

    FocusScope.of(context).unfocus();

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      debugPrint('🔴 [LOGIN FLOW] Validation Error: Email or Password empty.');
      showCustomSnackBar(context, 'Please fill in all fields.');
      return;
    }

    // تفعيل حالة التحميل وتحديث الواجهة
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint(
        '🔵 [LOGIN FLOW] Attempting FirebaseAuth sign in for: ${_emailController.text.trim()}',
      );

      // محاولة الاتصال بفايربيز
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      debugPrint('🟢 [LOGIN FLOW] Success: User signed in successfully!');
      // هنا AuthGate سيقوم تلقائياً بنقل المستخدم، لا داعي لعمل Navigator يدوياً
    } on FirebaseAuthException catch (e) {
      // [DEBUG] طباعة رمز الخطأ القادم من فايربيز
      debugPrint('🔴 [LOGIN FLOW] Firebase Error Code: ${e.code}');
      debugPrint('🔴 [LOGIN FLOW] Firebase Error Message: ${e.message}');

      String errorMessage = 'An unknown error occurred.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'كلمة المرور غير صحيحة.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'خطأ في الاتصال. تأكد من الإنترنت.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'محاولات كثيرة جداً. حاول لاحقاً.';
      }

      if (mounted) showCustomSnackBar(context, errorMessage);
    } catch (e) {
      // [DEBUG] أي خطأ آخر غير متوقع
      debugPrint('🔴 [LOGIN FLOW] General Error: $e');
      if (mounted) showCustomSnackBar(context, 'Error: $e');
    } finally {
      // إيقاف حالة التحميل سواء نجح الأمر أو فشل
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('⚪ [LOGIN FLOW] End: Loading state reset.');
      }
    }
  }

  // --- دوال تسجيل الدخول السريع (تم تحديثها أيضاً) ---
  Future<void> _quickLogin(
    String email,
    String password,
    String roleName,
  ) async {
    debugPrint('🔵 [QUICK LOGIN] Attempting quick login as $roleName...');
    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('🟢 [QUICK LOGIN] Success as $roleName.');
    } catch (e) {
      debugPrint('🔴 [QUICK LOGIN] Failed: $e');
      if (mounted) showCustomSnackBar(context, "Quick login failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/logo.png', height: 150),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),

              // 2. استخدام مؤشر التحميل هنا
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.login,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),

              if (!_isLoading)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  ),
                  child: Text(
                    l10n.dontHaveAccount,
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),

              if (kDebugMode && !_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Wrap(
                    spacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => _quickLogin(
                          'kloklop8@gmail.com',
                          'kloklop0',
                          'Admin',
                        ),
                        child: const Text('Login Admin'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _quickLogin('g@g.com', 'kloklop0', 'Trainer'),
                        child: const Text('Login Trainer'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _quickLogin('w@g.com', 'kloklop0', 'Trainee'),
                        child: const Text('Login Trainee'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
