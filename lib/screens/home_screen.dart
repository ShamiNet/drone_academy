import 'dart:convert';
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
import 'package:drone_academy/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    var user = ApiService.currentUser;

    if (user == null) {
      await _apiService.tryAutoLogin();
      user = ApiService.currentUser;
    }

    if (user != null) {
      if (mounted) {
        setState(() {
          _userName = user!['displayName'];
          _userRole = user!['role'];
          _photoUrl = user!['photoUrl'];
          _isLoading = false;
        });
      }

      final uid = user['uid'] ?? user['id'];
      try {
        final freshData = await _apiService.fetchUser(uid);
        if (freshData != null && mounted) {
          setState(() {
            _userName = freshData['displayName'];
            _userRole = freshData['role'];
            _photoUrl = freshData['photoUrl'];
          });

          ApiService.currentUser = freshData;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_user_data', json.encode(freshData));
        }
      } catch (e) {
        print("Failed to refresh user data: $e");
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_userRole == 'owner' || _userRole == 'admin') {
      // [تصحيح] استخدام دالة فارغة كبديل في حال كانت القيمة null لمنع الانهيار
      return AdminDashboard(
        setThemeMode: widget.setThemeMode ?? (ThemeMode m) {},
      );
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
            const Text("Role unknown or loading..."),
            ElevatedButton(
              onPressed: _loadUserData,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;

    if (_isLoading) {
      return const LoadingView(message: "جاري تحضير ملفك الشخصي...");
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_userName ?? l10n.home),
        actions: [
          IconButton(
            icon: Icon(
              brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () async {
              final newMode = brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              // استخدام ?.call() آمن هنا
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
                ).then((_) => _loadUserData());
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: ClipOval(
                  child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: _photoUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.person, color: Colors.grey),
                          useOldImageOnUrlChange: true,
                        )
                      : const Icon(Icons.person, color: Colors.grey),
                ),
              ),
            ),
          ),
          if (_userRole == 'trainee')
            IconButton(
              tooltip: l10n.myProgress,
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyProgressScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }
}
