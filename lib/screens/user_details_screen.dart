import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/screens/profile_screen.dart';
import 'package:drone_academy/screens/trainee_profile_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const UserDetailsScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final currentUser = ApiService.currentUser;
    final String myRole = (currentUser?['role'] ?? 'trainee')
        .toString()
        .toLowerCase();
    final bool amIAdmin = myRole == 'owner' || myRole == 'admin';

    final isMe =
        (currentUser?['uid'] == userData['uid']) ||
        (currentUser?['id'] == userData['id']);
    final bool canViewFullDetails = amIAdmin || isMe;

    final String name = userData['displayName'] ?? 'Unknown';
    final String email = userData['email'] ?? 'No Email';
    final String role = userData['role'] ?? 'trainee';
    final String? photoUrl = userData['photoUrl'];
    final String bio = userData['bio'] ?? 'لا توجد نبذة.';

    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const primaryColor = Color(0xFFFF9800);
    const accentColor = Color(0xFF3F51B5);

    if (role == 'trainee') {
      return TraineeProfileScreen(traineeData: userData);
    }

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isMe)
            FadeInRight(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'تعديل',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(setLocale: (l) {}),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. الهيدر والصورة
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 240,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentColor, bgColor],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  child: FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 70,
                        backgroundColor: cardColor,
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                            ? CachedNetworkImageProvider(photoUrl)
                            : null,
                        child: (photoUrl == null)
                            ? const Icon(
                                Icons.person,
                                size: 70,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 70),

            // 2. الاسم والرتبة
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getRoleColor(role), width: 1),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        color: _getRoleColor(role),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 3. النبذة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.format_quote, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 4. التفاصيل الكاملة
            if (canViewFullDetails)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      "المعلومات المهنية",
                      Icons.work,
                      primaryColor,
                    ),
                    _buildInfoCard([
                      _InfoItem(
                        "الرقم العسكري",
                        userData['militaryNumber']?.toString(),
                        Icons.badge,
                      ),
                      _InfoItem(
                        "اللقب",
                        userData['nickname']?.toString(),
                        Icons.star,
                      ),
                      _InfoItem(
                        "الاختصاص",
                        userData['specialization']?.toString(),
                        Icons.engineering,
                      ),
                      _InfoItem(
                        "الصفة",
                        userData['attribute']?.toString(),
                        Icons.label,
                      ),
                      _InfoItem(
                        "العمل",
                        userData['job']?.toString(),
                        Icons.business,
                      ),
                      _InfoItem(
                        "المجموعة",
                        userData['groupName']?.toString(),
                        Icons.group,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      "معلومات شخصية",
                      Icons.person,
                      Colors.greenAccent,
                    ),
                    _buildInfoCard([
                      _InfoItem(
                        "العمر",
                        userData['age']?.toString(),
                        Icons.cake,
                      ),
                      _InfoItem(
                        "البلد",
                        userData['country']?.toString(),
                        Icons.public,
                      ),
                      _InfoItem(
                        "تاريخ الانضمام",
                        _formatDate(userData['createdAt']?.toString()),
                        Icons.calendar_month,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      "التواصل",
                      Icons.contact_phone,
                      Colors.blueAccent,
                    ),
                    _buildInfoCard([
                      _InfoItem(
                        "الرقم السوري",
                        userData['phoneSyria']?.toString(),
                        Icons.phone,
                      ),
                      _InfoItem(
                        "واتس اب",
                        userData['whatsapp']?.toString(),
                        Icons.chat,
                      ),
                      _InfoItem(
                        "تلغرام",
                        userData['telegram']?.toString(),
                        Icons.send,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      "إضافي",
                      Icons.folder_special,
                      Colors.purpleAccent,
                    ),
                    _buildInfoCard([
                      _InfoItem(
                        "التزكية",
                        userData['recommendation']?.toString(),
                        Icons.thumb_up,
                      ),
                    ]),

                    // --- قسم حظر الجهاز (للمدير فقط) ---
                    if (amIAdmin && userData['lastDeviceId'] != null) ...[
                      const SizedBox(height: 40),
                      _buildSectionTitle(
                        "أمان النظام",
                        Icons.security,
                        Colors.redAccent,
                      ),
                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C0E0E), // خلفية حمراء داكنة
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.phonelink_erase,
                              color: Colors.redAccent,
                            ),
                            title: const Text(
                              "حظر جهاز هذا المستخدم",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "ID: ${userData['lastDeviceId']}",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                            onTap: () => _showBanDeviceDialog(
                              context,
                              userData['lastDeviceId'],
                            ),
                            trailing: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.grey),
                      SizedBox(width: 10),
                      Text(
                        "باقي المعلومات خاصة",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFFFFD700);
      case 'admin':
        return const Color(0xFFFF5252);
      case 'trainer':
        return const Color(0xFF448AFF);
      default:
        return Colors.greenAccent;
    }
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return FadeInLeft(
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoItem> items) {
    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final item = entry.value;
            if (item.value == null || item.value!.isEmpty)
              return const SizedBox.shrink();

            return Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: Colors.white70, size: 20),
                  ),
                  title: Text(
                    item.label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  subtitle: Text(
                    item.value!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                ),
                if (entry.key != items.length - 1)
                  Divider(
                    color: Colors.white.withOpacity(0.05),
                    height: 1,
                    indent: 60,
                    endIndent: 16,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBanDeviceDialog(BuildContext context, String deviceId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: const Text(
          "حظر الجهاز نهائياً",
          style: TextStyle(color: Colors.red),
        ),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "سبب الحظر...",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ApiService().banDevice(deviceId, reasonController.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تم حظر الجهاز بنجاح")),
              );
            },
            child: const Text("حظر"),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy/MM/dd').format(date);
    } catch (e) {
      return dateString ?? '';
    }
  }
}

class _InfoItem {
  final String label;
  final String? value;
  final IconData icon;
  _InfoItem(this.label, this.value, this.icon);
}
