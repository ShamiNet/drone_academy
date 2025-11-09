import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة حفظ واسترجاع وضع الثيم المختار من المستخدم
class ThemeService {
  static const _key = 'preferred_theme_mode';

  /// حفظ الوضع
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_key, value);
  }

  /// استرجاع الوضع المحفوظ
  static Future<ThemeMode?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }
}
