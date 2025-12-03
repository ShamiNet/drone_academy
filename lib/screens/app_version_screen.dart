import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

class AppVersionScreen extends StatelessWidget {
  const AppVersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ألوان التصميم
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const primaryColor = Color(0xFFFF9800);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "معلومات الإصدار",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. الشعار ورقم الإصدار
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardColor,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  // تأكد من وجود صورة الشعار في المسار الصحيح
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                    width: 80,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: const Text(
                  "Drone Academy",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),

              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withOpacity(0.5)),
                  ),
                  child: const Text(
                    "v1.0.0 (Stable)",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 2. سجل التغييرات (What's New)
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.new_releases,
                            color: primaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "ما الجديد في هذا الإصدار؟",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey, height: 20),
                      _buildChangeItem("إطلاق النسخة الأولى المتكاملة."),
                      _buildChangeItem("نظام إدارة ذكي للمتدربين والمدربين."),
                      _buildChangeItem(
                        "دعم الذكاء الاصطناعي (Gemini AI) للتحليل.",
                      ),
                      _buildChangeItem("لوحة تحكم إدارية شاملة."),
                      _buildChangeItem(
                        "تحسينات في الأداء والمظهر (Dark Mode).",
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. زر التحقق من التحديثات
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // محاكاة عملية التحقق
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("أنت تستخدم أحدث نسخة حالياً!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.system_update, color: Colors.black),
                    label: const Text(
                      "تحقق من وجود تحديثات",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // الحقوق
              FadeInUp(
                delay: const Duration(milliseconds: 800),
                child: const Text(
                  "© 2025 Drone Academy. All rights reserved.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // عنصر في القائمة
  Widget _buildChangeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
