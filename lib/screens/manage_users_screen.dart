import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
import 'package:drone_academy/screens/trainee_profile_screen.dart';
import 'package:drone_academy/screens/user_details_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final ApiService _apiService = ApiService();

  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  String _selectedManagerFilter = 'All';
  String _selectedUnitFilter = 'All'; // فلتر الوحدات الجديد

  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _orangeColor = const Color(0xFFFF9800);

  // ألوان التمييز للوحدات
  Color _getUnitColor(String? unitType) {
    if (unitType == 'markazia')
      return const Color(0xFF9C27B0); // بنفسجي للمركزية
    if (unitType == 'liwa')
      return const Color(0xFF009688); // تيفاني/أخضر للألوية
    return _cardColor; // الافتراضي
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFFFFD700);
      case 'admin':
        return const Color(0xFFFF5252);
      case 'trainer':
        return const Color(0xFF448AFF);
      case 'trainee':
        return const Color(0xFF69F0AE);
      default:
        return Colors.grey;
    }
  }

  // ... (نفس دوال الأيقونات والتسميات السابقة)
  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.workspace_premium;
      case 'admin':
        return Icons.security;
      case 'trainer':
        return Icons.school;
      case 'trainee':
        return Icons.person;
      default:
        return Icons.help_outline;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'المدير العام';
      case 'admin':
        return 'المدراء';
      case 'trainer':
        return 'المدربين';
      case 'trainee':
        return 'المتدربين';
      default:
        return role;
    }
  }

  int _getRoleOrder(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 1;
      case 'admin':
        return 2;
      case 'trainer':
        return 3;
      case 'trainee':
        return 4;
      default:
        return 5;
    }
  }

  void _navigateToUserProfile(Map<String, dynamic> user) {
    final role = (user['role'] ?? 'trainee').toString().toLowerCase();
    if (role == 'trainee') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TraineeProfileScreen(traineeData: user),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserDetailsScreen(userData: user),
        ),
      );
    }
  }

  // دالة جديدة لفتح البروفايل (معلومات شخصية)
  void _navigateToUserProfileInfo(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserDetailsScreen(userData: user, forceInfoView: true),
      ),
    );
  }

  // دالة لفتح تفاصيل التدريب (الوضع الافتراضي)
  void _navigateToTrainingDetails(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserDetailsScreen(userData: user, forceInfoView: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allUsers = snapshot.data ?? [];
          final managers = allUsers.where((u) {
            final r = (u['role'] ?? '').toString().toLowerCase();
            return r == 'owner' || r == 'admin' || r == 'trainer';
          }).toList();

          final filteredUsers = allUsers.where((user) {
            final name = (user['displayName'] ?? '').toString().toLowerCase();
            final email = (user['email'] ?? '').toString().toLowerCase();
            final role = (user['role'] ?? 'trainee').toString().toLowerCase();
            final parentId = user['parentId'] ?? '';
            final unitType = user['unitType'] ?? '';

            bool matchesSearch =
                name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase());
            bool matchesRole =
                _selectedRoleFilter == 'All' ||
                role == _selectedRoleFilter.toLowerCase();
            bool matchesManager =
                _selectedManagerFilter == 'All' ||
                parentId == _selectedManagerFilter;
            // شرط فلتر الوحدات
            bool matchesUnit =
                _selectedUnitFilter == 'All' || unitType == _selectedUnitFilter;

            return matchesSearch &&
                matchesRole &&
                matchesManager &&
                matchesUnit;
          }).toList();

          filteredUsers.sort((a, b) {
            int orderA = _getRoleOrder(a['role'] ?? '');
            int orderB = _getRoleOrder(b['role'] ?? '');
            return orderA.compareTo(orderB);
          });

          return Column(
            children: [
              // --- قسم البحث والفلترة ---
              Container(
                padding: const EdgeInsets.all(16.0),
                color: _bgColor,
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'بحث عن مستخدم...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: _cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: _buildDropdownFilter(
                              value: _selectedRoleFilter,
                              label: 'الدور',
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('الكل'),
                                ),
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text('المدراء'),
                                ),
                                DropdownMenuItem(
                                  value: 'trainer',
                                  child: Text('المدربين'),
                                ),
                                DropdownMenuItem(
                                  value: 'trainee',
                                  child: Text('المتدربين'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedRoleFilter = val!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // --- فلتر الوحدات الجديد ---
                          SizedBox(
                            width: 130,
                            child: _buildDropdownFilter(
                              value: _selectedUnitFilter,
                              label: 'الوحدة',
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('كل الوحدات'),
                                ),
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
                                  setState(() => _selectedUnitFilter = val!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_selectedRoleFilter == 'trainee' ||
                              _selectedRoleFilter == 'All')
                            SizedBox(
                              width: 150,
                              child: _buildDropdownFilter(
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
                                      child: Text(
                                        m['displayName'] ?? 'Unknown',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) => setState(
                                  () => _selectedManagerFilter = val!,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- القائمة ---
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
                          final isBlocked = user['isBlocked'] == true;
                          final String role = user['role'] ?? 'trainee';
                          final String photoUrl = user['photoUrl'] ?? '';
                          final Color roleColor = _getRoleColor(role);
                          final String unitType = user['unitType'] ?? '';

                          // لون البطاقة حسب الوحدة
                          final Color cardBackground = unitType.isNotEmpty
                              ? _getUnitColor(unitType).withOpacity(0.15)
                              : _cardColor;

                          // لون الحدود (Border) لزيادة الوضوح
                          final Color borderColor = unitType.isNotEmpty
                              ? _getUnitColor(unitType).withOpacity(0.5)
                              : Colors.transparent;

                          return Card(
                            color: cardBackground,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isBlocked ? Colors.red : borderColor,
                                width: isBlocked ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: GestureDetector(
                                onTap: () => _navigateToUserProfileInfo(user),
                                child: Hero(
                                  tag:
                                      'user_avatar_${user['id'] ?? user['uid']}',
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: roleColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Colors.grey.shade800,
                                          backgroundImage: (photoUrl.isNotEmpty)
                                              ? CachedNetworkImageProvider(
                                                  photoUrl,
                                                )
                                              : null,
                                          child: (photoUrl.isEmpty)
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 28,
                                                )
                                              : null,
                                        ),
                                      ),
                                      if (isBlocked)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.block,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
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
                                  if (unitType.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getUnitColor(unitType),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          unitType == 'liwa'
                                              ? 'ألوية'
                                              : 'مركزية',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: roleColor.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getRoleIcon(role),
                                      color: roleColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getRoleLabel(role),
                                      style: TextStyle(
                                        color: roleColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () => _navigateToUserProfile(user),
                              onLongPress: () => _showUserOptions(
                                context,
                                user,
                                allUsers,
                              ), // _showUserOptions same as before
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
        backgroundColor: _orangeColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // ... (بقية الدوال المساعدة مثل _showUserOptions, _showEditUserDialog, _showSelectParentDialog تبقى كما هي)
  void _showUserOptions(
    BuildContext context,
    Map<String, dynamic> user,
    List<dynamic> allUsers,
  ) {
    // ... Copy implementation from original file if needed, keeping it standard
    // For brevity, assuming standard implementation exists in the full file context
    final l10n = AppLocalizations.of(context)!;
    final bool isBlocked = user['isBlocked'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user['displayName'] ?? 'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text(
                  l10n.edit,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditUserDialog(user, allUsers);
                },
              ),
              if (user['role'] != 'owner')
                ListTile(
                  leading: Icon(
                    isBlocked ? Icons.check_circle : Icons.block,
                    color: isBlocked ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    isBlocked ? l10n.unblockUser : l10n.blockUser,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleBlockStatus(user, !isBlocked);
                  },
                ),
              if (user['role'] != 'owner')
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    l10n.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteDialog(
                      user['id'] ?? user['uid'],
                      user['displayName'],
                      l10n,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user, List<dynamic> allUsers) {
    String currentRole = user['role'] ?? 'trainee';
    String? currentParentId = user['parentId'];
    String? currentUnitType = user['unitType'];

    // [جديد] جلب المستوى الحالي (الافتراضي 1)
    int currentLevel = int.tryParse(user['level'].toString()) ?? 1;

    final userId = user['id'] ?? user['uid'];

    // منطق اختيار المدرب المسؤول (كما هو)
    if (currentParentId != null && currentParentId.isEmpty) {
      currentParentId = null;
    }
    String currentParentName = 'بدون مدرب';
    if (currentParentId != null) {
      final parent = allUsers.firstWhere(
        (u) => (u['id'] ?? u['uid']) == currentParentId,
        orElse: () => null,
      );
      if (parent != null) {
        currentParentName = parent['displayName'];
      } else {
        currentParentId = null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2230),
              title: const Text(
                "تعديل المستخدم",
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                // إضافة سكرول لتجنب مشاكل المساحة
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. قائمة الدور (Role)
                    const Text(
                      "الدور:",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    DropdownButton<String>(
                      value: currentRole,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(height: 1, color: Colors.grey),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('المدراء'),
                        ),
                        DropdownMenuItem(
                          value: 'trainer',
                          child: Text('المدربين'),
                        ),
                        DropdownMenuItem(
                          value: 'trainee',
                          child: Text('المتدربين'),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => currentRole = val!),
                    ),
                    const SizedBox(height: 16),

                    // 2. [جديد] قائمة المستوى (تظهر فقط للمتدربين)
                    if (currentRole == 'trainee') ...[
                      const Text(
                        "مستوى المتدرب:",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      DropdownButton<int>(
                        value: currentLevel,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        underline: Container(height: 1, color: Colors.grey),
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child: Text('المستوى 1 (مبتدئ)'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('المستوى 2 (متوسط)'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('المستوى 3 (متقدم)'),
                          ),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => currentLevel = val!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 3. قائمة نوع الوحدة (Unit Type)
                    const Text(
                      "نوع الوحدة:",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    DropdownButton<String>(
                      value: currentUnitType,
                      isExpanded: true,
                      hint: const Text(
                        "غير محدد",
                        style: TextStyle(color: Colors.grey),
                      ),
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(height: 1, color: Colors.grey),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('غير محدد')),
                        DropdownMenuItem(value: 'liwa', child: Text('ألوية')),
                        DropdownMenuItem(
                          value: 'markazia',
                          child: Text('مركزية'),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => currentUnitType = val),
                    ),
                    const SizedBox(height: 16),

                    // 4. المدرب المسؤول
                    const Text(
                      "المدرب المسؤول:",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    InkWell(
                      onTap: () async {
                        final result = await _showSelectParentDialog(
                          allUsers,
                          userId,
                        );
                        if (result != null) {
                          setDialogState(() {
                            currentParentId = result['id'];
                            currentParentName = result['name'];
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              currentParentName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // حفظ البيانات بما فيها المستوى الجديد
                    await _apiService.updateUser({
                      'uid': userId,
                      'role': currentRole,
                      'parentId': currentParentId ?? '',
                      'unitType': currentUnitType ?? '',
                      'level': currentLevel, // [تمت الإضافة]
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      showCustomSnackBar(
                        context,
                        "تم تحديث البيانات والمستوى بنجاح",
                        isError: false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text("حفظ"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showSelectParentDialog(
    List<dynamic> allUsers,
    String currentUserId,
  ) async {
    // ... (Same as original)
    final potentialParents = allUsers
        .where((u) => (u['id'] ?? u['uid']) != currentUserId)
        .toList();
    potentialParents.sort(
      (a, b) => _getRoleOrder(
        a['role'] ?? '',
      ).compareTo(_getRoleOrder(b['role'] ?? '')),
    );
    TextEditingController searchCtrl = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = potentialParents.where((u) {
              final name = (u['displayName'] ?? '').toString().toLowerCase();
              return name.contains(searchCtrl.text.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E2230),
              title: const Text(
                "اختر المسؤول",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "بحث...",
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                      onChanged: (v) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.highlight_off, color: Colors.white),
                      ),
                      title: const Text(
                        "بدون مدرب (مستوى أعلى)",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, {
                        'id': null,
                        'name': 'بدون مدرب',
                      }),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          return ListTile(
                            title: Text(
                              user['displayName'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () => Navigator.pop(context, {
                              'id': user['id'] ?? user['uid'],
                              'name': user['displayName'],
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleBlockStatus(Map<String, dynamic> user, bool shouldBlock) async {
    // ... (Same as original)
    final success = await _apiService.updateUser({
      'uid': user['id'] ?? user['uid'],
      'isBlocked': shouldBlock,
    });
    if (mounted) {
      showCustomSnackBar(
        context,
        success
            ? (shouldBlock ? 'تم حظر المستخدم' : 'تم تفعيل المستخدم')
            : 'فشل العملية',
        isError: !success || shouldBlock,
      );
    }
  }

  void _showDeleteDialog(
    String userId,
    String? userName,
    AppLocalizations l10n,
  ) {
    // ... (Same as original)
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          l10n.confirmDeletion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          "${l10n.areYouSureDelete} ($userName)؟",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _apiService.deleteUser(userId);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    // ... (Same as original)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: _cardColor,
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        ),
      ),
    );
  }
}
