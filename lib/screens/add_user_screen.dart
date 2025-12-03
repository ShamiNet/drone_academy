import 'package:animate_do/animate_do.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  String _selectedRole = 'trainee';
  String? _selectedParentId;
  bool _isLoading = false;

  // ألوان التصميم
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800);
  final Color _accentColor = const Color(0xFF3F51B5);

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    FirebaseApp? tempApp;
    try {
      // إنشاء تطبيق فرعي مؤقت لتسجيل المستخدم الجديد دون طرد المدير الحالي
      tempApp = await Firebase.initializeApp(
        name: 'temporaryRegister',
        options: Firebase.app().options,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instanceFor(
            app: tempApp,
          ).createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final newUserUid = userCredential.user?.uid;
      if (newUserUid != null) {
        // حفظ البيانات في السيرفر
        final success = await _apiService.updateUser({
          'uid': newUserUid,
          'displayName': _displayNameController.text,
          'email': _emailController.text,
          'role': _selectedRole,
          'parentId': _selectedParentId ?? '',
          'photoUrl': '',
          'fcmToken': '',
          'createdAt': DateTime.now().toIso8601String(),
        });

        if (success && mounted) {
          showCustomSnackBar(context, 'تم إنشاء الحساب بنجاح!', isError: false);
          Navigator.of(context).pop();
        } else if (mounted) {
          showCustomSnackBar(context, 'تم إنشاء الحساب ولكن فشل حفظ البيانات.');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showCustomSnackBar(context, e.message ?? 'خطأ في المصادقة');
    } catch (e) {
      if (mounted) showCustomSnackBar(context, 'حدث خطأ: $e');
    } finally {
      if (tempApp != null) await tempApp.delete();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.addUser,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الهيدر التعريفي
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accentColor, _bgColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_add,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "إضافة عضو جديد",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "أدخل بيانات المستخدم لإنشاء حساب جديد في النظام",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 2. حقول الإدخال
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildInputCard(
                        label: l10n.fullName,
                        icon: Icons.person,
                        child: TextFormField(
                          controller: _displayNameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "الاسم الكامل",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: _buildInputCard(
                        label: l10n.email,
                        icon: Icons.email,
                        child: TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "example@email.com",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: _buildInputCard(
                        label: l10n.password,
                        icon: Icons.lock,
                        child: TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "******",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          validator: (v) =>
                              v!.length < 6 ? 'كلمة المرور قصيرة جداً' : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // القوائم المنسدلة
                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInputCard(
                              label: l10n.role,
                              icon: Icons.badge,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRole,
                                  dropdownColor: _cardColor,
                                  style: const TextStyle(color: Colors.white),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                  ),
                                  items: ['trainee', 'trainer', 'admin'].map((
                                    role,
                                  ) {
                                    // ترجمة بسيطة للأدوار
                                    String label = role;
                                    if (role == 'trainee')
                                      label = l10n.trainees;
                                    if (role == 'trainer') label = l10n.trainer;
                                    if (role == 'admin') label = l10n.admin;
                                    return DropdownMenuItem(
                                      value: role,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedRole = val!),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // اختيار المدير (التبعية)
                    FadeInUp(
                      delay: const Duration(milliseconds: 600),
                      child: _buildInputCard(
                        label: l10n.selectNewParent,
                        icon: Icons.supervisor_account,
                        child: StreamBuilder<List<dynamic>>(
                          stream: _apiService.streamUsers(),
                          builder: (context, snapshot) {
                            final users = snapshot.data ?? [];
                            // فلترة فقط من يمكنهم أن يكونوا مسؤولين (اختياري)
                            final managers = users;

                            return DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                hint: Text(
                                  l10n.selectNewParent,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                value: _selectedParentId,
                                dropdownColor: _cardColor,
                                style: const TextStyle(color: Colors.white),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey,
                                ),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('بدون مسؤول (مستوى أعلى)'),
                                  ),
                                  ...managers.map(
                                    (u) => DropdownMenuItem<String>(
                                      value: u['id'] ?? u['uid'],
                                      child: Text(
                                        u['displayName'] ?? 'Unknown',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedParentId = val),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 3. زر الإنشاء
                    FadeInUp(
                      delay: const Duration(milliseconds: 700),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _createUser,
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.black,
                          ),
                          label: Text(
                            l10n.createUser,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 10,
                            shadowColor: _primaryColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ودجت مساعد لبناء الحقول
  Widget _buildInputCard({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: _primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26.0, bottom: 4),
            child: child,
          ),
        ],
      ),
    );
  }
}
