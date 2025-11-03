import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CompetitionDetailsScreen extends StatelessWidget {
  final DocumentSnapshot competition;

  const CompetitionDetailsScreen({super.key, required this.competition});

  @override
  Widget build(BuildContext context) {
    final String title = competition['title'] ?? 'No Title';
    final String description = competition['description'] ?? 'No Description';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Challenge Details & Rules',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const Spacer(), // يدفع الأزرار للأسفل
            // --- بداية التعديل ---
            // يمكننا إضافة معلومات إضافية هنا للمتدرب
            const Center(
              child: Text(
                'Ask your trainer to start this challenge for you.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            // // زر عرض قائمة المتصدرين
            // OutlinedButton.icon(
            //   icon: const Icon(Icons.leaderboard),
            //   label: const Text('View Leaderboard'),
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) =>
            //             LeaderboardScreen(competition: competition),
            //       ),
            //     );
            //   },
            //   style: OutlinedButton.styleFrom(
            //     padding: const EdgeInsets.symmetric(vertical: 16),
            //   ),
            // ),
            // const SizedBox(height: 10), // مسافة بين الزرين
            // // زر بدء التحدي
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.pushReplacement(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) =>
            //             CompetitionTimerScreen(competition: competition),
            //       ),
            //     );
            //   },
            //   style: ElevatedButton.styleFrom(
            //     padding: const EdgeInsets.symmetric(vertical: 16),
            //     backgroundColor: Colors.green,
            //   ),
            //   child: const Text(
            //     'Start Challenge!',
            //     style: TextStyle(fontSize: 18, color: Colors.white),
            //   ),
            // ),
            // // --- نهاية التعديل ---
          ],
        ),
      ),
    );
  }
}
