import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/screens/trainee_profile_screen.dart'; // سنعيد استخدام بعض الأجزاء من هنا
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserDetailsScreen extends StatelessWidget {
  final DocumentSnapshot userDoc;
  const UserDetailsScreen({super.key, required this.userDoc});

  @override
  Widget build(BuildContext context) {
    final String name = userDoc['displayName'] ?? 'No Name';
    final String email = userDoc['email'] ?? 'No Email';
    final String role = userDoc['role'] ?? 'trainee';
    final String? photoUrl = userDoc['photoUrl'];

    // إذا كان المستخدم متدرباً، اعرض الواجهة الكاملة مع التبويبات
    if (role == 'trainee') {
      // نحن نمرر QueryDocumentSnapshot إلى TraineeProfileScreen
      // لذلك نحتاج لتحويل بسيط هنا أو تعديل TraineeProfileScreen
      // للتبسيط، سنبني واجهة مشابهة هنا مباشرة
      return TraineeProfileScreen(
        traineeData: userDoc as QueryDocumentSnapshot,
      );
    }

    // أما إذا كان مدرباً أو مديراً، فنعرض واجهة بسيطة
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  (photoUrl != null && photoUrl.isNotEmpty) // --- التعديل هنا
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Chip(
              label: Text(
                role.toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: role == 'admin' ? Colors.red : Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
