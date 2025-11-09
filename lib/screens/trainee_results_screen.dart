import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class TraineeResultsScreen extends StatelessWidget {
  final Map<String, dynamic> traineeData;
  final String traineeId;

  const TraineeResultsScreen({
    super.key,
    required this.traineeData,
    required this.traineeId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name =
        traineeData['name'] as String? ??
        traineeData['email'] as String? ??
        traineeId;

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.results} - $name')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('results')
            .where('traineeUid', isEqualTo: traineeId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(l10n.noResultsRecorded));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final trainingTitle = data['trainingTitle'] as String? ?? '—';
              final score = data['score'];
              final mastery = data['mastery'];
              final dateTs = data['date'];
              DateTime? date;
              if (dateTs is Timestamp) date = dateTs.toDate();

              return Card(
                child: ListTile(
                  title: Text(trainingTitle),
                  subtitle: Text(
                    '${l10n.score}: ${score ?? '—'}  •  ${l10n.mastery}: ${mastery ?? '—'}\n${l10n.date}: ${date != null ? date.toLocal().toString().split('.').first : '—'}',
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
