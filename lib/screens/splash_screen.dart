import 'dart:async';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  final void Function(Locale) setLocale;
  final void Function(ThemeMode)? setThemeMode; // دعم تغيير الثيم لاحقاً
  const SplashScreen({super.key, required this.setLocale, this.setThemeMode});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startUp();
  }

  Future<void> _startUp() async {
    // تحقق من Remote Config قبل المتابعة
    final allowProceed = await _checkRemoteConfig();
    if (!mounted || !allowProceed) return;

    // انتظار خفيف لإظهار الشعار
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AuthGate(
          setLocale: widget.setLocale,
          setThemeMode: widget.setThemeMode,
        ),
      ),
    );
  }

  Future<bool> _checkRemoteConfig() async {
    try {
      // 1) حاول جلب الإعدادات من Firestore أولاً (إن وجدت)
      bool? isActiveFs;
      String? minVersionFs;
      String? updateUrlFs;

      try {
        final doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('config')
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          isActiveFs = data['isAppActive'] as bool?;
          minVersionFs = data['forceUpdateVersion'] as String?;
          updateUrlFs = data['updateUrl'] as String?;
        }
      } catch (_) {
        // تجاهل أخطاء Firestore وتابع إلى Remote Config
      }

      // 2) ثم Remote Config كنسخة احتياطية أو تكملة
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults({
        'forceUpdateVersion': '1.0.0',
        'isAppActive': true,
        'updateUrl': '',
      });

      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );

      await rc.fetchAndActivate();

      final minVersion = minVersionFs ?? rc.getString('forceUpdateVersion');
      // دعم اسم مفتاح آخر تاريخياً لكن نعتمد Firestore إن وجد
      final isActive = isActiveFs ?? rc.getBool('isAppActive');
      final updateUrl = updateUrlFs ?? rc.getString('updateUrl');

      // حالة إيقاف التطبيق
      if (!isActive) {
        await _showMaintenanceDialog(updateUrl);
        return false; // لا نتابع
      }

      // حالة التحديث الإجباري
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      if (_compareVersions(currentVersion, minVersion) < 0) {
        await _showForceUpdateDialog(updateUrl, currentVersion, minVersion);
        return false; // لا نتابع حتى يتم تحديث التطبيق
      }

      return true;
    } catch (e) {
      // في حال الفشل، نسمح بالمتابعة ولا نمنع الدخول
      debugPrint('RemoteConfig check failed: $e');
      return true;
    }
  }

  int _compareVersions(String v1, String v2) {
    try {
      final a = v1.split('.').map(int.parse).toList();
      final b = v2.split('.').map(int.parse).toList();
      for (int i = 0; i < a.length && i < b.length; i++) {
        if (a[i] != b[i]) return a[i].compareTo(b[i]);
      }
      return a.length.compareTo(b.length);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _showMaintenanceDialog(String updateUrl) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('🚧 ${l10n.appTitle}'),
          content: const Text(
            'التطبيق تحت الصيانة حالياً. الرجاء المحاولة لاحقاً.',
          ),
          actions: [
            if (updateUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => _launchUpdateUrl(updateUrl),
                icon: const Icon(Icons.phone),
                label: const Text('اتصال'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showForceUpdateDialog(
    String updateUrl,
    String current,
    String min,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('يتطلب تحديثاً'),
          content: Text(
            'إصدارك الحالي $current أقدم من المطلوب $min. يرجى التحديث للمتابعة.',
          ),
          actions: [
            TextButton(
              onPressed: () => _launchUpdateUrl(updateUrl),
              child: const Text('تحديث'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchUpdateUrl(String raw) async {
    if (raw.isEmpty) return;
    final uri = _asUri(raw);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Uri _asUri(String raw) {
    final trimmed = raw.trim();
    // إذا كان رقم هاتف، استخدم tel:
    final isPhone = RegExp(r'^[+\d][\d\s-]+$').hasMatch(trimmed);
    if (isPhone) return Uri(scheme: 'tel', path: trimmed.replaceAll(' ', ''));
    // وإلا افترض أنه رابط http/https، وإن لم يبدأ ببروتوكول، أضف http
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    return Uri.parse('https://$trimmed');
  }

  @override
  Widget build(BuildContext context) {
    // نحصل على الترجمة هنا أيضاً
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2),
          builder: (context, double opacity, child) {
            return Opacity(opacity: opacity, child: child);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', height: 180),
              const SizedBox(height: 20),
              // استخدام النص المترجم لاسم التطبيق
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              if (widget.setThemeMode != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    _ThemeChoiceButton(
                      label: 'فاتح',
                      icon: Icons.light_mode,
                      onTap: () => widget.setThemeMode!(ThemeMode.light),
                    ),
                    _ThemeChoiceButton(
                      label: 'داكن',
                      icon: Icons.dark_mode,
                      onTap: () => widget.setThemeMode!(ThemeMode.dark),
                    ),
                    _ThemeChoiceButton(
                      label: 'حسب النظام',
                      icon: Icons.brightness_auto,
                      onTap: () => widget.setThemeMode!(ThemeMode.system),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ThemeChoiceButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.15),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
