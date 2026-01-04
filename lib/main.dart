// lib/main.dart

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/splash_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/services/language_service.dart';
import 'package:drone_academy/services/notification_service.dart';
import 'package:drone_academy/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toastification/toastification.dart';

// [تم الحذف] لا نحتاج استيراد هذا الملف إذا لم يكن موجوداً
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [تعديل] تهيئة فايربيس بدون خيارات (سيعتمد على google-services.json)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase init error: $e");
  }

  // إعدادات فايرستور (اختياري، للكاش)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // تهيئة الإشعارات
  await NotificationService().initNotifications();

  // --- بداية كود التقاط الأخطاء ---

  // 1. التقاط أخطاء فلاتر (الشاشة الحمراء)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // عرض الخطأ في الكونسول
    ApiService().logAppError(
      error: details.exceptionAsString(),
      stackTrace: details.stack.toString(),
    );
  };

  // 2. التقاط الأخطاء البرمجية الخلفية (Async Errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    ApiService().logAppError(
      error: error.toString(),
      stackTrace: stack.toString(),
    );
    return true;
  };

  // --- نهاية كود التقاط الأخطاء ---

  runApp(const MyApp());
}

// تصدير نوع MyAppState ليُستخدم في language_selector
typedef MyAppState = _MyAppState;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system; // الوضع الافتراضي

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
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
        // تمرير دوال اللغة والثيم إلى السبلاش
        home: SplashScreen(setLocale: setLocale, setThemeMode: setThemeMode),
      ),
    );
  }
}
