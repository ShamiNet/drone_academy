import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ألوان التصميم
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const primaryColor = Color(0xFFFF9800); // برتقالي

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "سياسة الخصوصية",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. أيقونة الرأس
            Center(
              child: FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.privacy_tip_outlined,
                    size: 50,
                    color: primaryColor,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: FadeInUp(
                child: Text(
                  "آخر تحديث: 1 يناير 2025",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 2. بنود السياسة
            _buildSection(
              delay: 200,
              title: "1. مقدمة",
              content:
                  "نحن في أكاديمية الدرون نولي اهتماماً كبيراً لخصوصيتك وأمان بياناتك. توضح هذه السياسة كيف نقوم بجمع واستخدام وحماية معلوماتك الشخصية عند استخدام هذا التطبيق.",
            ),

            _buildSection(
              delay: 300,
              title: "2. البيانات التي نجمعها",
              content:
                  "لتقديم خدماتنا، قد نقوم بجمع المعلومات التالية:\n\n"
                  "• المعلومات الشخصية: الاسم، البريد الإلكتروني، رقم الهاتف، والرقم العسكري.\n"
                  "• بيانات الملف الشخصي: الصورة الشخصية، الرتبة، والاختصاص.\n"
                  "• بيانات الأداء: سجلات التدريب، نتائج المسابقات، وسجلات استعارة المعدات.",
            ),

            _buildSection(
              delay: 400,
              title: "3. كيف نستخدم بياناتك",
              content:
                  "نستخدم البيانات التي نجمعها للأغراض التالية:\n\n"
                  "• إدارة حسابك وتمكينك من الوصول للخدمات المخصصة.\n"
                  "• تتبع تقدمك في التدريبات وتقييم أدائك.\n"
                  "• إدارة مخزون المعدات وتنظيم عمليات الاستعارة.\n"
                  "• تحسين تجربة المستخدم وتطوير كفاءة التطبيق.",
            ),

            _buildSection(
              delay: 500,
              title: "4. مشاركة البيانات",
              content:
                  "نحن نلتزم بالحفاظ على سرية بياناتك. لا نقوم ببيع أو تأجير أو مشاركة معلوماتك الشخصية مع أي أطراف ثالثة لأغراض تجارية. قد تتم مشاركة البيانات فقط مع مزودي الخدمات التقنية الموثوقين (مثل خدمات الاستضافة السحابية) لضمان عمل التطبيق.",
            ),

            _buildSection(
              delay: 600,
              title: "5. أمان البيانات",
              content:
                  "نحن نتخذ كافة التدابير الأمنية التقنية والإدارية المعقولة لحماية بياناتك من الوصول غير المصرح به، أو التغيير، أو الكشف، أو الإتلاف.",
            ),

            _buildSection(
              delay: 700,
              title: "6. حقوقك",
              content:
                  "لديك الحق في الوصول إلى بياناتك الشخصية، وتصحيحها، أو طلب حذفها في أي وقت من خلال التواصل مع إدارة التطبيق.",
            ),

            _buildSection(
              delay: 800,
              title: "7. اتصل بنا",
              content:
                  "إذا كان لديك أي استفسارات أو مخاوف بخصوص سياسة الخصوصية هذه، يرجى عدم التردد في التواصل معنا عبر صفحة 'تواصل مع المطور' الموجودة في الإعدادات.",
            ),

            const SizedBox(height: 40),

            // Footer
            Center(
              child: FadeInUp(
                delay: const Duration(milliseconds: 900),
                child: const Text(
                  "Drone Academy © 2025",
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ودجت بناء القسم (Section)
  Widget _buildSection({
    required int delay,
    required String title,
    required String content,
  }) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo', // تأكد من تناسق الخط
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                height: 1.6, // تباعد الأسطر للقراءة المريحة
              ),
            ),
          ],
        ),
      ),
    );
  }
}
