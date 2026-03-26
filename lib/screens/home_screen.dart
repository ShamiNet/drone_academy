import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/main.dart';
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
  bool _hasInventoryAccess = false; // صلاحية الوصول للمخزون والمعدات

  // Cache for lazy-loaded trainee screens
  final Map<int, Widget> _traineeScreenCache = {};

  @override
  void initState() {
    super.initState();
    PerformanceTracker.logTime('HOME_SCREEN_INIT_START');
    // ✅ تفعيل مراقبة الحظر عند فتح الصفحة الرئيسية
    ApiService().startUserStatusMonitoring(context);
    _loadUserData();
  }

  @override
  void dispose() {
    // ✅ إيقاف المراقبة عند إغلاق التطبيق
    // (اختياري، لأن التطبيق سيغلق أصلاً، لكن جيد للنظافة البرمجية)
    ApiService().stopMonitoring();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    PerformanceTracker.logTime('LOAD_USER_DATA_START');

    var user = ApiService.currentUser;

    if (user == null) {
      PerformanceTracker.logTime('AUTO_LOGIN_ATTEMPTING');
      await _apiService.tryAutoLogin();
      PerformanceTracker.logTime('AUTO_LOGIN_DONE');
      user = ApiService.currentUser;
    }

    if (user != null) {
      PerformanceTracker.logTime('USER_FOUND_SETTING_STATE');
      if (mounted) {
        setState(() {
          _userName = user!['displayName'];
          _userRole = user!['role'];
          _photoUrl = user!['photoUrl'];
          _hasInventoryAccess = user!['hasInventoryAccess'] ?? false;
          _isLoading = false;
        });
      }

      final uid = user['uid'] ?? user['id'];
      try {
        PerformanceTracker.logTime('FETCH_FRESH_USER_START');
        final freshData = await _apiService.fetchUser(uid);
        PerformanceTracker.logTime('FETCH_FRESH_USER_DONE');

        if (freshData != null && mounted) {
          PerformanceTracker.logTime('UPDATE_UI_WITH_FRESH_DATA');
          setState(() {
            _userName = freshData['displayName'];
            _userRole = freshData['role'];
            _photoUrl = freshData['photoUrl'];
            _hasInventoryAccess = freshData['hasInventoryAccess'] ?? false;
          });

          ApiService.currentUser = freshData;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_user_data', json.encode(freshData));
          PerformanceTracker.logTime('CACHE_FRESH_DATA_DONE');
        }
      } catch (e) {
        debugPrint("Failed to refresh user data: $e");
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }

    PerformanceTracker.logTime('HOME_SCREEN_FULLY_LOADED');
  }

  // ⚡ Lazy load trainee screens and cache them
  Widget _getCachedScreen(int tabIndex) {
    if (!_traineeScreenCache.containsKey(tabIndex)) {
      late Widget screen;
      switch (tabIndex) {
        case 0:
          PerformanceTracker.logTime('LOADING_TAB_TRAININGS');
          screen = const TraineeDashboard();
          break;
        case 1:
          PerformanceTracker.logTime('LOADING_TAB_COMPETITIONS');
          screen = const TraineeCompetitionsScreen();
          break;
        case 2:
          PerformanceTracker.logTime('LOADING_TAB_EQUIPMENT');
          screen = const EquipmentCheckoutScreen();
          break;
        case 3:
          PerformanceTracker.logTime('LOADING_TAB_INVENTORY');
          screen = const InventoryScreen();
          break;
        default:
          screen = const SizedBox();
      }
      _traineeScreenCache[tabIndex] = screen;
    }

    return _traineeScreenCache[tabIndex]!;
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
      // بناء قائمة التبويبات بناءً على الصلاحيات
      List<Tab> tabs = [
        Tab(text: l10n.trainings, icon: const Icon(Icons.model_training)),
      ];
      List<Widget> tabViews = [
        _getCachedScreen(0), // trainings
      ];

      // إضافة المعدات والمخزون فقط إذا كان لدى المستخدم صلاحية
      if (_hasInventoryAccess) {
        tabs.addAll([
          Tab(text: l10n.equipment, icon: const Icon(Icons.construction)),
          Tab(text: l10n.inventory, icon: const Icon(Icons.all_inbox)),
        ]);
        tabViews.addAll([
          _getCachedScreen(2), // equipment
          _getCachedScreen(3), // inventory
        ]);
      }

      return DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            TabBar(tabs: tabs),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: tabViews,
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
