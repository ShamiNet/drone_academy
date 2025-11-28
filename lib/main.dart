import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/splash_screen.dart';
import 'package:drone_academy/screens/force_update_screen.dart';
import 'package:drone_academy/screens/banned_user_screen.dart';
import 'package:drone_academy/services/update_service.dart';
import 'package:drone_academy/services/ban_check_service.dart';
import 'package:drone_academy/services/notification_service.dart';
import 'package:drone_academy/theme/app_theme.dart'; // 1. استيراد ملف الثيم
import 'package:drone_academy/services/theme_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // 2. تفعيل خدمة الإشعارات
  await NotificationService().initNotifications();
  // --- 2. This is the only new line you need to add ---
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  // --- End of new line ---
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  bool _updateRequired = false;
  bool _userBanned = false;
  ThemeMode _themeMode = ThemeMode.system; // الوضع الحالي

  @override
  void initState() {
    super.initState();
    _checkUpdate();
    _checkBanStatus();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final saved = await ThemeService.loadThemeMode();
    if (saved != null && mounted) {
      setState(() => _themeMode = saved);
    }
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  void setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await ThemeService.saveThemeMode(mode);
  }

  Future<void> _checkUpdate() async {
    try {
      print('🚀 Starting update check in main.dart...');
      final updateService = UpdateService();
      final required = await updateService.isUpdateRequired();
      print('🎯 Update check result: $required');
      if (required && mounted) {
        print('⚠️ Setting _updateRequired to true');
        setState(() {
          _updateRequired = true;
        });
      } else {
        print('✅ No update required, continuing normally');
      }
    } catch (e) {
      print('❌ Error in _checkUpdate: $e');
      // Continue without forcing update if there's an error
    }
  }

  Future<void> _checkBanStatus() async {
    try {
      print('🚀 Starting ban status check in main.dart...');
      final banCheckService = BanCheckService();
      final banned = await banCheckService.isUserBanned();
      print('🎯 Ban check result: $banned');
      if (banned && mounted) {
        print('🚫 Setting _userBanned to true');
        setState(() {
          _userBanned = true;
        });
      } else {
        print('✅ User not banned, continuing normally');
      }
    } catch (e) {
      print('❌ Error in _checkBanStatus: $e');
      // Continue without blocking if there's an error
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drone Academy',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: [Locale('en'), Locale('ar'), Locale('ru')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _userBanned
          ? BannedUserScreen()
          : _updateRequired
          ? ForceUpdateScreen(
              storeUrl:
                  'https://play.google.com/store/apps/details?id=com.yourcompany.drone_academy',
              message:
                  'يجب عليك تحديث التطبيق للاستمرار في استخدام جميع الميزات. اضغط على زر التحديث للانتقال إلى المتجر.',
            )
          : SplashScreen(setLocale: setLocale, setThemeMode: setThemeMode),
    );
  }
}
