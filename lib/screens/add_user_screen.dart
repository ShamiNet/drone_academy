import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
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

  // --- بداية التعديل الكبير: دالة إنشاء المستخدم الجديدة ---
  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    FirebaseApp? tempApp;
    try {
      // 1. إنشاء اتصال مؤقت ومنفصل بـ Firebase باسم فريد
      tempApp = await Firebase.initializeApp(
        name: 'temporaryRegister',
        options: Firebase.app().options,
      );

      // 2. استخدام هذا الاتصال المؤقت لإنشاء المستخدم الجديد
      final UserCredential userCredential =
          await FirebaseAuth.instanceFor(
            app: tempApp,
          ).createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final newUserUid = userCredential.user?.uid;
      if (newUserUid != null) {
        // 3. الآن نستخدم اتصالنا الأساسي لحفظ بيانات المستخدم في Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(newUserUid)
            .set({
              'uid': newUserUid,
              'displayName': _displayNameController.text,
              'email': _emailController.text,
              'role': _selectedRole,
              'parentId': _selectedParentId ?? '',
              'photoUrl': '',
              'fcmToken': '', // سيتم تحديثه عند أول تسجيل دخول للمستخدم الجديد
            });

        if (mounted) {
          showCustomSnackBar(
            context,
            'User created successfully!',
            isError: false,
          );
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        // يمكننا استخدام نفس نظام رسائل الخطأ الذي أنشأناه سابقاً
        showCustomSnackBar(
          context,
          e.message ?? 'An error occurred during sign up.',
        );
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'An unexpected error occurred.');
      }
    } finally {
      // 4. الأهم: حذف الاتصال المؤقت دائماً، سواء نجحت العملية أو فشلت
      if (tempApp != null) {
        await tempApp.delete();
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // --- نهاية التعديل الكبير ---

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
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter an email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l10n.password),
                    obscureText: true,
                    validator: (value) => value!.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.role,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    items: ['trainee', 'trainer', 'admin'].map((String role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null)
                        setState(() => _selectedRole = newValue);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.selectNewParent,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final users = snapshot.data!.docs;
                      return DropdownButtonFormField<String?>(
                        hint: const Text('Top Level'),
                        value: _selectedParentId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Top Level'),
                          ),
                          ...users.map((doc) {
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(doc['displayName']),
                            );
                          }),
                        ],
                        onChanged: (String? newValue) {
                          setState(() => _selectedParentId = newValue);
                        },
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
