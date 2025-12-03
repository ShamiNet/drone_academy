import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_app_control_panel.dart';
import 'package:drone_academy/screens/app_features_screen.dart';
import 'package:drone_academy/screens/app_version_screen.dart';
import 'package:drone_academy/screens/contact_developer_screen.dart';
import 'package:drone_academy/screens/org_chart_screen.dart';
import 'package:drone_academy/screens/privacy_policy_screen.dart';
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
        title: const Text('الإعدادات'),
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
            subtitle: 'عرض الهيكل المعتمد على المجموعات',
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
            subtitle: 'حظر وإلغاء حظر المستخدمين',
            icon: Icons.block,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserBlockingScreen()),
            ),
          ),
          _buildSettingItem(
            title: 'تصدير النسخة الاحتياطية',
            subtitle: 'تصدير بيانات التطبيق (JSON)',
            icon: Icons.cloud_download_outlined,
            onTap: () => _runBackup(context),
          ),
          _buildSettingItem(
            title: 'تقرير شامل',
            subtitle: 'إنشاء تقرير أداء لكل المتدربين (PDF)',
            icon: Icons.picture_as_pdf_outlined,
            onTap: () => generateAllTraineesReport(context),
          ),
          _buildSettingItem(
            title: 'التحكم في التطبيق',
            subtitle: 'إيقاف التشغيل، الصيانة، والتحديثات',
            icon: Icons.settings_applications_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: AdminAppControlPanel()),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // القسم الثالث: حول التطبيق (الجديد)
          _buildSectionHeader('حول التطبيق'),
          _buildSettingItem(
            title: 'رقم الإصدار',
            subtitle: 'v1.0.0 (Stable)',
            icon: Icons.info_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppVersionScreen()),
              );
            },
          ),
          _buildSettingItem(
            title: 'سياسة الخصوصية',
            subtitle: 'الشروط والأحكام وسياسة الاستخدام',
            icon: Icons.privacy_tip_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          _buildSettingItem(
            title: 'مميزات التطبيق',
            subtitle: 'تعرف على إمكانيات النظام الشاملة',
            icon: Icons.stars_outlined, // أيقونة نجوم
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppFeaturesScreen()),
              );
            },
          ),
          _buildSettingItem(
            title: 'تواصل مع المطور',
            subtitle: 'للإبلاغ عن مشكلة أو طلب ميزة',
            icon: Icons.support_agent,
            onTap: () {
              // الانتقال للشاشة الجديدة
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContactDeveloperScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 40),
          const Center(
            child: Text(
              "Drone Academy © 2025",
              style: TextStyle(color: Colors.grey, fontSize: 12),
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
          color: Color(0xFFFF9800), // لون برتقالي للعناوين
          fontSize: 14,
          fontWeight: FontWeight.bold,
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
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
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
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 14,
        ),
      ),
    );
  }
}
