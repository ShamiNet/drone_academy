import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_settings_screen.dart';
import 'package:drone_academy/screens/manage_competitions_tab.dart';
import 'package:drone_academy/screens/manage_equipment_screen.dart';
import 'package:drone_academy/screens/manage_inventory_screen.dart';
import 'package:drone_academy/screens/manage_trainings_tab.dart'; // سنحتاج تعديل هذا الملف ليتناسب مع شكل المستويات
import 'package:drone_academy/screens/manage_users_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) setState(() => _photoUrl = doc.data()?['photoUrl']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // الألوان الداكنة كما في الصور
    const bgColor = Color(0xFF111318);
    const appBarColor = Color(0xFF111318);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'الرئيسية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          // --- اليمين (RTL Leading): الصورة الشخصية ---
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(_photoUrl!)
                  : null,
              child: (_photoUrl == null)
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
          ),
          // --- اليسار (RTL Actions): زر الوضع وأيقونة الإعدادات ---
          actions: [
            IconButton(
              icon: const Icon(
                Icons.wb_sunny_outlined,
                size: 20,
              ), // أيقونة الشمس الصغيرة
              onPressed: () {
                /* منطق تبديل الثيم */
              },
            ),
          ],
          // --- الجزء السفلي من الـ AppBar: العنوان الفرعي والتبويبات ---
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(
              100,
            ), // مساحة للعنوان والتبويبات
            child: Column(
              children: [
                // زر الإعدادات الكبير (الترس) مع العنوان "لوحة تحكم المدير"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.settings,
                          color: Color(0xFF8FA1B4),
                        ),
                        onPressed: () {
                          // الانتقال لصفحة الإعدادات (الصورة 3)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Expanded(
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
                      const SizedBox(
                        width: 48,
                      ), // مساحة فارغة للتوازن مع زر الإعدادات
                    ],
                  ),
                ),
                // التبويبات (أيقونات ونص)
                TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFF8FA1B4),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF8FA1B4),
                  tabs: [
                    Tab(
                      text: l10n.trainings,
                      icon: const Icon(Icons.model_training),
                    ), // التدريبات
                    Tab(
                      text: l10n.competitions,
                      icon: const Icon(Icons.emoji_events),
                    ), // المسابقات
                    Tab(
                      text: l10n.users,
                      icon: const Icon(Icons.people),
                    ), // المستخدمون
                    Tab(
                      text: l10n.equipment,
                      icon: const Icon(Icons.construction),
                    ), // المعدات
                    Tab(
                      text: l10n.inventory,
                      icon: const Icon(Icons.inventory_2),
                    ), // المخزون
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ManageTrainingsTab(), // تحتاج تحديث لتظهر المستويات كقوائم
            ManageCompetitionsTab(),
            ManageUsersScreen(),
            ManageEquipmentScreen(),
            ManageInventoryScreen(),
          ],
        ),

        floatingActionButtonLocation:
            FloatingActionButtonLocation.startFloat, // أقصى اليسار في RTL
      ),
    );
  }
}
