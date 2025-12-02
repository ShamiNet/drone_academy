import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_dashboard.dart';
import 'package:drone_academy/screens/equipment_checkout_screen.dart';
import 'package:drone_academy/screens/inventory_screen.dart';
import 'package:drone_academy/screens/login_screen.dart';
import 'package:drone_academy/screens/my_progress_screen.dart';
import 'package:drone_academy/screens/profile_screen.dart';
import 'package:drone_academy/screens/trainee_competitions_screen.dart';
import 'package:drone_academy/screens/trainee_dashboard.dart';
import 'package:drone_academy/screens/trainer_dashboard.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class ThemeService {
  static Future<void> saveThemeMode(ThemeMode mode) async {
    debugPrint('Theme mode saved: ${mode.name}');
  }
}

class HomeScreen extends StatefulWidget {
  final void Function(Locale) setLocale;
  final void Function(ThemeMode)? setThemeMode;
  const HomeScreen({super.key, required this.setLocale, this.setThemeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  String? _userName;
  String? _userRole;
  String? _photoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    // --- التعديل الجوهري: الاعتماد على ApiService.currentUser بدلاً من Firebase ---
    final apiUser = ApiService.currentUser;

    if (apiUser != null) {
      print("🔵 HomeScreen: Loading from ApiService Memory...");
      if (mounted) {
        setState(() {
          _userName = apiUser['displayName'];
          _userRole = (apiUser['role'] ?? 'trainee')
              .toString()
              .toLowerCase()
              .trim();
          _photoUrl = apiUser['photoUrl'];
          _isLoading = false;
        });
        print("🟢 Role set to: $_userRole");
      }
    } else {
      // إذا لم يكن هناك مستخدم في الذاكرة (مثلاً عند إعادة تشغيل التطبيق بالكامل)
      // هنا يجب عادةً العودة لشاشة تسجيل الدخول أو استخدام التخزين المحلي
      print("🔴 HomeScreen: No user in memory. Redirecting to Login...");
      if (mounted) {
        Future.delayed(Duration.zero, () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        });
      }
    }
  }

  Widget _buildBody(AppLocalizations l10n) {
    // توجيه حسب الدور
    if (_userRole == 'owner' || _userRole == 'admin') {
      return const AdminDashboard();
    } else if (_userRole == 'trainer') {
      return TrainerDashboard(onLocaleChange: widget.setLocale);
    } else if (_userRole == 'trainee') {
      return DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(
                  text: l10n.trainings,
                  icon: const Icon(Icons.model_training),
                ),
                Tab(
                  text: l10n.competitions,
                  icon: const Icon(Icons.emoji_events),
                ),
                Tab(text: l10n.equipment, icon: const Icon(Icons.construction)),
                Tab(text: l10n.inventory, icon: const Icon(Icons.all_inbox)),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  TraineeDashboard(),
                  TraineeCompetitionsScreen(),
                  EquipmentCheckoutScreen(),
                  InventoryScreen(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.welcome, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 10),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text("Loading user data..."),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? l10n.loading : (_userName ?? l10n.home)),
        actions: [
          IconButton(
            tooltip: brightness == Brightness.dark ? 'وضع نهاري' : 'وضع ليلي',
            icon: Icon(
              brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () async {
              final newMode = brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              widget.setThemeMode?.call(newMode);
              await ThemeService.saveThemeMode(newMode);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(setLocale: widget.setLocale),
                  ),
                ).then((_) {
                  // إعادة تحميل البيانات عند العودة من البروفايل
                  // لكن بحذر لأننا نعتمد على الذاكرة
                  setState(() {
                    if (ApiService.currentUser != null) {
                      _userName = ApiService.currentUser!['displayName'];
                      _photoUrl = ApiService.currentUser!['photoUrl'];
                    }
                  });
                });
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(_photoUrl!)
                    : null,
                child: (_photoUrl == null || _photoUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          if (_userRole == 'trainee')
            IconButton(
              tooltip: l10n.myProgress,
              icon: const Icon(Icons.bar_chart),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyProgressScreen(),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(l10n),
    );
  }
}
