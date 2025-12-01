import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/competition_details_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class TraineeCompetitionsScreen extends StatefulWidget {
  const TraineeCompetitionsScreen({super.key});

  @override
  State<TraineeCompetitionsScreen> createState() =>
      _TraineeCompetitionsScreenState();
}

class _TraineeCompetitionsScreenState extends State<TraineeCompetitionsScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamCompetitions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final competitions = snapshot.data ?? [];
          if (competitions.isEmpty) {
            return Center(
              child: Text(
                l10n.noActiveCompetitions,
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: competitions.length,
            itemBuilder: (context, index) {
              final competition = competitions[index];
              return Card(
                color: const Color(0xFF1E2230),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 30,
                  ),
                  title: Text(
                    competition['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CompetitionDetailsScreen(competition: competition),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
