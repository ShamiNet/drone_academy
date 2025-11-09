import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/models/user_model.dart';
import 'package:drone_academy/services/user_service.dart';
import 'package:drone_academy/screens/trainee_dashboard.dart';
import 'package:drone_academy/screens/trainee_results_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  String _selectedRole = 'all'; // 'all', 'admin', 'trainer', 'trainee'

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userService = UserService();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Helper to get localized role name using existing keys
    String getRoleName(String role) {
      switch (role) {
        case 'admin':
          return l10n.admin;
        case 'trainer':
          return l10n.trainers; // using plural key as fallback
        case 'trainee':
          return l10n.trainees; // using plural key as fallback
        default:
          return role;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.users)),
      // نستخدم StreamBuilder لجلب كل المستخدمين
      body: StreamBuilder<List<UserModel>>(
        stream: userService.allUsersStream,
        builder: (context, snapshot) {
          // حالة التحميل
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // حالة الخطأ
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // لا يوجد بيانات (قائمة فارغة)
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noUsersFound));
          }

          // Filter users based on the selected role
          final filteredUsers = snapshot.data!.where((user) {
            if (_selectedRole == 'all') {
              return true;
            }
            return user.role == _selectedRole;
          }).toList();

          return Column(
            children: [
              // Filter Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: l10n.role,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(l10n.all)),
                    DropdownMenuItem(value: 'admin', child: Text(l10n.admin)),
                    DropdownMenuItem(
                      value: 'trainer',
                      child: Text(l10n.trainers),
                    ),
                    DropdownMenuItem(
                      value: 'trainee',
                      child: Text(l10n.trainees),
                    ),
                    const DropdownMenuItem(
                      value: 'guest',
                      child: Text('Guest'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
              ),
              // Users List
              Expanded(
                child: filteredUsers.isEmpty
                    ? Center(child: Text(l10n.noUsersFound))
                    : ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];

                          // (لا نعرض المدير في القائمة، لا يمكنه حظر نفسه)
                          if (user.uid == currentUserId) {
                            return const SizedBox.shrink(); // عنصر فارغ
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    (user.photoUrl != null &&
                                        user.photoUrl!.isNotEmpty)
                                    ? NetworkImage(user.photoUrl!)
                                    : null,
                                child:
                                    (user.photoUrl == null ||
                                        user.photoUrl!.isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                user.name ??
                                    user.email ??
                                    'User ${user.uid.substring(0, 8)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${getRoleName(user.role)} • ${user.email ?? user.uid}',
                              ),
                              trailing: Switch(
                                value: user.isBanned,
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                onChanged: (bool isBanned) {
                                  _showBanConfirmationDialog(
                                    context,
                                    user,
                                    isBanned,
                                    l10n,
                                    userService,
                                  );
                                },
                              ),
                              onTap: () {
                                if (user.role == 'trainee') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TraineeResultsScreen(
                                            traineeData: user.toJson(),
                                            traineeId: user.uid,
                                          ),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TraineeDashboard(),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // دالة لإظهار رسالة تأكيد الحظر
  void _showBanConfirmationDialog(
    BuildContext context,
    UserModel user,
    bool isBanned,
    AppLocalizations l10n,
    UserService userService,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isBanned ? 'Confirm Ban' : 'Confirm Unban'),
          content: Text(
            isBanned
                ? 'Are you sure you want to ban ${user.email ?? user.uid}?'
                : 'Are you sure you want to unban ${user.email ?? user.uid}?',
          ),
          actions: [
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // إغلاق الحوار
              },
            ),
            TextButton(
              child: Text(
                isBanned ? 'Ban' : 'Unban',
                style: TextStyle(
                  color: isBanned
                      ? Theme.of(context).colorScheme.error
                      : Colors.green,
                ),
              ),
              onPressed: () {
                // تنفيذ عملية الحظر
                userService.updateUserBanStatus(user.uid, isBanned).catchError((
                  e,
                ) {
                  // إظهار رسالة خطأ إذا فشل الحظر
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
                Navigator.of(dialogContext).pop(); // إغلاق الحوار
              },
            ),
          ],
        );
      },
    );
  }
}
