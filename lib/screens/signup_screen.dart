import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/app_notifications.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:drone_academy/widgets/language_selector.dart';
import 'package:flutter/material.dart';

enum UserRole { trainee, trainer }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  UserRole? _selectedRole = UserRole.trainee;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedRole == null) return;
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _displayNameController.text.isEmpty) {
      showCustomSnackBar(
        context,
        l10n.enterDescription,
      ); // أو رسالة "أكمل البيانات"
      return;
    }

    setState(() => _isLoading = true);

    final ApiService apiService = ApiService();
    final String roleString = _selectedRole == UserRole.trainer
        ? 'trainer'
        : 'trainee';

    // استخدام ApiService (يمر عبر السيرفر للتحقق من الحظر)
    final result = await apiService.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      displayName: _displayNameController.text.trim(),
      role: roleString,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      AppNotifications.showSuccess(context, l10n.welcome);
      Navigator.of(context).pop(); // العودة وتسجيل الدخول تلقائياً
    } else {
      String errorMsg = result['error'] ?? l10n.signupFailed;

      if (errorMsg == 'DEVICE_BANNED') {
        errorMsg = "⛔ ${l10n.failed}: Device Banned (${result['reason']})";
      } else if (errorMsg.contains('email-already-in-use')) {
        errorMsg = l10n.signupFailed; // يمكن تخصيص رسالة "البريد مستخدم"
      }

      showCustomSnackBar(context, errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createNewAccount),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/logo.png', height: 100),
              const SizedBox(height: 32),

              // الاسم الكامل
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // البريد الإلكتروني
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // كلمة المرور
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // اختيار الدور
              Text(
                l10n.selectYourRole,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              RadioListTile<UserRole>(
                title: Text(l10n.iAmATrainee),
                value: UserRole.trainee,
                groupValue: _selectedRole,
                onChanged: (UserRole? value) =>
                    setState(() => _selectedRole = value),
              ),
              RadioListTile<UserRole>(
                title: Text(l10n.iAmATrainer),
                value: UserRole.trainer,
                groupValue: _selectedRole,
                onChanged: (UserRole? value) =>
                    setState(() => _selectedRole = value),
              ),
              const SizedBox(height: 24),

              // زر التسجيل
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
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
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(l10n.signUp, style: const TextStyle(fontSize: 18)),
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
