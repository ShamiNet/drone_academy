import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
// import 'package:drone_academy/screens/user_details_screen.dart'; // قد تحتاج لتعديل هذه الشاشة أيضاً لاحقاً
import 'package:drone_academy/services/api_service.dart'; // استيراد الخدمة الجديدة
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  // تعريف الخدمة
  final ApiService _apiService = ApiService();

  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const orangeColor = Color(0xFFFF9800);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // --- 1. التبويبات العلوية ---
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
                  _buildTabItem(l10n.all, 0),
                  _buildVerticalDivider(),
                  _buildTabItem(l10n.blockUser, 1, isDanger: true),
                  _buildVerticalDivider(),
                  _buildTabItem(l10n.active, 2, isSuccess: true),
                ],
              ),
            ),
          ),

          // --- 2. البحث والفلترة ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
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

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3F51B5),
                      width: 1,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: Key(_selectedRoleFilter),
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
                        _buildRoleOption('trainee', l10n.iAmATrainee),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- 3. قائمة المستخدمين (تستخدم ApiService) ---
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              // تغيير النوع إلى List<dynamic>
              stream: _apiService.streamUsers(), // استخدام دالة الـ Proxy
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // التعامل مع البيانات القادمة من JSON
                final usersList = snapshot.data ?? [];

                if (usersList.isEmpty) {
                  return EmptyStateWidget(
                    message: l10n.noUsersFound,
                    imagePath: 'assets/illustrations/no_data.svg',
                  );
                }

                // منطق الفلترة (يتم محلياً)
                var filteredUsers = usersList.where((user) {
                  // user هو عبارة عن Map<String, dynamic>
                  final name = (user['displayName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (user['email'] ?? '').toString().toLowerCase();
                  final role = user['role'] ?? 'trainee';
                  final isBlocked = user['isBlocked'] ?? false;

                  if (_searchQuery.isNotEmpty &&
                      !name.contains(_searchQuery.toLowerCase()) &&
                      !email.contains(_searchQuery.toLowerCase())) {
                    return false;
                  }

                  if (_selectedRoleFilter != 'All' &&
                      role != _selectedRoleFilter) {
                    return false;
                  }

                  if (_selectedTab == 1 && !isBlocked) return false;
                  if (_selectedTab == 2 && isBlocked) return false;

                  return true;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noResultsFound,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index]; // Map<String, dynamic>
                    final isBlocked = user['isBlocked'] ?? false;
                    final userId =
                        user['id'] ?? user['uid']; // التأكد من وجود المعرف

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
                        // زر التبديل للحظر (يستخدم ApiService)
                        leading: _buildBlockSwitch(userId, isBlocked),

                        title: Text(
                          user['displayName'] ?? 'No Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['email'] ?? '',
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
                                    : (user['role'] ?? 'trainee'),
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

                        // زر التفاصيل
                        trailing: GestureDetector(
                          onTap: () {
                            // ملاحظة: UserDetailsScreen تحتاج أيضاً لتعديل لتقبل Map بدلاً من DocumentSnapshot
                            // أو يمكنك تمرير البيانات بشكل مختلف. للآن سأعطلها مؤقتاً لتجنب الأخطاء
                            // Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailsScreen(userData: user)));
                          },
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue,
                            backgroundImage:
                                (user['photoUrl'] != null &&
                                    user['photoUrl'] != '')
                                ? CachedNetworkImageProvider(user['photoUrl'])
                                : null,
                            child:
                                (user['photoUrl'] == null ||
                                    user['photoUrl'] == '')
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddUserScreen()),
        ),
        backgroundColor: orangeColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  // --- دوال مساعدة ---

  Widget _buildTabItem(
    String label,
    int index, {
    bool isDanger = false,
    bool isSuccess = false,
  }) {
    final bool isSelected = _selectedTab == index;
    Color textColor = Colors.grey;
    if (isSelected) {
      textColor = Colors.white;
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
        return l10n.trainees;
      default:
        return 'جميع الأدوار';
    }
  }

  // ويدجت التبديل (Switch) الذي يتصل بالسيرفر
  Widget _buildBlockSwitch(String userId, bool isBlocked) {
    return Transform.scale(
      scale: 0.8,
      child: Switch(
        value: !isBlocked, // تفعيل = حساب نشط
        onChanged: (val) async {
          // استدعاء API لتحديث الحالة
          final success = await _apiService.updateUser({
            'uid': userId,
            'isBlocked': !val, // عكس القيمة لأن val هي "النشاط"
          });

          if (!success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("فشل تحديث الحالة. تأكد من الاتصال بالسيرفر."),
                ),
              );
            }
          }
          // الستريم سيقوم بتحديث الواجهة تلقائياً بعد نجاح العملية في السيرفر
        },
        activeColor: Colors.white,
        activeTrackColor: Colors.grey.shade600,
        inactiveThumbColor: Colors.red,
        inactiveTrackColor: Colors.red.withOpacity(0.3),
      ),
    );
  }
}
