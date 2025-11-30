import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
import 'package:drone_academy/screens/user_details_screen.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'All'; // All, admin, trainer, trainee
  int _selectedTab = 0; // 0: All, 1: Blocked, 2: Active

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // الألوان
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const orangeColor = Color(0xFFFF9800);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // --- 1. التبويبات العلوية (Custom Segmented Control) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Row(
                children: [
                  _buildTabItem(l10n.all, 0), // "المستخدمون"
                  _buildVerticalDivider(),
                  _buildTabItem(l10n.blockUser, 1, isDanger: true), // "محظورون"
                  _buildVerticalDivider(),
                  _buildTabItem(l10n.active, 2, isSuccess: true), // "نشطون"
                ],
              ),
            ),
          ),

          // --- 2. البحث والفلترة ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // شريط البحث
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مستخدم...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),

                // قائمة الأدوار المنسدلة (Accordion Style)
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3F51B5),
                      width: 1,
                    ), // حدود زرقاء خفيفة
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: Key(
                        _selectedRoleFilter,
                      ), // لإجبار التحديث عند تغيير العنوان
                      title: Text(
                        _getRoleLabel(_selectedRoleFilter, l10n),
                        style: const TextStyle(color: Colors.white),
                      ),
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white,
                      children: [
                        _buildRoleOption('All', l10n.allRoles),
                        _buildRoleOption('admin', l10n.admin),
                        _buildRoleOption('trainer', l10n.trainer),
                        _buildRoleOption(
                          'trainee',
                          l10n.iAmATrainee,
                        ), // أو Trainees
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- 3. قائمة المستخدمين ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return EmptyStateWidget(
                    message: l10n.noUsersFound,
                    imagePath: 'assets/illustrations/no_data.svg',
                  );
                }

                // منطق الفلترة
                var users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['displayName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final role = data['role'] ?? 'trainee';
                  final isBlocked = data['isBlocked'] ?? false;

                  // فلتر البحث النصي
                  if (_searchQuery.isNotEmpty &&
                      !name.contains(_searchQuery.toLowerCase()) &&
                      !email.contains(_searchQuery.toLowerCase())) {
                    return false;
                  }

                  // فلتر الدور
                  if (_selectedRoleFilter != 'All' &&
                      role != _selectedRoleFilter) {
                    return false;
                  }

                  // فلتر التبويبات (الكل، محظور، نشط)
                  if (_selectedTab == 1 && !isBlocked)
                    return false; // تبويب المحظورين
                  if (_selectedTab == 2 && isBlocked)
                    return false; // تبويب النشطين

                  return true;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noResultsFound,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final data = userDoc.data() as Map<String, dynamic>;
                    final isBlocked = data['isBlocked'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        // الصورة (اليسار في RTL)
                        leading: _buildBlockSwitch(
                          userDoc.reference,
                          isBlocked,
                        ),

                        // المعلومات (الوسط/اليمين)
                        title: Text(
                          data['displayName'] ?? 'No Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['email'] ?? '',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                                    : (data['role'] ??
                                          'trainee'), // ترجمة الدور
                                style: TextStyle(
                                  color: isBlocked
                                      ? Colors.red
                                      : Colors.grey.shade400,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // زر التعديل أو الصورة (الجهة الأخرى)
                        trailing: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserDetailsScreen(userDoc: userDoc),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue,
                            backgroundImage:
                                (data['photoUrl'] != null &&
                                    data['photoUrl'] != '')
                                ? CachedNetworkImageProvider(data['photoUrl'])
                                : null,
                            child:
                                (data['photoUrl'] == null ||
                                    data['photoUrl'] == '')
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
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
      // الزر العائم للإضافة
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddUserScreen()),
        ),
        backgroundColor: orangeColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // أقصى اليسار
    );
  }

  // --- دوال مساعدة للواجهة ---

  Widget _buildTabItem(
    String label,
    int index, {
    bool isDanger = false,
    bool isSuccess = false,
  }) {
    final bool isSelected = _selectedTab == index;
    Color textColor = Colors.grey;
    if (isSelected) {
      textColor = Colors.white; // النص أبيض عند التحديد
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDanger
                      ? Colors.red.withOpacity(0.2)
                      : (isSuccess
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.shade700))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (isSelected && (isDanger || isSuccess)) ...[
                const SizedBox(width: 4),
                Icon(
                  isDanger ? Icons.block : Icons.check_circle,
                  size: 14,
                  color: isDanger ? Colors.red : Colors.green,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 20, color: Colors.grey.shade800);
  }

  Widget _buildRoleOption(String roleValue, String label) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        setState(() {
          _selectedRoleFilter = roleValue;
        });
      },
      trailing: _selectedRoleFilter == roleValue
          ? const Icon(Icons.check, color: Colors.orange)
          : null,
    );
  }

  String _getRoleLabel(String role, AppLocalizations l10n) {
    switch (role) {
      case 'admin':
        return l10n.admin;
      case 'trainer':
        return l10n.trainer;
      case 'trainee':
        return l10n.trainees; // أو ترجمة "متدربين"
      default:
        return 'جميع الأدوار'; // أو l10n.allRoles
    }
  }

  Widget _buildBlockSwitch(DocumentReference ref, bool isBlocked) {
    return Transform.scale(
      scale: 0.8,
      child: Switch(
        value: !isBlocked, // السويتش مفعل يعني الحساب "نشط" (غير محظور)
        onChanged: (val) {
          // val = true (نشط) -> isBlocked = false
          // val = false (غير نشط) -> isBlocked = true
          ref.update({'isBlocked': !val});
        },
        activeColor: Colors.white,
        activeTrackColor: Colors.grey.shade600,
        inactiveThumbColor: Colors.red,
        inactiveTrackColor: Colors.red.withOpacity(0.3),
      ),
    );
  }
}
