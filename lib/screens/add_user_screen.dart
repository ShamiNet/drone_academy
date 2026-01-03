// ... (imports)
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
  final _recommendationController = TextEditingController(); // التزكية

  final ApiService _apiService = ApiService();

  String _selectedRole = 'trainee';
  String? _selectedParentId;
  String? _selectedUnitType; // الوحدة
  String? _selectedMaritalStatus; // الحالة الاجتماعية
  bool _isLoading = false;

  // ... (Colors and dispose same as original)
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800);
  final Color _accentColor = const Color(0xFF3F51B5);

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _recommendationController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    FirebaseApp? tempApp;
    try {
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
        final success = await _apiService.updateUser({
          'uid': newUserUid,
          'displayName': _displayNameController.text,
          'email': _emailController.text,
          'role': _selectedRole,
          'parentId': _selectedParentId ?? '',
          // الحقول الجديدة
          'unitType': _selectedUnitType ?? '',
          'maritalStatus': _selectedMaritalStatus ?? '',
          'recommendation': _recommendationController.text,
          'photoUrl': '',
          'fcmToken': '',
          'createdAt': DateTime.now().toIso8601String(),
        });

        // ... (Handling success/error same as original)
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
        title: Text(
          l10n.addUser,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _bgColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                    // ... (Header same as original)
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildInputCard(
                      label: l10n.fullName,
                      icon: Icons.person,
                      child: TextFormField(
                        controller: _displayNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "الاسم الكامل",
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      label: l10n.email,
                      icon: Icons.email,
                      child: TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "email@example.com",
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      label: l10n.password,
                      icon: Icons.lock,
                      child: TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "******",
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        validator: (v) => v!.length < 6 ? 'قصيرة جداً' : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- الحقول الجديدة ---
                    Row(
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
                                  String label = role;
                                  if (role == 'trainee') label = l10n.trainees;
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInputCard(
                            label: "نوع الوحدة",
                            icon: Icons.flag,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUnitType,
                                hint: Text(
                                  "اختر",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                dropdownColor: _cardColor,
                                style: const TextStyle(color: Colors.white),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'liwa',
                                    child: Text('ألوية'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'markazia',
                                    child: Text('مركزية'),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedUnitType = val),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInputCard(
                            label: "الحالة الاجتماعية",
                            icon: Icons.family_restroom,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedMaritalStatus,
                                hint: Text(
                                  "اختر",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                dropdownColor: _cardColor,
                                style: const TextStyle(color: Colors.white),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'single',
                                    child: Text('أعزب'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'married',
                                    child: Text('متزوج'),
                                  ),
                                ],
                                onChanged: (val) => setState(
                                  () => _selectedMaritalStatus = val,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildInputCard(
                      label: "التزكية",
                      icon: Icons.recommend,
                      child: TextFormField(
                        controller: _recommendationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "اسم المُزكي أو ملاحظات",
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- اختيار المسؤول ---
                    _buildInputCard(
                      label: l10n.selectNewParent,
                      icon: Icons.supervisor_account,
                      child: StreamBuilder<List<dynamic>>(
                        stream: _apiService.streamUsers(),
                        builder: (context, snapshot) {
                          final users = snapshot.data ?? [];
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
                                  child: Text('بدون مسؤول'),
                                ),
                                ...users.map(
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

                    const SizedBox(height: 40),
                    SizedBox(
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

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
