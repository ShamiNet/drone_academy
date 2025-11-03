import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  final DocumentSnapshot competition;

  const LeaderboardScreen({super.key, required this.competition});

  // دالة لتحويل المللي ثانية إلى تنسيق دقائق:ثواني:أجزاء من الثانية
  String _formatMilliseconds(int milliseconds) {
    final minutes = (milliseconds / 60000).floor().toString().padLeft(2, '0');
    final seconds = ((milliseconds % 60000) / 1000).floor().toString().padLeft(
      2,
      '0',
    );
    final ms = (milliseconds % 1000).toString().padLeft(3, '0');
    return '$minutes:$seconds:$ms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${competition['title']} - Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        // 1. جلب المشاركات الخاصة بهذه المسابقة فقط
        stream: FirebaseFirestore.instance
            .collection('competition_entries')
            .where('competitionId', isEqualTo: competition.id)
            .orderBy(
              'score',
              descending: false,
            ) // 2. ترتيب النتائج (الوقت الأقل هو الأفضل)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // --- بداية التعديل ---
            return const EmptyStateWidget(
              message: "No entries yet. Be the first!.\nCheck back later!",
              imagePath: 'assets/illustrations/no_data.svg',
            );
            // --- نهاية التعديل ---
          }

          final entries = snapshot.data!.docs;

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final rank = index + 1;

              // تحديد لون الميدالية حسب الترتيب
              Color medalColor = Colors.transparent;
              if (rank == 1) medalColor = Colors.amber;
              if (rank == 2) medalColor = Colors.grey.shade400;
              if (rank == 3) medalColor = Colors.brown.shade400;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: medalColor,
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: Text(entry['traineeName']),
                  trailing: Text(
                    _formatMilliseconds(entry['score']),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
