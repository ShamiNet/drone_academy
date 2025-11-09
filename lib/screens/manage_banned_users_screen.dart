import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/models/user_model.dart';
import 'package:drone_academy/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageBannedUsersScreen extends StatefulWidget {
  const ManageBannedUsersScreen({super.key});

  @override
  State<ManageBannedUsersScreen> createState() =>
      _ManageBannedUsersScreenState();
}

class _ManageBannedUsersScreenState extends State<ManageBannedUsersScreen> {
  String _selectedFilter = 'all'; // 'all', 'banned', 'active'

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userService = UserService();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.users),
        actions: [
          // عداد المستخدمين المحظورين
          StreamBuilder<List<UserModel>>(
            stream: userService.allUsersStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final bannedCount = snapshot.data!
                    .where((u) => u.isBanned)
                    .length;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Chip(
                      avatar: const Icon(Icons.block, size: 18),
                      label: Text('$bannedCount'),
                      backgroundColor: bannedCount > 0
                          ? Colors.red.shade100
                          : Colors.grey.shade200,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // فلتر لاختيار نوع العرض
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'all',
                  label: Text(l10n.users),
                  icon: const Icon(Icons.people),
                ),
                ButtonSegment(
                  value: 'banned',
                  label: const Text('محظورون'),
                  icon: const Icon(Icons.block),
                ),
                ButtonSegment(
                  value: 'active',
                  label: const Text('نشطون'),
                  icon: const Icon(Icons.check_circle),
                ),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedFilter = newSelection.first;
                });
              },
            ),
          ),

          // قائمة المستخدمين
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: userService.allUsersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('خطأ في تحميل البيانات'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمين'));
                }

                // فلترة المستخدمين حسب الاختيار
                List<UserModel> users = snapshot.data!;
                if (_selectedFilter == 'banned') {
                  users = users.where((u) => u.isBanned).toList();
                } else if (_selectedFilter == 'active') {
                  users = users.where((u) => !u.isBanned).toList();
                }

                // إخفاء المستخدم الحالي من القائمة
                users = users.where((u) => u.uid != currentUserId).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFilter == 'banned'
                              ? Icons.check_circle_outline
                              : Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'banned'
                              ? 'لا يوجد مستخدمين محظورين'
                              : 'لا يوجد مستخدمين',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      elevation: user.isBanned ? 4 : 1,
                      color: user.isBanned ? Colors.red.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: user.isBanned
                              ? Colors.red
                              : Colors.blue,
                          child:
                              user.photoUrl != null && user.photoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    user.photoUrl!,
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                    errorBuilder: (_, __, ___) => Icon(
                                      user.isBanned
                                          ? Icons.block
                                          : Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  user.isBanned ? Icons.block : Icons.person,
                                  color: Colors.white,
                                ),
                        ),
                        title: Text(
                          user.name ??
                              user.email ??
                              'مستخدم ${user.uid.substring(0, 8)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: user.isBanned
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    _getRoleText(user.role, l10n),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 8),
                                if (user.isBanned)
                                  Chip(
                                    label: const Text(
                                      'محظور',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Switch(
                          value: user.isBanned,
                          activeColor: Colors.red,
                          onChanged: (bool value) {
                            _showBanConfirmationDialog(
                              context,
                              user,
                              value,
                              userService,
                              l10n,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleText(String role, AppLocalizations l10n) {
    switch (role) {
      case 'admin':
        return l10n.admin;
      case 'trainer':
        return l10n.trainers;
      case 'trainee':
        return l10n.trainees;
      default:
        return role;
    }
  }

  void _showBanConfirmationDialog(
    BuildContext context,
    UserModel user,
    bool shouldBan,
    UserService userService,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            shouldBan ? 'تأكيد الحظر' : 'إلغاء الحظر',
            style: TextStyle(color: shouldBan ? Colors.red : Colors.green),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shouldBan
                    ? 'هل أنت متأكد من حظر هذا المستخدم؟'
                    : 'هل أنت متأكد من إلغاء حظر هذا المستخدم؟',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.name ??
                          user.email ??
                          'مستخدم ${user.uid.substring(0, 8)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.email, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(user.email ?? '')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.badge, size: 20),
                  const SizedBox(width: 8),
                  Text(_getRoleText(user.role, l10n)),
                ],
              ),
              if (shouldBan) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم منع هذا المستخدم من تسجيل الدخول فوراً',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await userService.updateUserBanStatus(user.uid, shouldBan);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          shouldBan
                              ? 'تم حظر المستخدم بنجاح'
                              : 'تم إلغاء حظر المستخدم بنجاح',
                        ),
                        backgroundColor: shouldBan ? Colors.red : Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: shouldBan ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(shouldBan ? 'حظر' : 'إلغاء الحظر'),
            ),
          ],
        );
      },
    );
  }
}
