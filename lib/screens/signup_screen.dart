import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
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

  // استخدام ApiService لإنشاء الحساب (المرور عبر السيرفر)
  Future<void> _signUp() async {
    if (_selectedRole == null) return;
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _displayNameController.text.isEmpty) {
      showCustomSnackBar(context, 'يرجى ملء جميع الحقول');
      return;
    }

    setState(() => _isLoading = true);

    final ApiService apiService = ApiService();
    final String roleString = _selectedRole == UserRole.trainer
        ? 'trainer'
        : 'trainee';

    // استدعاء دالة التسجيل في السيرفر
    final result = await apiService.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      displayName: _displayNameController.text.trim(),
      role: roleString,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showCustomSnackBar(context, 'تم إنشاء الحساب بنجاح!', isError: false);
      Navigator.of(context).pop(); // العودة وتسجيل الدخول تلقائياً
    } else {
      String errorMsg = result['error'] ?? 'فشل إنشاء الحساب';

      // معالجة رسائل الحظر أو الأخطاء الشائعة
      if (errorMsg == 'DEVICE_BANNED') {
        errorMsg =
            '⛔ تم حظر هذا الجهاز من إنشاء حسابات جديدة.\nالسبب: ${result['reason'] ?? "غير محدد"}';
      } else if (errorMsg.contains('email-already-in-use')) {
        errorMsg = 'البريد الإلكتروني مستخدم بالفعل';
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
            ],
          ),
        ),
      ),
    );
  }
}
