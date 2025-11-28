import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_dashboard.dart';
import 'package:drone_academy/screens/inventory_screen.dart';
import 'package:drone_academy/screens/my_progress_screen.dart';
import 'package:drone_academy/screens/profile_screen.dart';
import 'package:drone_academy/screens/trainee_competitions_screen.dart';
import 'package:drone_academy/screens/trainee_dashboard.dart';
import 'package:drone_academy/screens/trainer_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:drone_academy/services/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/screens/equipment_checkout_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Locale) setLocale;
  final void Function(ThemeMode)? setThemeMode;
  const HomeScreen({super.key, required this.setLocale, this.setThemeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ignore: unused_field
  String? _userName;
  String? _userRole; // القيمة الافتراضية ستعالج في الأسفل
  String? _photoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    debugPrint('🏠 [HOME] Start fetching user data...');
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      debugPrint('🏠 [HOME] Current User ID: ${user.uid}');
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          if (docSnapshot.exists) {
            debugPrint('🏠 [HOME] User Document FOUND.');
            final data = docSnapshot.data();
            setState(() {
              _userName = data?['displayName'];
              _userRole = data?['role'];
              _photoUrl = data?['photoUrl'];
              _isLoading = false; // إيقاف التحميل
            });
            debugPrint('🏠 [HOME] Role: $_userRole');
          } else {
            debugPrint('⚠️ [HOME] User Document NOT FOUND in Firestore!');
            // حالة خاصة: المستخدم مسجل دخول ولكن ليس لديه ملف بيانات
            // سنعطيه دور افتراضي (متدرب) لنسمح له بالدخول
            setState(() {
              _userRole = 'trainee';
              _userName = user.displayName ?? 'User';
              _isLoading = false; // إيقاف التحميل ضروري هنا!
            });
          }
        }
      } catch (e) {
        debugPrint("🔴 [HOME] Error fetching user data: $e");
        if (mounted) {
          setState(() {
            _isLoading = false; // إيقاف التحميل عند الخطأ
            _userRole = 'trainee'; // دور افتراضي عند الخطأ
          });
        }
      }
    } else {
      debugPrint('🔴 [HOME] User is null!');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBody(AppLocalizations l10n) {
    // دعم دور المالك (owner) بنفس توجيه لوحة الإدارة
    if (_userRole == 'owner' || _userRole == 'admin') {
      return const AdminDashboard();
    } else if (_userRole == 'trainer') {
      // --- تم الإصلاح هنا: تمرير دالة setLocale ---
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
      // حالة احتياطية إذا لم يتم تحديد الدور
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.welcome, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 10),
            const Text("Role not assigned or unknown."),
            ElevatedButton(
              onPressed: _fetchUserData,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? l10n.loading : l10n.home),
        actions: [
          // تبديل الثيم بسرعة من شريط العنوان
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
              // استدعاء الضبط المركزي لضمان تطبيق فوري على MaterialApp
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
                ).then((_) => _fetchUserData());
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(l10n),
    );
  }
}
