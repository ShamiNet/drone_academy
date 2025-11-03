import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/splash_screen.dart';
import 'package:drone_academy/services/notification_service.dart';
import 'package:drone_academy/theme/app_theme.dart'; // 1. استيراد ملف الثيم
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

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drone Academy',
      theme: AppTheme.lightTheme, // 2. تطبيق الثيم العادي
      darkTheme: AppTheme.darkTheme, // 3. تطبيق الثيم الليلي
      themeMode:
          ThemeMode.system, // 4. جعل التطبيق يتبع إعدادات الهاتف تلقائياً
      locale: _locale,
      supportedLocales: [Locale('en'), Locale('ar'), Locale('ru')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(setLocale: setLocale),
    );
  }
}
