import 'dart:async';
import 'package:animate_do/animate_do.dart'; // تأكد أن المكتبة مضافة، أو يمكننا استخدام حركات Flutter العادية
import 'package:drone_academy/screens/app_status_wrapper.dart';
import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/login_screen.dart';
import 'package:drone_academy/services/api_service.dart';
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
  // قائمة معلومات ونصائح لعرضها
  final List<String> _droneTips = [
    "هل تعلم؟ أول طائرة بدون طيار استخدمت في عام 1917.",
    "نصيحة: تحقق دائماً من سرعة الرياح قبل الإقلاع.",
    "الأمان أولاً: لا تطر أبداً فوق التجمعات البشرية.",
    "معلومة: بطاريات الليثيوم تحتاج لعناية خاصة في التخزين.",
    "نصيحة: استخدم قاعدة الأثلاث للحصول على لقطات سينمائية.",
    "تذكير: حافظ دائماً على الطائرة في مجال رؤيتك.",
    "هل تعلم؟ الدرونات تستخدم الآن في الزراعة والإنقاذ.",
  ];

  int _currentTipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _startTipRotation(); // بدء تغيير النصائح
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _tipTimer?.cancel(); // إيقاف المؤقت عند الخروج
    super.dispose();
  }

  // دالة لتغيير النصيحة كل 2.5 ثانية
  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _droneTips.length;
        });
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    // وقت إضافي قليل للسماح للمستخدم بقراءة معلومة (اختياري)
    await Future.delayed(const Duration(seconds: 4));

    final isLoggedIn = await ApiService().tryAutoLogin();

    if (!mounted) return;

    if (isLoggedIn) {
      // الكود الجديد ✅
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppStatusWrapper(
            // نمرر الـ HomeScreen كـ child داخل الغلاف
            child: HomeScreen(
              setLocale: widget.setLocale,
              setThemeMode: widget.setThemeMode,
            ),
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // خلفية متدرجة جميلة
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // كحلي غامق
              Color(0xFF1E293B), // افتح قليلاً
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // 1. الشعار مع حركة نبض
            FadeInDown(
              duration: const Duration(seconds: 1),
              child: Container(
                width: 160,
                height: 160,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFFF9800), width: 2),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 2. اسم التطبيق
            FadeInUp(
              duration: const Duration(seconds: 1),
              child: const Text(
                'أكاديمية الدرون',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const Spacer(),

            // 3. منطقة المعلومات المتغيرة (AnimatedSwitcher)
            SizedBox(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  child: Text(
                    _droneTips[_currentTipIndex],
                    key: ValueKey<int>(_currentTipIndex), // مهم للحركة
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. مؤشر التحميل
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFFF9800),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "جاري تجهيز قمرة القيادة...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const Spacer(),

            // رقم الإصدار في الأسفل
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                "v1.0.2",
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
