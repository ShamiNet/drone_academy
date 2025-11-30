import 'dart:async';
import 'package:drone_academy/screens/auth_gate.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final void Function(Locale) setLocale;
  final void Function(ThemeMode) setThemeMode;

  const SplashScreen({
    super.key,
    required this.setLocale,
    required this.setThemeMode,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // المؤقت للانتقال التلقائي
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AuthGate(
              setLocale: widget.setLocale,
              setThemeMode: widget.setThemeMode, // تمرير دالة الثيم
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // الألوان المستوحاة من الصورة
    const backgroundColor = Color(0xFF111318); // لون الخلفية الداكن
    const primaryColor = Color(0xFFFF9800); // اللون البرتقالي

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // --- الشعار والدائرة ---
            Container(
              width: 180,
              height: 180,
              padding: const EdgeInsets.all(4), // سمك الحدود البرتقالية
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 3),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black, // خلفية سوداء داخل الدائرة
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // --- النص ---
            const Text(
              'أكاديمية الدرون',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
            const Spacer(),
            // --- أزرار التحكم بالثيم (مطابقة للصورة) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildThemeButton(
                    'فاتح',
                    Icons.wb_sunny_outlined,
                    ThemeMode.light,
                  ),
                  const SizedBox(width: 12),
                  _buildThemeButton(
                    'داكن',
                    Icons.nightlight_round,
                    ThemeMode.dark,
                  ),
                  const SizedBox(width: 12),
                  _buildThemeButton(
                    'حسب النظام',
                    Icons.brightness_auto,
                    ThemeMode.system,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ودجت لبناء أزرار الثيم الرمادية
  Widget _buildThemeButton(String label, IconData icon, ThemeMode mode) {
    return InkWell(
      onTap: () => widget.setThemeMode(mode),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C), // لون رمادي غامق للأزرار
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
