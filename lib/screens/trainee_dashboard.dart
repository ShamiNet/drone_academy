import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:drone_academy/widgets/training_card.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TraineeDashboard extends StatefulWidget {
  const TraineeDashboard({super.key});
  @override
  State<TraineeDashboard> createState() => _TraineeDashboardState();
}

class _TraineeDashboardState extends State<TraineeDashboard> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamTrainings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade800,
              highlightColor: Colors.grey.shade700,
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    height: 70.0,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
            );
          }

          final trainings = snapshot.data ?? [];
          if (trainings.isEmpty) {
            return EmptyStateWidget(
              message: l10n.noTrainingsAvailable,
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          final Map<int, List<dynamic>> trainingsByLevel = {};
          for (var training in trainings) {
            final level = training['level'] as int? ?? 1;
            if (trainingsByLevel[level] == null) {
              trainingsByLevel[level] = [];
            }
            trainingsByLevel[level]!.add(training);
          }
          final sortedLevels = trainingsByLevel.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: sortedLevels.length,
            itemBuilder: (context, index) {
              final level = sortedLevels[index];
              final levelTrainings = trainingsByLevel[level]!;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2230),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      '${l10n.level} $level',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF3F51B5),
                      child: Text(
                        '$level',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    collapsedIconColor: Colors.grey,
                    iconColor: const Color(0xFF8FA1B4),
                    initiallyExpanded: index == 0,
                    children: levelTrainings.map((training) {
                      return TrainingCard(training: training);
                    }).toList(),
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
