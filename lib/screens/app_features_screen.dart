import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

class AppFeaturesScreen extends StatelessWidget {
  const AppFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ألوان التصميم
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const primaryColor = Color(0xFFFF9800); // برتقالي
    const accentColor = Color(0xFF3F51B5); // أزرق

    // قائمة الميزات
    final List<Map<String, dynamic>> features = [
      {
        "title": "إدارة التدريبات المتقدمة",
        "desc":
            "نظام هرمي متكامل يسمح بإنشاء مستويات تدريبية متعددة، مع خطوات تفصيلية (قوائم تحقق أو فيديو) لضمان إتقان المتدرب لكل مهارة.",
        "icon": Icons.model_training,
        "color": Colors.blueAccent,
      },
      {
        "title": "نظام المسابقات والتنافس",
        "desc":
            "بيئة تنافسية حية تتيح إنشاء مسابقات، تسجيل التوقيت بدقة أجزاء الثانية، وعرض لوحة متصدرين (Leaderboard) فورية لتحفيز المتدربين.",
        "icon": Icons.emoji_events,
        "color": Colors.amber,
      },
      {
        "title": "الذكاء الاصطناعي (Gemini AI)",
        "desc":
            "محلل ذكي مدمج يقوم بقراءة ملاحظات المدربين وتحويلها إلى تقارير أداء دقيقة، موضحاً نقاط القوة والضعف والتوصيات بضغطة زر.",
        "icon": Icons.auto_awesome,
        "color": Colors.purpleAccent,
      },
      {
        "title": "إدارة الأسطول والمعدات",
        "desc":
            "سجل رقمي لكل قطعة (درون، بطارية، جهاز تحكم) يتيح تتبع حالتها (متاح، مستخدم، صيانة) ومعرفة من يحمل العهدة حالياً وتاريخ الاستخدام.",
        "icon": Icons.flight_takeoff,
        "color": Colors.tealAccent,
      },
      {
        "title": "الهيكل التنظيمي المرئي",
        "desc":
            "رسم بياني تفاعلي (Interactive Chart) يوضح شجرة القيادة والتبعية الإدارية للأقسام والمستخدمين، مع إمكانية التعديل بالسحب والإفلات.",
        "icon": Icons.account_tree,
        "color": Colors.greenAccent,
      },
      {
        "title": "التقارير والتوثيق",
        "desc":
            "نظام تصدير متطور يتيح إنشاء ملفات PDF احترافية لتقارير الأداء، بالإضافة إلى تصدير قاعدة البيانات كاملة لملفات Excel للأرشفة.",
        "icon": Icons.picture_as_pdf,
        "color": Colors.redAccent,
      },
      {
        "title": "نظام الصلاحيات والأمان",
        "desc":
            "بنية تحتية آمنة (Secure Backend) تمنح صلاحيات محددة لكل دور (مدير عام، مدير، مدرب، متدرب) لضمان خصوصية البيانات.",
        "icon": Icons.security,
        "color": Colors.cyanAccent,
      },
    ];

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "ميزات الأكاديمية",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // خلفية جمالية (تم التصحيح هنا)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.15),
                // التصحيح: استخدام BoxShadow بدلاً من blurRadius المباشر
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.15),
                // التصحيح: استخدام BoxShadow بدلاً من blurRadius المباشر
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // المحتوى
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
            itemCount: features.length + 1, // +1 للهيدر
            itemBuilder: (context, index) {
              if (index == 0) {
                return FadeInDown(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                      ), // تأكد من وجود الشعار
                      const SizedBox(height: 16),
                      const Text(
                        "نظام إدارة شامل",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(
                          "اكتشف القوة الكامنة في تطبيق أكاديمية الدرون وكيف يساعدك في تحقيق التميز التشغيلي.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              }

              final item = features[index - 1];
              return FadeInUp(
                delay: Duration(milliseconds: index * 100),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (item['color'] as Color).withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item['icon'],
                                color: item['color'],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                item['title'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item['desc'],
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
