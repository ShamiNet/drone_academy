import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_settings_screen.dart';
import 'package:drone_academy/screens/manage_equipment_screen.dart';
import 'package:drone_academy/screens/manage_inventory_screen.dart';
import 'package:drone_academy/screens/manage_users_screen.dart';
import 'package:drone_academy/services/role_service.dart';
import 'package:flutter/material.dart';
import 'manage_competitions_tab.dart';
import 'manage_trainings_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final RoleService _roleService = RoleService();
  // ملاحظة: وظائف النسخ الاحتياطي والتقارير نُقلت إلى صفحة الإعدادات.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<bool>(
      future: _roleService.isOwner(),
      builder: (context, snapshot) {
        final isOwner = snapshot.data ?? false;

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.adminDashboard),
              actions: [
                // زر إعدادات موحد يجمع الأيقونات السابقة
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'الإعدادات',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AdminSettingsScreen(isOwner: isOwner),
                      ),
                    );
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
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
                  Tab(text: l10n.inventory, icon: const Icon(Icons.all_inbox)),
                ],
              ),
            ),
            body: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: controller.animation!,
                  builder: (context, _) {
                    // استخدم IndexedStack لعرض التاب الحالي فقط بدون أي انتقالات
                    final currentIndex = controller.index;
                    return IndexedStack(
                      index: currentIndex,
                      children: const [
                        ManageTrainingsTab(),
                        ManageCompetitionsTab(),
                        ManageUsersScreen(),
                        ManageEquipmentScreen(),
                        ManageInventoryScreen(),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
