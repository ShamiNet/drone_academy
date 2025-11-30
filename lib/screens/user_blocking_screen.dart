import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';

class UserBlockingScreen extends StatefulWidget {
  const UserBlockingScreen({super.key});

  @override
  State<UserBlockingScreen> createState() => _UserBlockingScreenState();
}

class _UserBlockingScreenState extends State<UserBlockingScreen> {
  // 0: الكل (أو المستخدمون)، 1: محظورون، 2: نشطون
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('المستخدمون'),
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          // عداد المحظورين (ديكور من الصورة)
          Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: Row(
              children: const [
                Text('1', style: TextStyle(color: Colors.red)), // مثال رقمي
                SizedBox(width: 4),
                Icon(Icons.block, color: Colors.red, size: 16),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- التبويبات العلوية (Chips) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildFilterChip('المستخدمون', Icons.group, 0),
                const SizedBox(width: 8),
                _buildFilterChip('محظورون', Icons.block, 1),
                const SizedBox(width: 8),
                _buildFilterChip('نشطون', Icons.check_circle, 2),
              ],
            ),
          ),

          // --- القائمة ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('displayName')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final allDocs = snapshot.data!.docs;

                // التصفية
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final bool isBlocked = data['isBlocked'] == true;

                  if (_selectedIndex == 1) return isBlocked; // محظورون فقط
                  if (_selectedIndex == 2) return !isBlocked; // نشطون فقط
                  return true; // الكل
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final user = filteredDocs[index];
                    final data = user.data() as Map<String, dynamic>;
                    final bool isBlocked = data['isBlocked'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2230),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          // مفتاح التبديل (Switch)
                          Switch(
                            value: !isBlocked, // On يعني نشط، Off يعني محظور
                            activeColor: const Color(
                              0xFFFF9800,
                            ), // برتقالي عند التفعيل
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.grey.shade800,
                            onChanged: (val) {
                              // عكس الحالة
                              _toggleBlockStatus(user, !val);
                            },
                          ),
                          const Spacer(),

                          // المعلومات
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                data['displayName'] ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                data['email'] ?? '',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // شارة الدور أو الحالة
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isBlocked
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isBlocked
                                        ? Colors.red
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                child: Text(
                                  isBlocked
                                      ? 'محظور'
                                      : (data['role'] == 'trainee'
                                            ? 'المتدربين'
                                            : 'المدربين'),
                                  style: TextStyle(
                                    color: isBlocked ? Colors.red : Colors.grey,
                                    fontSize: 10,
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
                                  backgroundColor: Colors.blue,
                                  backgroundImage:
                                      (data['photoUrl'] != null &&
                                          data['photoUrl'] != '')
                                      ? CachedNetworkImageProvider(
                                          data['photoUrl'],
                                        )
                                      : null,
                                  child:
                                      (data['photoUrl'] == null ||
                                          data['photoUrl'] == '')
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
            color: isSelected
                ? const Color(0xFF3F455A)
                : Colors.transparent, // لون رمادي مزرق عند التحديد
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
              if (isSelected) Icon(Icons.check, size: 16, color: Colors.white),
              if (!isSelected) Icon(icon, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleBlockStatus(DocumentSnapshot user, bool shouldBlock) {
    user.reference.update({'isBlocked': shouldBlock}).then((_) {
      showCustomSnackBar(
        context,
        shouldBlock ? 'تم حظر المستخدم' : 'تم تفعيل المستخدم',
        isError: shouldBlock, // أحمر للحظر، أخضر للتفعيل
      );
    });
  }
}
