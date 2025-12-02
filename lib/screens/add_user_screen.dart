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
      // 1. إنشاء المستخدم في Auth (محاولة من التطبيق)
      // ملاحظة: إذا كان Auth محظوراً، يجب استخدام VPN أو إضافة دالة create_user في السيرفر
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
        // 2. حفظ البيانات عبر السيرفر (بدلاً من Firestore مباشرة)
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
          showCustomSnackBar(
            context,
            'User created successfully!',
            isError: false,
          );
          Navigator.of(context).pop();
        } else if (mounted) {
          showCustomSnackBar(
            context,
            'User created in Auth but failed to save data.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showCustomSnackBar(context, e.message ?? 'Auth Error');
    } catch (e) {
      if (mounted) showCustomSnackBar(context, 'Error: $e');
    } finally {
      if (tempApp != null) await tempApp.delete();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addUser)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _displayNameController,
                    decoration: InputDecoration(labelText: l10n.fullName),
                    validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter an email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l10n.password),
                    obscureText: true,
                    validator: (v) => v!.length < 6
                        ? 'Password must be at least 6 chars'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(labelText: l10n.role),
                    items: ['trainee', 'trainer', 'admin']
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 24),
                  // استخدام Stream من السيرفر
                  StreamBuilder<List<dynamic>>(
                    stream: _apiService.streamUsers(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final users = snapshot.data!;
                      return DropdownButtonFormField<String?>(
                        hint: Text(l10n.selectNewParent),
                        value: _selectedParentId,
                        decoration: InputDecoration(
                          labelText: l10n.selectNewParent,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Top Level'),
                          ),
                          ...users.map(
                            (u) => DropdownMenuItem<String>(
                              value: u['id'] ?? u['uid'],
                              child: Text(u['displayName'] ?? 'Unknown'),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedParentId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _createUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(l10n.createUser),
                  ),
                ],
              ),
            ),
    );
  }
}
