import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/app_control_screen.dart';
import 'package:drone_academy/screens/manage_banned_users_screen.dart';
import 'package:drone_academy/screens/org_chart_screen.dart';
import 'package:drone_academy/screens/user_org_chart_screen.dart';
import 'package:drone_academy/services/export_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'report_generation_dialogs.dart';

/// شاشة الإعدادات الموحدة للمدير / المالك
class AdminSettingsScreen extends StatelessWidget {
  final bool isOwner;
  const AdminSettingsScreen({super.key, required this.isOwner});

  Future<void> _runBackup(BuildContext context) async {
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
      if (context.mounted) {
        showCustomSnackBar(context, '${l10n.exportFailed}: $e');
      }
    }
  }

  Future<void> _shareBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    showCustomSnackBar(context, 'جارٍ توليد الملف...', isError: false);
    try {
      final bytes = await ExportService.generateBackupBytes();
      final fileName =
          'drone_academy_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final xfile = XFile.fromData(
        bytes,
        name: fileName,
        // بعض الأجهزة قد لا تعرض التطبيقات عند تحديد mime ضيق
        mimeType: '*/*',
      );
      await Share.shareXFiles([
        xfile,
      ], text: 'نسخة احتياطية من تطبيق Drone Academy');
      if (context.mounted) {
        showCustomSnackBar(context, l10n.success, isError: false);
      }
    } catch (e) {
      // إظهار السبب للمستخدم ثم تنفيذ حفظ احتياطي
      if (context.mounted) {
        showCustomSnackBar(context, 'فشل المشاركة: $e');
      }
      // Fallback: محاولة حفظ النسخة بدلاً من المشاركة
      try {
        final result = await ExportService.exportDatabase();
        if (context.mounted) {
          showCustomSnackBar(
            context,
            'تعذر المشاركة، تم الحفظ بدلاً من ذلك: $result',
          );
        }
      } catch (e2) {
        if (context.mounted) {
          showCustomSnackBar(context, 'فشل المشاركة والحفظ: $e2');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDashboard)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('الهيكل التنظيمي'),
          _settingsTile(
            context,
            icon: Icons.account_tree_outlined,
            title: l10n.organizationalStructure,
            subtitle: 'عرض الهيكل المعتمد على org_nodes',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrgChartScreen()),
            ),
          ),
          _settingsTile(
            context,
            icon: Icons.people_alt_outlined,
            title: l10n.usersOrgChart,
            subtitle: 'عرض هيكل المستخدمين حسب الأدوار',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserOrgChartScreen(),
              ),
            ),
          ),
          const Divider(height: 32),
          _sectionTitle('عمليات إدارية'),
          if (isOwner)
            _settingsTile(
              context,
              icon: Icons.block,
              title: 'إدارة حظر المستخدمين',
              subtitle: 'حظر وإلغاء حظر المستخدمين ومنعهم من الوصول',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageBannedUsersScreen(),
                ),
              ),
            ),
          if (isOwner)
            _settingsTile(
              context,
              icon: Icons.cloud_download_outlined,
              title: l10n.exportBackup,
              subtitle: 'تصدير نسخة احتياطية من البيانات',
              onTap: () => _runBackup(context),
            ),
          if (isOwner)
            _settingsTile(
              context,
              icon: Icons.share_outlined,
              title: 'مشاركة النسخة الاحتياطية',
              subtitle: 'إنشاء الملف ومشاركته مباشرة عبر التطبيقات',
              onTap: () => _shareBackup(context),
            ),
          if (isOwner)
            _settingsTile(
              context,
              icon: Icons.picture_as_pdf_outlined,
              title: l10n.comprehensiveReport,
              subtitle: 'إنشاء تقرير شامل لكل المتدربين',
              onTap: () => generateAllTraineesReport(context),
            ),
          if (isOwner)
            _settingsTile(
              context,
              icon: Icons.settings_applications,
              title: 'التحكم في التطبيق',
              subtitle: 'إيقاف وتشغيل التطبيق وإدارة الإصدار الأدنى',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppControlScreen(),
                ),
              ),
            ),
          if (!isOwner)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'بعض العناصر مخفية لأنك لست المالك (Owner).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue.shade700),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
