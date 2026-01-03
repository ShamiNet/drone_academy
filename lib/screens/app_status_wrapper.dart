import 'package:drone_academy/screens/maintenance_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppStatusWrapper extends StatefulWidget {
  // ✅ التعديل الأساسي: استقبال الـ child ليكون غلافاً لأي صفحة
  final Widget child;

  const AppStatusWrapper({super.key, required this.child});

  @override
  State<AppStatusWrapper> createState() => _AppStatusWrapperState();
}

class _AppStatusWrapperState extends State<AppStatusWrapper> {
  final ApiService _apiService = ApiService();

  // دالة مقارنة الإصدارات
  bool _isVersionSupported(String currentVersion, String minVersion) {
    if (minVersion.isEmpty) return true;
    try {
      List<int> current = currentVersion
          .split('.')
          .map((e) => int.parse(e))
          .toList();
      List<int> min = minVersion.split('.').map((e) => int.parse(e)).toList();

      for (int i = 0; i < 3; i++) {
        int c = i < current.length ? current[i] : 0;
        int m = i < min.length ? min[i] : 0;
        if (c < m) return false; // الإصدار الحالي أقل
        if (c > m) return true; // الإصدار الحالي أعلى
      }
    } catch (e) {
      return true; // في حال الخطأ في التنسيق، اسمح بالدخول
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _apiService.streamAppConfig(),
      builder: (context, snapshot) {
        // 1. شاشة التحميل أثناء جلب البيانات
        if (!snapshot.hasData) {
          return const LoadingView(message: "جاري التحقق من حالة النظام...");
        }

        final config = snapshot.data!;
        final bool isEnabled = config['isEnabled'] ?? true;

        // التحقق من وضع الصيانة
        if (!isEnabled) {
          return const MaintenanceScreen(
            title: "التطبيق في الصيانة",
            message: "نقوم حالياً بإجراء تحسينات على السيرفر. سنعود قريباً.",
          );
        }

        // 2. التحقق من رقم الإصدار (Force Update)
        return FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, pkgSnapshot) {
            if (!pkgSnapshot.hasData) {
              return const LoadingView(message: "التحقق من الإصدار...");
            }

            final currentVersion = pkgSnapshot.data!.version;
            final String minVersion = config['minVersion'] ?? '1.0.0';
            final String updateUrl = config['updateUrl'] ?? '';

            if (!_isVersionSupported(currentVersion, minVersion)) {
              // عرض شاشة التحديث الإجباري
              return _buildForceUpdateScreen(context, updateUrl);
            }

            // 3. كل شيء سليم، اعرض التطبيق (الطفل)
            return widget.child;
          },
        );
      },
    );
  }

  // تصميم شاشة التحديث الإجباري (داخلية لتجنب مشاكل MaintenanceScreen)
  Widget _buildForceUpdateScreen(BuildContext context, String url) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                "تحديث إجباري مطلوب",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "إصدارك الحالي قديم جداً. لضمان أفضل أداء وميزات جديدة، يرجى تحديث التطبيق الآن.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text("تحديث الآن"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (url.isNotEmpty) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
