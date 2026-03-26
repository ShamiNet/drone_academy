// lib/main.dart

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/app_status_wrapper.dart';
import 'package:drone_academy/screens/splash_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/services/language_service.dart';
import 'package:drone_academy/services/notification_service.dart';
import 'package:drone_academy/services/offline_sync_service.dart';
import 'package:drone_academy/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toastification/toastification.dart';

// [تم الحذف] لا نحتاج استيراد هذا الملف إذا لم يكن موجوداً
// import 'firebase_options.dart';

// 📊 متغير عام لقياس الأداء
class PerformanceTracker {
  static final DateTime appStartTime = DateTime.now();

  static void logTime(String stage, {bool showFromStart = true}) {
    final now = DateTime.now();
    final elapsed = now.difference(appStartTime).inMilliseconds;
    final stageMs = elapsed > 0 ? elapsed : 0;

    debugPrint(
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      '⏱️  [$stage]\n'
      '   وقت المرحلة من البداية: ${stageMs}ms (${(stageMs / 1000).toStringAsFixed(2)}s)\n'
      '   الوقت الحالي: ${now.hour}:${now.minute}:${now.second}.${now.millisecond}\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    );
  }
}

void main() async {
  PerformanceTracker.logTime('APP_START');
  WidgetsFlutterBinding.ensureInitialized();

  // ⚡ تهيئة Firebase (حرجة - يجب أن تنتظر)
  try {
    await Firebase.initializeApp();
    PerformanceTracker.logTime('FIREBASE_INIT_DONE');
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // ⚡ تفعيل المداومة في Firestore (استخدام الكاش المحلي)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  PerformanceTracker.logTime('FIRESTORE_CACHE_ENABLED');

  // 🔔 تهيئة الإشعارات (بدء غير متزامن في الخلفية)
  // ملاحظة: لا ننتظر هنا لأنها قد تأخذ وقتاً وتؤخر بدء التطبيق
  NotificationService().initNotifications().ignore();
  PerformanceTracker.logTime('NOTIFICATIONS_INIT_STARTED');

  // --- معالجات الأخطاء ---

  // 1️⃣ التقاط أخطاء Flutter (الشاشة الحمراء)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ApiService().logAppError(
      error: details.exceptionAsString(),
      stackTrace: details.stack.toString(),
    );
  };

  // 2️⃣ التقاط الأخطاء غير المتزامنة
  PlatformDispatcher.instance.onError = (error, stack) {
    ApiService().logAppError(
      error: error.toString(),
      stackTrace: stack.toString(),
    );
    return true;
  };

  // --- بدء التطبيق ---
  PerformanceTracker.logTime('BEFORE_RUNAPP');
  runApp(const MyApp());
}

// تصدير نوع MyAppState ليُستخدم في language_selector
typedef MyAppState = _MyAppState;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system; // الوضع الافتراضي

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLanguage();
    OfflineSyncService.instance.syncPendingMutations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OfflineSyncService.instance.syncPendingMutations();
    }
  }

  // تحميل اللغة المحفوظة
  Future<void> _loadSavedLanguage() async {
    final savedLocale = await LanguageService.getSavedLocale();
    if (savedLocale != null && mounted) {
      setState(() {
        _locale = savedLocale;
      });
    }
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Drone Academy',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode, // استخدام المتغير
        locale: _locale,
        supportedLocales: const [Locale('en'), Locale('ar'), Locale('ru')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // تمرير دوال اللغة والثيم إلى السبلاش مع لف التطبيق بفاحص الإصدار
        home: AppStatusWrapper(
          child: SplashScreen(setLocale: setLocale, setThemeMode: setThemeMode),
        ),
      ),
    );
  }
}
