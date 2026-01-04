import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'app_language';

  // اللغات المدعومة
  static const List<Locale> supportedLocales = [
    Locale('ar'), // العربية
    Locale('en'), // الإنجليزية
    Locale('ru'), // الروسية
  ];

  // أسماء اللغات للعرض
  static const Map<String, String> languageNames = {
    'ar': 'العربية',
    'en': 'English',
    'ru': 'Русский',
  };

  // حفظ اللغة المختارة
  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  // جلب اللغة المحفوظة
  static Future<String?> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  // جلب اللغة كـ Locale
  static Future<Locale?> getSavedLocale() async {
    final languageCode = await getSavedLanguage();
    if (languageCode != null) {
      return Locale(languageCode);
    }
    return null;
  }

  // الحصول على اسم اللغة بالعربية
  static String getLanguageNameInArabic(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'الإنجليزية';
      case 'ru':
        return 'الروسية';
      default:
        return 'العربية';
    }
  }

  // الحصول على اسم اللغة بلغتها
  static String getLanguageNativeName(String languageCode) {
    return languageNames[languageCode] ?? 'العربية';
  }
}
