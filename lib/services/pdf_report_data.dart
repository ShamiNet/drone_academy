import 'package:cloud_firestore/cloud_firestore.dart';

class LevelProgress {
  final int level;
  final int completedTrainings;
  final int totalTrainingsInLevel;

  LevelProgress({
    required this.level,
    required this.completedTrainings,
    required this.totalTrainingsInLevel,
  });

  int get remainingTrainings => totalTrainingsInLevel - completedTrainings;
}

class PdfReportData {
  final String traineeName;
  final List<QueryDocumentSnapshot> results;
  final List<QueryDocumentSnapshot> notes;
  final String? aiSummary;
  final LevelProgress? levelProgress;

  PdfReportData({
    required this.traineeName,
    required this.results,
    required this.notes,
    this.aiSummary,
    this.levelProgress,
  });
}
