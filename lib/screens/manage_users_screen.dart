import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
import 'package:drone_academy/screens/user_details_screen.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late AppLocalizations l10n;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedRole = 'all';
  String? _selectedManagerId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditUserDialog(
    BuildContext context,
    DocumentSnapshot user,
    List<DocumentSnapshot> allUsers,
  ) {
    String currentRole = user['role'];
    String? currentParentId =
        (user.data() as Map<String, dynamic>).containsKey('parentId')
        ? user['parentId']
        : null;
    final potentialParents = allUsers.where((u) => u.id != user.id).toList();
    final _displayNameController = TextEditingController(
      text: user['displayName'],
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${l10n.edit} ${user['displayName']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _displayNameController,
                      decoration: InputDecoration(labelText: l10n.fullName),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.role,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: currentRole,
                      isExpanded: true,
                      items: ['admin', 'manager', 'trainer', 'trainee'].map((
                        String role,
                      ) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() => currentRole = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.selectNewParent,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String?>(
                      hint: const Text('Top Level'),
                      value: currentParentId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Top Level'),
                        ),
                        ...potentialParents.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['displayName']),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) {
                        setDialogState(() => currentParentId = newValue);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.id)
                        .update({
                          'displayName': _displayNameController.text,
                          'role': currentRole,
                          'parentId': currentParentId ?? '',
                        });
                    Navigator.pop(context);
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteUserDialog(BuildContext context, DocumentSnapshot user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text('${l10n.areYouSureDelete} (${user['displayName']})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.id)
                  .delete();
              Navigator.pop(context);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleExpansionTile(
    BuildContext context,
    String title,
    List<DocumentSnapshot> users,
    List<DocumentSnapshot> allUsers,
    Color color,
  ) {
    if (users.isEmpty) {
      return const SizedBox.shrink(); // لا تعرض القسم إذا لم يكن هناك مستخدمون
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text('$title (${users.length})'),
        leading: Icon(Icons.group, color: color),
        children: users.map((user) {
          final role = user['role'];
          Color roleColor = Colors.grey;
          if (role == 'admin') roleColor = Colors.red;
          if (role == 'manager') roleColor = Colors.orange;
          if (role == 'trainer') roleColor = Colors.blue;
          if (role == 'trainee') roleColor = Colors.green;

          return ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailsScreen(userDoc: user),
              ),
            ),
            leading: CircleAvatar(
              backgroundImage:
                  (user['photoUrl'] != null && // --- التعديل هنا
                      user['photoUrl'].isNotEmpty)
                  ? CachedNetworkImageProvider(user['photoUrl'])
                  : null,
              child: (user['photoUrl'] == null || user['photoUrl'].isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              user['displayName'],
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              role,
              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditUserDialog(context, user, allUsers),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteUserDialog(context, user),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ودجت جديد لعرض قائمة المستخدمين عند الفلترة
  Widget _buildFilteredUserList(
    BuildContext context,
    List<DocumentSnapshot> users,
    List<DocumentSnapshot> allUsers,
  ) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsScreen(userDoc: user),
            ),
          ),
          leading: CircleAvatar(
            backgroundImage:
                (user['photoUrl'] != null && user['photoUrl'].isNotEmpty)
                ? CachedNetworkImageProvider(user['photoUrl'])
                : null,
            child: (user['photoUrl'] == null || user['photoUrl'].isEmpty)
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(
            user['displayName'],
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            user['email'] ?? '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditUserDialog(context, user, allUsers),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteUserDialog(context, user),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n
                    .searchTrainee, // TODO: Change to a more generic searchUser key
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: l10n.role,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              isExpanded: true,
              items: [
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text(l10n.allRoles),
                ),
                DropdownMenuItem<String>(
                  value: 'admin',
                  child: Text(l10n.admin),
                ),
                DropdownMenuItem<String>(
                  value: 'manager',
                  child: Text(l10n.manager),
                ),
                DropdownMenuItem<String>(
                  value: 'trainee',
                  child: Text(l10n.trainees),
                ),
                DropdownMenuItem<String>(
                  value: 'trainer',
                  child: Text(l10n.trainers),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedRole = newValue;
                  });
                }
              },
            ),
          ),
          // --- بداية الإضافة: قائمة منسدلة لفلترة المتدربين حسب المسؤول ---
          if (_selectedRole == 'trainee')
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', whereIn: ['manager', 'trainer', 'admin'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final managers = snapshot.data!.docs;
                  return DropdownButtonFormField<String?>(
                    value: _selectedManagerId,
                    hint: Text(l10n.filterByManager),
                    decoration: InputDecoration(
                      labelText: l10n.filterByManager,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.allManagers),
                      ),
                      ...managers.map((manager) {
                        return DropdownMenuItem<String>(
                          value: manager.id,
                          child: Text(manager['displayName']),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedManagerId = newValue;
                      });
                    },
                  );
                },
              ),
            ),
          // --- نهاية الإضافة ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('role')
                  .orderBy('displayName')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allUsers = snapshot.data?.docs ?? [];

                // Filter users based on search query
                final searchedUsers = allUsers.where((user) {
                  final displayName = user['displayName']?.toLowerCase() ?? '';
                  return displayName.contains(_searchQuery.toLowerCase());
                }).toList();

                // Filter users based on selected role
                final filteredUsers = searchedUsers.where((user) {
                  if (_selectedRole == 'all') {
                    return true;
                  }
                  final role = user['role']?.toLowerCase() ?? '';
                  return role == _selectedRole;
                }).toList();

                // --- بداية الإضافة: فلترة إضافية حسب المسؤول إذا تم تحديده ---
                final managerFilteredUsers = filteredUsers.where((user) {
                  if (_selectedRole == 'trainee' &&
                      _selectedManagerId != null) {
                    return user['parentId'] == _selectedManagerId;
                  }
                  return true; // إذا لم يكن الفلتر مفعلاً، اعرض الجميع
                }).toList();

                if (filteredUsers.isEmpty) {
                  // Show empty state if no users are found (for any filter)
                  // But only show the big illustration if there are no users at all.
                  if (_searchQuery.isEmpty && _selectedRole == 'all') {
                    return EmptyStateWidget(
                      message: l10n.noUsersFound,
                      imagePath: 'assets/illustrations/no_data.svg',
                    );
                  } else {
                    return Center(
                      child: Text(l10n.noUsersFound),
                    ); // No users found for search or filter
                  }
                }

                // Group filtered users by role
                final Map<String, List<DocumentSnapshot>> usersByRole = {
                  'admin': [],
                  'manager': [],
                  'trainer': [],
                  'trainee': [],
                };

                for (var user in managerFilteredUsers) {
                  // استخدام القائمة المفلترة الجديدة
                  final role = user['role'] as String;
                  if (usersByRole.containsKey(role)) {
                    usersByRole[role]!.add(user);
                  }
                }

                // --- بداية التعديل: تغيير طريقة العرض بناءً على الفلتر ---
                if (_selectedRole == 'all') {
                  // إذا كان الفلتر "الكل"، اعرض الأقسام القابلة للتوسيع
                  return ListView(
                    children: [
                      _buildRoleExpansionTile(
                        context,
                        l10n.admin,
                        usersByRole['admin']!,
                        allUsers,
                        Colors.red,
                      ),
                      _buildRoleExpansionTile(
                        context,
                        l10n.manager,
                        usersByRole['manager']!,
                        allUsers,
                        Colors.orange,
                      ),
                      _buildRoleExpansionTile(
                        context,
                        l10n.trainers,
                        usersByRole['trainer']!,
                        allUsers,
                        Colors.blue,
                      ),
                      _buildRoleExpansionTile(
                        context,
                        l10n.trainees,
                        usersByRole['trainee']!,
                        allUsers,
                        Colors.green,
                      ),
                    ],
                  );
                } else {
                  // إذا تم اختيار دور معين، اعرض قائمة مباشرة
                  return _buildFilteredUserList(
                    context,
                    managerFilteredUsers, // استخدام القائمة المفلترة الجديدة
                    allUsers,
                  );
                }
                // --- نهاية التعديل ---
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-manage-users',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddUserScreen()),
          );
        },
        tooltip: l10n.addUser,
        child: const Icon(Icons.add),
      ),
    );
  }
}
