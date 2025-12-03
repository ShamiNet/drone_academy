import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // يفضل إضافة هذه المكتبة لأيقونات احترافية، أو سأستخدم البدائل

class ContactDeveloperScreen extends StatelessWidget {
  const ContactDeveloperScreen({super.key});

  // الروابط
  final String _telegramUrl = "https://t.me/DevDrond";
  final String _whatsappUrl = "https://wa.me/963951727833";
  final String _email =
      "mailto:shami313p@gmail.com"; // بريد افتراضي (عدله إذا أردت)

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ألوان التصميم
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const primaryColor = Color(0xFFFF9800); // برتقالي
    const accentColor = Color(0xFF3F51B5); // أزرق

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
            // 1. الهيدر التعريفي (Header)
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentColor, const Color(0xFF000000)],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                  child: Center(
                    child: FadeInDown(
                      duration: const Duration(seconds: 1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // أيقونة المبرمج (أو صورتك)
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
                              radius: 50,
                              backgroundColor: cardColor,
                              child: Icon(
                                Icons.code,
                                size: 50,
                                color: Colors.white,
                              ), // يمكن استبدالها بصورتك
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "الشامي",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Text(
                            "Software Engineer & App Developer",
                            style: TextStyle(
                              fontSize: 14,
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

            const SizedBox(height: 40),

            // 2. بطاقات التواصل (Social Cards)
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
                        "تواصل معي مباشرة",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  _buildContactCard(
                    title: "Telegram",
                    subtitle: "@DevDrond",
                    icon: Icons.send, // أيقونة بديلة لتلغرام
                    color: const Color(0xFF0088CC),
                    onTap: () => _launchUrl(_telegramUrl),
                    delay: 300,
                  ),

                  _buildContactCard(
                    title: "WhatsApp",
                    subtitle: "+963 951 727 833",
                    icon: Icons.chat, // أيقونة بديلة للواتس
                    color: const Color(0xFF25D366),
                    onTap: () => _launchUrl(_whatsappUrl),
                    delay: 400,
                  ),

                  _buildContactCard(
                    title: "Email",
                    subtitle: "اضغط للمراسلة",
                    icon: Icons.email_outlined,
                    color: Colors.redAccent,
                    onTap: () => _launchUrl(_email),
                    delay: 500,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 3. قسم "عن المطور" (معلومات جميلة)
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.format_quote,
                      color: Colors.grey,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "نحول الأفكار المعقدة إلى تطبيقات ذكية وسلسة. هدفنا هو تمكين التكنولوجيا لخدمة المسلمين بأعلى معايير الجودة والأداء.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSkillChip("Flutter"),
                        const SizedBox(width: 8),
                        _buildSkillChip("Node.js"),
                        const SizedBox(width: 8),
                        _buildSkillChip("AI Integration"),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Footer
            const Text(
              "v1.0.0 • Made with ❤️",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
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
        margin: const EdgeInsets.only(bottom: 16),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(height: 4),
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
                    size: 16,
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
