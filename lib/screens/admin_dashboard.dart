import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/manage_equipment_screen.dart';
import 'package:drone_academy/screens/manage_inventory_screen.dart';
import 'package:drone_academy/screens/manage_users_screen.dart';
import 'package:drone_academy/screens/org_chart_screen.dart';
import 'package:drone_academy/screens/user_org_chart_screen.dart';
import 'package:drone_academy/services/export_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'report_generation_dialogs.dart';
import 'manage_competitions_tab.dart';
import 'manage_trainings_tab.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  // 2. دالة جديدة لتشغيل النسخ الاحتياطي
  void _runBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    showCustomSnackBar(context, l10n.exportStarting, isError: false);

    try {
      final result = await ExportService.exportDatabase();
      // إظهار رسالة النجاح أو الفشل
      if (context.mounted) {
        showCustomSnackBar(
          context,
          result,
          isError: !result.contains(l10n.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showCustomSnackBar(context, '${l10n.exportFailed}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminDashboard),
          actions: [
            // الزر الأول (القديم) للهيكل المعتمد على org_nodes
            IconButton(
              icon: const Icon(Icons.account_tree_outlined),
              tooltip: l10n.organizationalStructure,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrgChartScreen(),
                  ),
                );
              },
            ),
            // --- الزر الجديد المضاف هنا ---
            // الزر الثاني (الجديد) للهيكل المعتمد على users
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: l10n.usersOrgChart,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserOrgChartScreen(),
                  ),
                );
              },
            ), // --- 3. الزر الجديد للنسخ الاحتياطي ---
            IconButton(
              icon: const Icon(Icons.cloud_download_outlined),
              tooltip: l10n.exportBackup,
              onPressed: () => _runBackup(context),
            ),
            // زر التقرير الشامل
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: l10n.comprehensiveReport,
              onPressed: () => generateAllTraineesReport(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.trainings, icon: const Icon(Icons.model_training)),
              Tab(
                text: l10n.competitions,
                icon: const Icon(Icons.emoji_events),
              ),
              Tab(text: l10n.users, icon: const Icon(Icons.people)),
              Tab(text: l10n.equipment, icon: const Icon(Icons.construction)),
              Tab(text: l10n.inventory, icon: const Icon(Icons.all_inbox)),
            ],
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
      ),
    );
  }
}
