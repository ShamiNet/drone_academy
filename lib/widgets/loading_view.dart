import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

class LoadingView extends StatefulWidget {
  final String message;
  const LoadingView({super.key, this.message = "جاري تجهيز البيانات..."});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  // قائمة نصائح مفيدة للتسلية أثناء الانتظار
  final List<String> _tips = [
    "نصيحة: تحقق دائماً من حالة الطقس قبل الطيران.",
    "معلومة: البطاريات المشحونة بالكامل تضمن طيراناً آمناً.",
    "تذكير: حافظ على مسافة بصرية مباشرة مع طائرتك.",
    "هل تعلم؟ الدرونات تستخدم الآن في مسح الأراضي بدقة عالية.",
    "نصيحة: قم بمعايرة البوصلة (Compass) في كل موقع جديد.",
    "تذكير: لا تطر بالقرب من المطارات أو المناطق المحظورة.",
  ];

  int _currentTipIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // تغيير النصيحة كل 3 ثوانٍ
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318), // خلفية داكنة
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // الشعار مع حركة دوران خفيفة أو نبض
            FadeInDown(
              child: Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.3),
                  border: Border.all(color: const Color(0xFFFF9800), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // مؤشر التحميل
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFFF9800),
              ),
            ),

            const SizedBox(height: 20),

            // رسالة الحالة (المتغيرة حسب المكان)
            Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),

            const Spacer(),

            // منطقة النصائح المتغيرة
            SizedBox(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    _tips[_currentTipIndex],
                    key: ValueKey<int>(_currentTipIndex),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
