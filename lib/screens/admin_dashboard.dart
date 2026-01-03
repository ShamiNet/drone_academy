import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_settings_screen.dart';
import 'package:drone_academy/screens/contact_developer_screen.dart'; // [إضافة] استيراد شاشة الدعم
import 'package:drone_academy/screens/error_logs_screen.dart';
import 'package:drone_academy/screens/manage_competitions_tab.dart';
import 'package:drone_academy/screens/manage_equipment_screen.dart';
import 'package:drone_academy/screens/manage_inventory_screen.dart';
import 'package:drone_academy/screens/manage_trainings_tab.dart';
import 'package:drone_academy/screens/manage_users_screen.dart';
import 'package:drone_academy/screens/profile_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// خدمة حفظ الثيم
class ThemeService {
  static Future<void> saveThemeMode(ThemeMode mode) async {
    print('🌗 Theme mode saved: ${mode.name}');
  }
}

class AdminDashboard extends StatefulWidget {
  // استقبال دالة تغيير الثيم
  final void Function(ThemeMode) setThemeMode;

  const AdminDashboard({super.key, required this.setThemeMode});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  String? _photoUrl;
  String? _displayName;
  String? _email;

  // الألوان
  final Color _bgColor = const Color(0xFF111318);
  final Color _appBarColor = const Color(0xFF111318);
  final Color _primaryColor = const Color(0xFFFF9800); // برتقالي
  final Color _secondaryColor = const Color(0xFF3F51B5); // أزرق

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _fetchProfile() async {
    final currentUser = ApiService.currentUser;
    if (currentUser != null) {
      final userData = await _apiService.fetchUser(
        currentUser['uid'] ?? currentUser['id'],
      );
      if (mounted && userData != null) {
        setState(() {
          _photoUrl = userData['photoUrl'];
          _displayName = userData['displayName'];
          _email = userData['email'];
        });
      } else if (mounted) {
        setState(() {
          _photoUrl = currentUser['photoUrl'];
          _displayName = currentUser['displayName'];
          _email = currentUser['email'];
        });
      }
    }
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen(setLocale: (l) {})),
    ).then((_) => _fetchProfile());
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminSettingsScreen()),
    );
  }

  // [تعديل] دالة الانتقال للدعم
  void _goToSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactDeveloperScreen()),
    );
  }

  Future<void> _logout() async {
    await _apiService.logout();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // نافذة اختيار الثيم
  void _showThemeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2230),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "اختر مظهر التطبيق",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeOption(
                ctx,
                "حسب النظام",
                Icons.settings_brightness,
                ThemeMode.system,
              ),
              _buildThemeOption(
                ctx,
                "فاتح (Light)",
                Icons.light_mode,
                ThemeMode.light,
              ),
              _buildThemeOption(
                ctx,
                "داكن (Dark)",
                Icons.dark_mode,
                ThemeMode.dark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext ctx,
    String title,
    IconData icon,
    ThemeMode mode,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () async {
        widget.setThemeMode(mode);
        await ThemeService.saveThemeMode(mode);
        if (mounted) Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: _bgColor,
        drawer: _buildProfessionalDrawer(l10n),

        appBar: AppBar(
          backgroundColor: _appBarColor,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'الرئيسية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset('assets/images/logo.png', width: 30),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'لوحة تحكم المدير',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  labelColor: _primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _primaryColor,
                  tabs: [
                    Tab(
                      text: l10n.trainings,
                      icon: const Icon(Icons.model_training),
                    ),
                    Tab(
                      text: l10n.competitions,
                      icon: const Icon(Icons.emoji_events),
                    ),
                    Tab(text: l10n.users, icon: const Icon(Icons.people)),
                    Tab(
                      text: l10n.equipment,
                      icon: const Icon(Icons.construction),
                    ),
                    Tab(
                      text: l10n.inventory,
                      icon: const Icon(Icons.inventory_2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ManageTrainingsTab(),
            ManageCompetitionsTab(),
            ManageUsersScreen(),
            ManageEquipmentScreen(),
            ManageInventoryScreen(),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      ),
    );
  }

  Widget _buildProfessionalDrawer(AppLocalizations l10n) {
    return Drawer(
      child: Container(
        color: const Color(0xFF1E2230),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_secondaryColor, _bgColor],
                ),
              ),
              currentAccountPicture: GestureDetector(
                onTap: _goToProfile,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _primaryColor, width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage:
                        (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(_photoUrl!)
                        : null,
                    child: (_photoUrl == null)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              accountName: Text(
                _displayName ?? 'Admin',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(
                _email ?? '',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    title: 'الملف الشخصي',
                    onTap: () {
                      Navigator.pop(context);
                      _goToProfile();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'الإعدادات العامة',
                    onTap: () {
                      Navigator.pop(context);
                      _goToSettings();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.wb_sunny_outlined,
                    title: 'المظهر (Theme)',
                    onTap: () {
                      Navigator.pop(context);
                      _showThemeDialog();
                    },
                  ),
                  const Divider(color: Colors.grey),
                  // [تعديل] ربط زر الدعم
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    title: 'المساعدة والدعم',
                    onTap: () {
                      Navigator.pop(context);
                      _goToSupport(); // الانتقال لصفحة التواصل
                    },
                  ),
                  // مثال لإضافة الزر في Drawer المدير
                  ListTile(
                    leading: const Icon(
                      Icons.bug_report,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      "سجل الأخطاء (للمطور)",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ErrorLogsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              child: _buildDrawerItem(
                icon: Icons.logout,
                title: l10n.logout,
                color: Colors.redAccent,
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
