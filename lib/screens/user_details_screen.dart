import 'package:drone_academy/screens/trainee_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> userData; // Map
  const UserDetailsScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final String name = userData['displayName'] ?? 'No Name';
    final String email = userData['email'] ?? 'No Email';
    final String role = userData['role'] ?? 'trainee';
    final String? photoUrl = userData['photoUrl'];

    if (role == 'trainee') {
      return TraineeProfileScreen(traineeData: userData);
    }

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: (photoUrl == null)
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Chip(label: Text(role.toUpperCase())),
          ],
        ),
      ),
    );
  }
}
