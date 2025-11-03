import 'package:flutter/material.dart';

// تعريف الألوان الأساسية لسهولة استخدامها
const Color primaryColor = Color(0xFF0D47A1); // أزرق داكن
const Color accentColor = Color(0xFFFFA000); // برتقالي مميز
const Color lightBackgroundColor = Color(0xFFF5F5F5); // رمادي فاتح للخلفية
const Color darkBackgroundColor = Color(0xFF121212); // أسود داكن للوضع الليلي

class AppTheme {
  // الثيم الخاص بالوضع العادي (Light Mode)
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackgroundColor,
    fontFamily: 'Cairo', // تطبيق الخط على كل التطبيق
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white, // لون النصوص والأيقونات في الشريط العلوي
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white, // لون النص داخل الزر
      ),
    ),
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.blue,
    ).copyWith(secondary: accentColor),
  );

  // الثيم الخاص بالوضع الليلي (Dark Mode)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackgroundColor,
    fontFamily: 'Cairo',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black, // شريط علوي أسود في الوضع الليلي
      foregroundColor: Colors.white,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor, // أزرار برتقالية في الوضع الليلي
        foregroundColor: Colors.black,
      ),
    ),
    colorScheme: ColorScheme.fromSwatch(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
    ).copyWith(secondary: accentColor),
  );
}
