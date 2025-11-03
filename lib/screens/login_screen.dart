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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An unknown error occurred.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'كلمة المرور غير صحيحة.';
      }
      if (mounted) showCustomSnackBar(context, errorMessage);
    }
  }

  // --- دوال تسجيل الدخول السريع ---
  // دالة تسجيل الدخول كمدير
  Future<void> _quickLoginAdmin() async {
    FocusScope.of(context).unfocus();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'kloklop8@gmail.com',
        password: 'kloklop0',
      );
    } on FirebaseAuthException catch (e) {
      if (mounted)
        showCustomSnackBar(context, e.message ?? "Quick login failed");
    }
  }

  // دالة تسجيل الدخول كمدرب
  Future<void> _quickLoginTrainer() async {
    FocusScope.of(context).unfocus();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'g@g.com',
        password: 'kloklop0',
      );
    } on FirebaseAuthException catch (e) {
      if (mounted)
        showCustomSnackBar(context, e.message ?? "Quick login failed");
    }
  }

  // دالة تسجيل الدخول كمتدرب
  Future<void> _quickLoginTrainee() async {
    FocusScope.of(context).unfocus();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'w@g.com',
        password: 'kloklop0',
      );
    } on FirebaseAuthException catch (e) {
      if (mounted)
        showCustomSnackBar(context, e.message ?? "Quick login failed");
    }
  }
  // --- نهاية دوال تسجيل الدخول السريع ---

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
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocusNode),
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
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.login, style: const TextStyle(fontSize: 18)),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                ),
                child: Text(
                  l10n.dontHaveAccount,
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),

              // --- تعديل قسم أزرار الدخول السريع ---
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Wrap(
                    spacing: 8.0, // مسافة أفقية بين الأزرار
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _quickLoginAdmin,
                        child: const Text('Login Admin'),
                      ),
                      OutlinedButton(
                        onPressed: _quickLoginTrainer,
                        child: const Text('Login Trainer'),
                      ),
                      OutlinedButton(
                        onPressed: _quickLoginTrainee,
                        child: const Text('Login Trainee'),
                      ),
                    ],
                  ),
                ),
              // --- نهاية التعديل ---
            ],
          ),
        ),
      ),
    );
  }
}
