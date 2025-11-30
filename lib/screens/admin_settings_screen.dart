import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_app_control_panel.dart';
import 'package:drone_academy/screens/manage_users_screen.dart';
import 'package:drone_academy/screens/org_chart_screen.dart';
import 'package:drone_academy/screens/report_generation_dialogs.dart';
import 'package:drone_academy/screens/user_blocking_screen.dart';
import 'package:drone_academy/screens/user_org_chart_screen.dart';
import 'package:drone_academy/services/export_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  void _runBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    showCustomSnackBar(context, l10n.exportStarting, isError: false);
    try {
      final result = await ExportService.exportDatabase();
      if (context.mounted) {
        showCustomSnackBar(
          context,
          result,
          isError: !result.contains(l10n.success),
        );
      }
    } catch (e) {
      if (context.mounted)
        showCustomSnackBar(context, '${l10n.exportFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير'),
        backgroundColor: bgColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // القسم الأول: الهيكل التنظيمي
          _buildSectionHeader('الهيكل التنظيمي'),
          _buildSettingItem(
            title: 'الهيكل التنظيمي',
            subtitle: 'عرض الهيكل المعتمد على org_nodes',
            icon: Icons.account_tree_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrgChartScreen()),
            ),
          ),
          _buildSettingItem(
            title: 'الهيكل التنظيمي للمستخدمين',
            subtitle: 'عرض هيكل المستخدمين حسب الأدوار',
            icon: Icons.people_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserOrgChartScreen()),
            ),
          ),

          const SizedBox(height: 20),

          // القسم الثاني: عمليات إدارية
          _buildSectionHeader('عمليات إدارية'),
          _buildSettingItem(
            title: 'إدارة حظر المستخدمين',
            subtitle: 'حظر وإلغاء حظر المستخدمين ومنعهم من الوصول',
            icon: Icons.block,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserBlockingScreen()),
            ), // <-- التحديث هنا
          ),
          _buildSettingItem(
            title: 'تصدير النسخة الاحتياطية',
            subtitle: 'تصدير نسخة احتياطية من البيانات',
            icon: Icons.cloud_download_outlined,
            onTap: () => _runBackup(context),
          ),
          _buildSettingItem(
            title: 'مشاركة النسخة الاحتياطية',
            subtitle: 'إنشاء الملف ومشاركته مباشرة عبر التطبيقات',
            icon: Icons.share,
            onTap: () {
              /* منطق المشاركة */
            },
          ),
          _buildSettingItem(
            title: 'تقرير شامل',
            subtitle: 'إنشاء تقرير شامل لكل المتدربين',
            icon: Icons.picture_as_pdf_outlined,
            onTap: () => generateAllTraineesReport(context),
          ),
          _buildSettingItem(
            title: 'التحكم في التطبيق',
            subtitle: 'إيقاف وتشغيل التطبيق وإدارة الإصدار الأدنى',
            icon: Icons.settings_applications_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: AdminAppControlPanel()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230), // لون الكارد الداكن المائل للأزرق
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(
          Icons.arrow_back_ios,
          color: Colors.grey,
          size: 16,
        ), // السهم على اليسار (RTL)
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: CircleAvatar(
          backgroundColor: Colors.white,
          radius: 20,
          child: Icon(icon, color: const Color(0xFF0D47A1)),
        ),
      ),
    );
  }
}
