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
  // التعديل: استخدام List<dynamic> لتقبل JSON
  final List<dynamic> results;
  final List<dynamic> notes;
  final String? aiSummary;
  final LevelProgress? levelProgress;
  final double? averageMastery;

  PdfReportData({
    required this.traineeName,
    required this.results,
    required this.notes,
    this.aiSummary,
    this.levelProgress,
    this.averageMastery,
  });
}
