import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// تأكد من وجود المكتبة في pubspec.yaml أو استخدم أيقونات Material البديلة كما فعلت في الكود
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactDeveloperScreen extends StatelessWidget {
  const ContactDeveloperScreen({super.key});

  // الروابط (تم التحديث)
  final String _telegramUrl = "https://t.me/DevDrond";
  // 👇 تم تحديث رابط الواتساب
  final String _whatsappUrl = "https://wa.me/message/EZ3U5DGNRP25M1";
  final String _email = "mailto:shami313p@gmail.com";

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const primaryColor = Color(0xFFFF9800);
    const accentColor = Color(0xFF3F51B5);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. الهيدر التعريفي
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentColor, const Color(0xFF000000)],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                  child: Center(
                    child: FadeInDown(
                      duration: const Duration(seconds: 1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 45,
                              backgroundColor: cardColor,
                              // ضع شعار التطبيق أو صورتك هنا
                              backgroundImage: AssetImage(
                                'assets/images/logo.png',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "الشامي",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Text(
                            "Software Engineer & App Developer",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 2. بطاقات التواصل
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInLeft(
                    delay: const Duration(milliseconds: 200),
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 16, right: 8),
                      child: Text(
                        "قنوات التواصل",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  _buildContactCard(
                    title: "WhatsApp",
                    subtitle: "اضغط للمراسلة المباشرة",
                    icon: Icons.chat,
                    color: const Color(0xFF25D366),
                    onTap: () => _launchUrl(_whatsappUrl),
                    delay: 300,
                  ),

                  _buildContactCard(
                    title: "Telegram",
                    subtitle: "@DevDrond",
                    icon: Icons.send,
                    color: const Color(0xFF0088CC),
                    onTap: () => _launchUrl(_telegramUrl),
                    delay: 400,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. قسم الباركود (QR Code) الجديد
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "أو امسح الباركود للتواصل السريع",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            Colors.white, // خلفية بيضاء للباركود ليكون واضحاً
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // 👇 هنا نضع صورة الباركود الخاصة بك
                      child: Image.asset(
                        'assets/images/contact_qr.jpg',
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 180,
                            height: 180,
                            child: Center(
                              child: Text(
                                "QR Code Image\nNot Found",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "امسح الرمز باستخدام كاميرا هاتفك",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Footer
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.hasData
                    ? 'v${snapshot.data!.version}'
                    : 'v...';
                return Text(
                  '$version • Made with ❤️ by Shami',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
