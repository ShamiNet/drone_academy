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
  String _selectedUnitFilter = 'All';

  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _orangeColor = const Color(0xFFFF9800);

  Color _getUnitColor(String? unitType) {
    if (unitType == 'markazia') return const Color(0xFF9C27B0);
    if (unitType == 'liwa') return const Color(0xFF009688);
    return _cardColor;
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

  String _getRoleLabel(String role, AppLocalizations l10n) {
    switch (role.toLowerCase()) {
      case 'owner':
        return l10n.generalSupervisor; // ✅ تم التغيير لاستدعاء "المشرف العام"
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

  void _navigateToUserProfileInfo(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserDetailsScreen(userData: user, forceInfoView: true),
      ),
    );
  }

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
              Container(
                padding: const EdgeInsets.all(16.0),
                color: _bgColor,
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.searchTrainee,
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
                              label: l10n.role,
                              items: [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text(l10n.all),
                                ),
                                // ✅ تم إضافة هذا الخيار لتجنب المشاكل في الفلترة أيضاً
                                DropdownMenuItem(
                                  value: 'owner',
                                  child: Text(
                                    l10n.generalSupervisor,
                                  ), // ✅ "المشرف العام"
                                ),
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text(l10n.admin),
                                ),
                                DropdownMenuItem(
                                  value: 'trainer',
                                  child: Text(l10n.trainers),
                                ),
                                DropdownMenuItem(
                                  value: 'trainee',
                                  child: Text(l10n.trainees),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedRoleFilter = val!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 130,
                            child: _buildDropdownFilter(
                              value: _selectedUnitFilter,
                              label: l10n.unitType,
                              items: [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text(l10n.all),
                                ),
                                DropdownMenuItem(
                                  value: 'liwa',
                                  child: Text(l10n.liwa),
                                ),
                                DropdownMenuItem(
                                  value: 'markazia',
                                  child: Text(l10n.markazia),
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

                          final Color cardBackground = unitType.isNotEmpty
                              ? _getUnitColor(unitType).withOpacity(0.15)
                              : _cardColor;

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
                                              ? l10n.liwa
                                              : l10n.markazia,
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
                                      _getRoleLabel(role, l10n),
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
                              onLongPress: () =>
                                  _showUserOptions(context, user, allUsers),
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

  void _showUserOptions(
    BuildContext context,
    Map<String, dynamic> user,
    List<dynamic> allUsers,
  ) {
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
                user['displayName'] ?? l10n.users,
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
    final l10n = AppLocalizations.of(context)!;
    String currentRole = user['role'] ?? 'trainee';
    String? currentParentId = user['parentId'];
    String? currentUnitType = user['unitType'];

    int currentLevel = int.tryParse(user['level'].toString()) ?? 1;

    final userId = user['id'] ?? user['uid'];

    if (currentParentId != null && currentParentId.isEmpty) {
      currentParentId = null;
    }
    String currentParentName = l10n.noTrainer;
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
              title: Text(
                l10n.editProfile,
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الدور
                    Text(
                      l10n.role,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    DropdownButton<String>(
                      value: currentRole,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(height: 1, color: Colors.grey),
                      items: [
                        // ✅ تم إضافة الشرط هنا: إذا كان الدور owner، أظهر الخيار owner
                        // ✅ تعديل اسم الاونر في القائمة
                        if (currentRole == 'owner')
                          DropdownMenuItem(
                            value: 'owner',
                            child: Text(
                              l10n.generalSupervisor,
                            ), // "المشرف العام"
                          ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(l10n.admin),
                        ),
                        DropdownMenuItem(
                          value: 'trainer',
                          child: Text(l10n.trainers),
                        ),
                        DropdownMenuItem(
                          value: 'trainee',
                          child: Text(l10n.trainees),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => currentRole = val!),
                    ),
                    const SizedBox(height: 16),

                    // 2. المستوى
                    if (currentRole == 'trainee') ...[
                      Text(
                        l10n.traineeLevel,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      DropdownButton<int>(
                        value: currentLevel,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        underline: Container(height: 1, color: Colors.grey),
                        items: [
                          DropdownMenuItem(
                            value: 1,
                            child: Text(l10n.level1Beginner),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(l10n.level2Intermediate),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text(l10n.level3Advanced),
                          ),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => currentLevel = val!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 3. نوع الوحدة
                    Text(
                      l10n.unitType,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    DropdownButton<String>(
                      value: currentUnitType,
                      isExpanded: true,
                      hint: Text(
                        l10n.notSpecified,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(height: 1, color: Colors.grey),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.notSpecified),
                        ),
                        DropdownMenuItem(value: 'liwa', child: Text(l10n.liwa)),
                        DropdownMenuItem(
                          value: 'markazia',
                          child: Text(l10n.markazia),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => currentUnitType = val),
                    ),
                    const SizedBox(height: 16),

                    // 4. المدرب المسؤول
                    Text(
                      l10n.responsibleTrainer,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _apiService.updateUser({
                      'uid': userId,
                      'role': currentRole,
                      'parentId': currentParentId ?? '',
                      'unitType': currentUnitType ?? '',
                      'level': currentLevel,
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      showCustomSnackBar(
                        context,
                        l10n.userDataUpdated,
                        isError: false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text(l10n.save),
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
    final l10n = AppLocalizations.of(context)!;
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
              title: Text(
                l10n.selectNewParent,
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.lookup,
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                      ),
                      onChanged: (v) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.highlight_off, color: Colors.white),
                      ),
                      title: Text(
                        l10n.noTrainer,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, {
                        'id': null,
                        'name': l10n.noTrainer,
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
    final l10n = AppLocalizations.of(context)!;
    final success = await _apiService.updateUser({
      'uid': user['id'] ?? user['uid'],
      'isBlocked': shouldBlock,
    });
    if (mounted) {
      showCustomSnackBar(
        context,
        success
            ? (shouldBlock ? l10n.userBlocked : l10n.userUnblocked)
            : l10n.failed,
        isError: !success || shouldBlock,
      );
    }
  }

  void _showDeleteDialog(
    String userId,
    String? userName,
    AppLocalizations l10n,
  ) {
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
