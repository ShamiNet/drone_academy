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

  // دالة مقارنة الإصدارات - ترجع true إذا الإصدار مدعوم (>= minVersion)
  bool _isVersionSupported(String currentVersion, String minVersion) {
    if (minVersion.isEmpty) return true;

    try {
      // إزالة أي حرف 'v' من البداية
      final cleanCurrent = currentVersion.toLowerCase().replaceAll('v', '');
      final cleanMin = minVersion.toLowerCase().replaceAll('v', '');

      List<int> current = cleanCurrent
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      List<int> min = cleanMin
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      // التأكد من وجود 3 أجزاء على الأقل
      while (current.length < 3) current.add(0);
      while (min.length < 3) min.add(0);

      for (int i = 0; i < 3; i++) {
        int c = current[i];
        int m = min[i];

        if (c < m) {
          print(
            '🔴 [VERSION_CHECK] Current: $currentVersion < Min: $minVersion → BLOCKED',
          );
          return false; // الإصدار الحالي أقل من المطلوب → **ممنوع**
        }
        if (c > m) {
          print(
            '✅ [VERSION_CHECK] Current: $currentVersion > Min: $minVersion → ALLOWED',
          );
          return true; // الإصدار الحالي أعلى → مسموح
        }
      }

      print(
        '✅ [VERSION_CHECK] Current: $currentVersion = Min: $minVersion → ALLOWED',
      );
      return true; // الإصدارات متساوية → مسموح
    } catch (e) {
      print(
        '⚠️ [VERSION_CHECK] Error parsing versions: $e → ALLOWED (fallback)',
      );
      return true; // في حال الخطأ، اسمح بالدخول (لتجنب قفل المستخدمين)
    }
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

        // 📊 طباعة البيانات المستلمة من السيرفر
        print('📡 [APP_CONFIG_RECEIVED] ${config.toString()}');

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

            print(
              '🔍 [VERSION_COMPARISON] Current: $currentVersion | Min Required: $minVersion',
            );

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
