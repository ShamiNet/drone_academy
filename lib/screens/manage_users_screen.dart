import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
import 'package:drone_academy/screens/trainee_profile_screen.dart';
import 'package:drone_academy/screens/user_details_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/organization_mapping.dart';
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
  String _selectedAffiliationFilter = 'All';

  late Future<List<dynamic>> _usersFuture;

  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _orangeColor = const Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _usersFuture = _apiService.getUsers();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _usersFuture = _apiService.getUsers(forceRefresh: true);
    });
  }

  Color _getUnitColor(String? unitType) {
    if (unitType == 'markazia') return const Color(0xFF9C27B0);
    if (unitType == 'liwa') return const Color(0xFF009688);
    return _cardColor;
  }

  Color _getAffiliationColor(String? affiliation) {
    switch (affiliation) {
      case 'first':
        return const Color(0xFF4CAF50); // أخضر
      case 'second':
        return const Color(0xFF2196F3); // أزرق
      case 'third':
        return const Color(0xFFFF9800); // برتقالي
      case 'fourth':
        return const Color(0xFF9C27B0); // بنفسجي
      case 'artillery':
        return const Color(0xFFF44336); // أحمر
      case 'central':
        return const Color(0xFF607D8B); // رمادي أزرق
      case 'administrative':
        return const Color(0xFF795548); // بني
      default:
        return _cardColor;
    }
  }

  String _getAffiliationLabel(String affiliation) {
    switch (affiliation) {
      case 'first':
        return _selectedUnitFilter == 'markazia' ? 'الأولى' : 'الأول';
      case 'second':
        return _selectedUnitFilter == 'markazia' ? 'الثانية' : 'الثاني';
      case 'third':
        return _selectedUnitFilter == 'markazia' ? 'الثالثة' : 'الثالث';
      case 'fourth':
        return _selectedUnitFilter == 'markazia' ? 'الرابعة' : 'الرابع';
      case 'artillery':
        return 'المدفعية';
      case 'central':
        return 'المركزية';
      case 'administrative':
        return 'إداري';
      default:
        return '';
    }
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

  void _applyQuickUnitFilter(String unitType) {
    setState(() {
      _selectedUnitFilter = unitType;
      _selectedManagerFilter = 'All';
      if (unitType != 'markazia') {
        _selectedAffiliationFilter = 'All';
      } else if (_selectedAffiliationFilter == 'All') {
        _selectedAffiliationFilter = '';
      }
    });
  }

  void _applyQuickAffiliationFilter(String affiliation, {String? unitType}) {
    setState(() {
      if (unitType != null && unitType.isNotEmpty) {
        _selectedUnitFilter = unitType;
      }
      if (affiliation == 'administrative') {
        _selectedUnitFilter = 'markazia';
      }
      _selectedAffiliationFilter = affiliation;
      _selectedManagerFilter = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _bgColor,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<dynamic>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'خطأ: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
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
              final affiliation = user['affiliation'] ?? '';

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
                  _selectedUnitFilter == 'All' ||
                  unitType == _selectedUnitFilter;
              bool matchesAffiliation =
                  _selectedAffiliationFilter.isEmpty ||
                  _selectedAffiliationFilter == 'All' ||
                  affiliation == _selectedAffiliationFilter;

              return matchesSearch &&
                  matchesRole &&
                  matchesManager &&
                  matchesUnit &&
                  matchesAffiliation;
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.role,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                                    onChanged: (val) => setState(
                                      () => _selectedRoleFilter = val!,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.unitType,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                                    onChanged: (val) => setState(() {
                                      _selectedUnitFilter = val!;
                                      // إعادة تعيين التبعية عند تغيير الوحدة
                                      if (val != 'markazia' && val != 'All') {
                                        _selectedAffiliationFilter = 'All';
                                      } else if (val == 'markazia' &&
                                          _selectedAffiliationFilter == 'All') {
                                        // إذا تم اختيار مركزية وكانت التبعية "الكل"، اجعلها فارغة لإجبار الاختيار
                                        _selectedAffiliationFilter = '';
                                      }
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            if (_selectedUnitFilter == 'markazia' ||
                                _selectedUnitFilter == 'liwa' ||
                                _selectedUnitFilter == 'All')
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedUnitFilter == 'markazia'
                                        ? "السرية *"
                                        : "التبعية",
                                    style: TextStyle(
                                      color:
                                          _selectedUnitFilter == 'markazia' &&
                                              _selectedAffiliationFilter.isEmpty
                                          ? Colors.red
                                          : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 120,
                                    child: _buildDropdownFilter(
                                      value: _selectedAffiliationFilter,
                                      label: _selectedUnitFilter == 'markazia'
                                          ? "السرية"
                                          : "التبعية",
                                      items: _selectedUnitFilter == 'markazia'
                                          ? const [
                                              DropdownMenuItem(
                                                value: '',
                                                child: Text(
                                                  'اختر السرية',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'first',
                                                child: Text('الأولى'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'second',
                                                child: Text('الثانية'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'third',
                                                child: Text('الثالثة'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'fourth',
                                                child: Text('الرابعة'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'administrative',
                                                child: Text('إداري'),
                                              ),
                                            ]
                                          : const [
                                              DropdownMenuItem(
                                                value: 'All',
                                                child: Text('الكل'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'first',
                                                child: Text('الأول'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'second',
                                                child: Text('الثاني'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'third',
                                                child: Text('الثالث'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'fourth',
                                                child: Text('الرابع'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'artillery',
                                                child: Text('المدفعية'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'central',
                                                child: Text('المركزية'),
                                              ),
                                            ],
                                      onChanged: (val) => setState(
                                        () => _selectedAffiliationFilter = val!,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.filterByManager,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                                            backgroundColor:
                                                Colors.grey.shade800,
                                            backgroundImage:
                                                (photoUrl.isNotEmpty)
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
                                title: Tooltip(
                                  message: (user['displayName'] ?? 'No Name')
                                      .toString(),
                                  child: Text(
                                    user['displayName'] ?? 'No Name',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                    Row(
                                      children: [
                                        if (unitType.isNotEmpty)
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            onTap: () =>
                                                _applyQuickUnitFilter(unitType),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              margin: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getUnitColor(unitType),
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                                        if (user['affiliation'] != null &&
                                            user['affiliation']
                                                .toString()
                                                .isNotEmpty)
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            onTap: () =>
                                                _applyQuickAffiliationFilter(
                                                  user['affiliation'],
                                                  unitType: unitType,
                                                ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getAffiliationColor(
                                                  user['affiliation'],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getAffiliationLabel(
                                                  user['affiliation'],
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (user['nickname'] != null &&
                                            user['nickname']
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF2196F3,
                                              ), // لون أزرق للقب
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              user['nickname'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
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
    final currentUser = ApiService.currentUser;
    final currentUserRole =
        currentUser?['role']?.toString().toLowerCase() ?? 'trainee';
    final canEditOwner = currentUserRole == 'owner';

    String currentRole = (user['role']?.toString() ?? '').isEmpty
        ? 'trainee'
        : user['role'];
    if (!['owner', 'admin', 'trainer', 'trainee'].contains(currentRole)) {
      currentRole = 'trainee';
    }
    String? currentParentId = user['parentId'];
    String? currentUnitType = user['unitType'];
    if (currentUnitType != null && currentUnitType.isEmpty) {
      currentUnitType = null;
    }
    String? currentDivision = divisionLabelFromUser(user);
    if (currentDivision != null && currentDivision.isEmpty) {
      currentDivision = null;
    }

    int currentLevel = int.tryParse(user['level'].toString()) ?? 1;
    if (currentLevel < 1 || currentLevel > 3) {
      currentLevel = 1;
    }
    bool currentHasInventoryAccess = user['hasInventoryAccess'] ?? false;

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
                        if (canEditOwner || currentRole == 'owner')
                          DropdownMenuItem(
                            value: 'owner',
                            child: Text(l10n.generalSupervisor),
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
                      onChanged: (val) {
                        if (val == 'owner' && !canEditOwner) return;
                        setDialogState(() => currentRole = val!);
                      },
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

                    // 3.5. اللواء
                    const Text(
                      'اللواء',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    DropdownButton<String>(
                      value: currentDivision,
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
                        const DropdownMenuItem(
                          value: 'اللواء الأول',
                          child: Text('اللواء الأول'),
                        ),
                        const DropdownMenuItem(
                          value: 'اللواء الثاني',
                          child: Text('اللواء الثاني'),
                        ),
                        const DropdownMenuItem(
                          value: 'اللواء الثالث',
                          child: Text('اللواء الثالث'),
                        ),
                        const DropdownMenuItem(
                          value: 'اللواء الرابع',
                          child: Text('اللواء الرابع'),
                        ),
                        const DropdownMenuItem(
                          value: 'المدفعية',
                          child: Text('المدفعية'),
                        ),
                        const DropdownMenuItem(
                          value: 'المركزية',
                          child: Text('المركزية'),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => currentDivision = val),
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
                    const SizedBox(height: 16),

                    // 5. صلاحية الوصول للمخزون والمعدات
                    if (currentRole == 'trainee') ...[
                      Row(
                        children: [
                          Checkbox(
                            value: currentHasInventoryAccess,
                            onChanged: (val) => setDialogState(
                              () => currentHasInventoryAccess = val ?? false,
                            ),
                            activeColor: const Color(0xFFFF9800),
                          ),
                          Expanded(
                            child: Text(
                              l10n.inventoryAccessPermission,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
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
                    final success = await _apiService.updateUser({
                      'uid': userId,
                      'role': currentRole,
                      'parentId': currentParentId ?? '',
                      'unitType': currentUnitType ?? '',
                      'division': currentDivision ?? '',
                      'affiliation': affiliationFromDivision(currentDivision),
                      'level': currentLevel,
                      'hasInventoryAccess': currentHasInventoryAccess,
                    });
                    if (mounted) {
                      if (success) {
                        Navigator.pop(ctx);
                        showCustomSnackBar(
                          context,
                          l10n.userDataUpdated,
                          isError: false,
                        );
                      } else {
                        showCustomSnackBar(context, l10n.failed, isError: true);
                      }
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
                            title: Tooltip(
                              message: (user['displayName'] ?? 'Unknown')
                                  .toString(),
                              child: Text(
                                user['displayName'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
    // Ensure value is in items, otherwise use the first item's value
    String validValue = value;
    if (!items.any((item) => item.value == value)) {
      validValue = items.isNotEmpty ? items.first.value! : '';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
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
