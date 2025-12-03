import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/services/api_service.dart'; // استخدام الخدمة الجديدة
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';

class UserBlockingScreen extends StatefulWidget {
  const UserBlockingScreen({super.key});

  @override
  State<UserBlockingScreen> createState() => _UserBlockingScreenState();
}

class _UserBlockingScreenState extends State<UserBlockingScreen> {
  final ApiService _apiService = ApiService();
  // 0: الكل، 1: محظورون، 2: نشطون
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('إدارة حظر المستخدمين'),
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          // --- العداد الديناميكي (تم تفعيله) ---
          StreamBuilder<List<dynamic>>(
            stream: _apiService.streamUsers(), // الاستماع للتحديثات
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              final blockedCount = users
                  .where((u) => u['isBlocked'] == true)
                  .length;

              return Container(
                margin: const EdgeInsets.only(left: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Text(
                      '$blockedCount',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.block, color: Colors.red, size: 16),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- التبويبات العلوية ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildFilterChip('الكل', Icons.group, 0),
                const SizedBox(width: 8),
                _buildFilterChip('محظورون', Icons.block, 1),
                const SizedBox(width: 8),
                _buildFilterChip('نشطون', Icons.check_circle, 2),
              ],
            ),
          ),

          // --- القائمة ---
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: _apiService
                  .streamUsers(), // استخدام السيرفر بدلاً من فايربيز
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allUsers = snapshot.data ?? [];

                // التصفية حسب التبويب المختار
                final filteredUsers = allUsers.where((user) {
                  final bool isBlocked = user['isBlocked'] == true;

                  if (_selectedIndex == 1) return isBlocked; // محظورون فقط
                  if (_selectedIndex == 2) return !isBlocked; // نشطون فقط
                  return true; // الكل
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text(
                      "لا يوجد مستخدمين",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final bool isBlocked = user['isBlocked'] == true;
                    final String photoUrl = user['photoUrl'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: isBlocked
                            ? Border.all(color: Colors.red.withOpacity(0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          // مفتاح التبديل (Switch)
                          Switch(
                            value: !isBlocked, // On = نشط، Off = محظور
                            activeColor: const Color(0xFFFF9800),
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.grey.shade800,
                            onChanged: (val) {
                              // عكس الحالة (إذا كان val=true يعني نريد التفعيل، إذن isBlocked يجب أن يصبح false)
                              _toggleBlockStatus(user, !val);
                            },
                          ),
                          const Spacer(),

                          // المعلومات
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                user['displayName'] ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                user['email'] ?? '',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // شارة الحالة
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isBlocked
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isBlocked
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                                child: Text(
                                  isBlocked ? 'محظور' : 'نشط',
                                  style: TextStyle(
                                    color: isBlocked
                                        ? Colors.red
                                        : Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 12),

                          // الصورة أو أيقونة الحظر
                          isBlocked
                              ? const CircleAvatar(
                                  backgroundColor: Colors.red,
                                  child: Icon(Icons.block, color: Colors.white),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.grey.shade800,
                                  backgroundImage: (photoUrl.isNotEmpty)
                                      ? CachedNetworkImageProvider(photoUrl)
                                      : null,
                                  child: (photoUrl.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                        ],
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

  Widget _buildFilterChip(String label, IconData icon, int index) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3F455A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey.shade800,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleBlockStatus(Map<String, dynamic> user, bool shouldBlock) async {
    final uid = user['id'] ?? user['uid'];

    final success = await _apiService.updateUser({
      'uid': uid,
      'isBlocked': shouldBlock,
    });

    if (mounted) {
      if (success) {
        showCustomSnackBar(
          context,
          shouldBlock ? 'تم حظر المستخدم' : 'تم تفعيل المستخدم',
          isError: shouldBlock,
        );
      } else {
        showCustomSnackBar(context, 'فشل تحديث الحالة');
      }
    }
  }
}
