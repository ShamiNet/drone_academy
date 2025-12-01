import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatefulWidget {
  // يقبل Map بدلاً من DocumentSnapshot
  final Map<String, dynamic> competition;

  const LeaderboardScreen({super.key, required this.competition});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService _apiService = ApiService();

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
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('${widget.competition['title']} - Leaderboard'),
        backgroundColor: bgColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamCompetitionEntries(widget.competition['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return const EmptyStateWidget(
              message: "No entries yet. Be the first!\nCheck back later!",
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          // الترتيب يتم في السيرفر، لكن للتأكد نرتب محلياً أيضاً
          entries.sort(
            (a, b) => (a['score'] as int).compareTo(b['score'] as int),
          );

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final rank = index + 1;

              Color medalColor = const Color(0xFF2C2C2C); // لون افتراضي داكن
              Color textColor = Colors.white;

              if (rank == 1) {
                medalColor = Colors.amber;
                textColor = Colors.black;
              } else if (rank == 2) {
                medalColor = Colors.grey.shade400;
                textColor = Colors.black;
              } else if (rank == 3) {
                medalColor = const Color(0xFFA1887F); // برونزي
                textColor = Colors.black;
              }

              return Card(
                color: const Color(0xFF1E2230),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: medalColor,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  title: Text(
                    entry['traineeName'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Text(
                    _formatMilliseconds(entry['score'] ?? 0),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF8FA1B4),
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
