import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
import 'package:drone_academy/screens/trainee_profile_screen.dart'; // <-- استيراد هام جداً
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final ApiService _apiService = ApiService();

  String _searchQuery = '';
  String _selectedRoleFilter = 'trainee';
  String _selectedManagerFilter = 'All';
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const orangeColor = Color(0xFFFF9800);

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allUsers = snapshot.data ?? [];

          final managers = allUsers.where((u) {
            final r = u['role'] ?? '';
            return r == 'admin' || r == 'trainer';
          }).toList();

          final filteredUsers = allUsers.where((user) {
            final name = (user['displayName'] ?? '').toString().toLowerCase();
            final email = (user['email'] ?? '').toString().toLowerCase();
            final role = user['role'] ?? 'trainee';
            final parentId = user['parentId'] ?? '';
            final isBlocked = user['isBlocked'] ?? false;

            if (_searchQuery.isNotEmpty &&
                !name.contains(_searchQuery.toLowerCase()) &&
                !email.contains(_searchQuery.toLowerCase())) {
              return false;
            }

            if (_selectedRoleFilter != 'All' && role != _selectedRoleFilter) {
              return false;
            }

            if (_selectedManagerFilter != 'All' &&
                parentId != _selectedManagerFilter) {
              return false;
            }

            if (_selectedTab == 1 && !isBlocked) return false;

            return true;
          }).toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن مستخدم...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
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

                    _buildDropdownFilter(
                      value: _selectedRoleFilter,
                      label: 'الدور',
                      items: [
                        const DropdownMenuItem(
                          value: 'All',
                          child: Text('جميع الأدوار'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(l10n.admin),
                        ),
                        DropdownMenuItem(
                          value: 'trainer',
                          child: Text(l10n.trainer),
                        ),
                        DropdownMenuItem(
                          value: 'trainee',
                          child: Text(l10n.trainees),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedRoleFilter = val!),
                    ),

                    const SizedBox(height: 8),

                    if (_selectedRoleFilter == 'trainee' ||
                        _selectedRoleFilter == 'All')
                      _buildDropdownFilter(
                        value: _selectedManagerFilter,
                        label: l10n.filterByManager,
                        items: [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text(l10n.allManagers),
                          ),
                          ...managers.map(
                            (m) => DropdownMenuItem(
                              value: m['id'] ?? m['uid'],
                              child: Text(m['displayName'] ?? 'Unknown'),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedManagerFilter = val!),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noResultsFound,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final isBlocked = user['isBlocked'] ?? false;
                          final userId = user['id'] ?? user['uid'];

                          // دالة الانتقال لبروفايل المتدرب
                          void openTraineeProfile() {
                            // نمرر بيانات المستخدم (Map) مباشرة إلى الشاشة
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TraineeProfileScreen(traineeData: user),
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // 1. أزرار التحكم (حذف وتعديل) - يسار
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _showDeleteDialog(
                                        userId,
                                        user['displayName'],
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(height: 16),
                                    // زر التعديل/العرض
                                    IconButton(
                                      icon: const Icon(
                                        Icons.visibility,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      onPressed:
                                          openTraineeProfile, // النقر يفتح البروفايل
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // 2. المعلومات (وسط) - جعلها قابلة للنقر أيضاً
                                Expanded(
                                  child: GestureDetector(
                                    onTap:
                                        openTraineeProfile, // النقر يفتح البروفايل
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          user['displayName'] ?? 'No Name',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user['email'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                        if (isBlocked)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Colors.red,
                                                ),
                                              ),
                                              child: const Text(
                                                'محظور',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // 3. الصورة (يمين) - النقر عليها يفتح البروفايل
                                GestureDetector(
                                  onTap: openTraineeProfile,
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.blue.shade700,
                                    backgroundImage:
                                        (user['photoUrl'] != null &&
                                            user['photoUrl'] != '')
                                        ? CachedNetworkImageProvider(
                                            user['photoUrl'],
                                          )
                                        : null,
                                    child:
                                        (user['photoUrl'] == null ||
                                            user['photoUrl'] == '')
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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

  Widget _buildDropdownFilter({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3F51B5), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E2230),
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Align(
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    item.child,
                  ],
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(String userId, String? userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white)),
        content: Text(
          "هل أنت متأكد من حذف ${userName ?? 'المستخدم'}؟",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _apiService.deleteUser(userId);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
