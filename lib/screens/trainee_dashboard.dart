import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:drone_academy/widgets/training_card.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TraineeDashboard extends StatelessWidget {
  const TraineeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trainings')
          .orderBy('level')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  height: 70.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return EmptyStateWidget(
            message: l10n.noTrainingsAvailable,
            imagePath: 'assets/illustrations/no_data.svg',
          );
        }

        final trainings = snapshot.data!.docs;

        final Map<int, List<QueryDocumentSnapshot>> trainingsByLevel = {};
        for (var training in trainings) {
          final level = training['level'] as int? ?? 1;
          if (trainingsByLevel[level] == null) {
            trainingsByLevel[level] = [];
          }
          trainingsByLevel[level]!.add(training);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: trainingsByLevel.keys.length,
          itemBuilder: (context, index) {
            final level = trainingsByLevel.keys.elementAt(index);
            final levelTrainings = trainingsByLevel[level]!;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text(
                  '${l10n.level} $level',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                leading: CircleAvatar(child: Text('$level')),
                initiallyExpanded: index == 0,
                children: levelTrainings.map((training) {
                  return TrainingCard(training: training);
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}