import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:drone_academy/services/ai_analyzer_service.dart';
import 'package:drone_academy/utils/pdf_generator.dart' as pdf_gen;
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';

Future<void> generateAllTraineesReport(BuildContext context) async {
  final traineesSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'trainee')
      .get();

  if (context.mounted) {
    final selectedTraineeIds = await _showTraineeSelectionDialog(
      context,
      traineesSnapshot.docs,
    );

    if (selectedTraineeIds != null && selectedTraineeIds.isNotEmpty) {
      if (context.mounted) {
        await _showAiInclusionDialog(context, selectedTraineeIds);
      }
    }
  }
}

Future<List<String>?> _showTraineeSelectionDialog(
  BuildContext context,
  List<QueryDocumentSnapshot> trainees,
) async {
  final selectedIds = <String>{};
  final searchController = TextEditingController();
  final l10n = AppLocalizations.of(context)!;

  return showDialog<List<String>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final searchQuery = searchController.text.toLowerCase();
          final filteredTrainees = trainees.where((trainee) {
            final name = (trainee['displayName'] as String? ?? '')
                .toLowerCase();
            return name.contains(searchQuery);
          }).toList();

          return AlertDialog(
            title: Text(l10n.selectTrainee), // "Select Trainees for Report"
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: l10n.searchTrainee,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredTrainees.length,
                      itemBuilder: (context, index) {
                        final trainee = filteredTrainees[index];
                        final traineeId = trainee.id;
                        final isSelected = selectedIds.contains(traineeId);
                        return CheckboxListTile(
                          title: Text(trainee['displayName'] ?? 'Unknown'),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedIds.add(traineeId);
                              } else {
                                selectedIds.remove(traineeId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(selectedIds.toList()),
                child: Text(l10n.ok),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showAiInclusionDialog(
  BuildContext context,
  List<String> selectedTraineeIds,
) async {
  final l10n = AppLocalizations.of(context)!;
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(l10n.comprehensiveReport), // "Comprehensive Report"
        content: Text(
          l10n.includeAiAnalysis,
        ), // "Do you want to include AI analysis in the report?\n(This may take longer)"
        actions: <Widget>[
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () =>
                Navigator.of(context).pop(), // Just close the dialog
          ),
          TextButton(
            child: Text(l10n.withoutAiAnalysis), // "Without AI Analysis"
            onPressed: () {
              // إصلاح: إغلاق نافذة الاختيار الحالية أولاً
              Navigator.of(context).pop();
              // ثم بدء عملية إنشاء التقرير. سيتم استخدام الـ context الأصلي داخل الدالة
              _runReportGeneration(
                context,
                includeAiAnalysis: false,
                selectedTraineeIds: selectedTraineeIds,
              );
            },
          ),
          ElevatedButton(
            child: Text(l10n.withAiAnalysis), // "With AI Analysis"
            onPressed: () {
              // إصلاح: إغلاق نافذة الاختيار الحالية أولاً
              Navigator.of(context).pop();
              // ثم بدء عملية إنشاء التقرير
              _runReportGeneration(
                context,
                includeAiAnalysis: true,
                selectedTraineeIds: selectedTraineeIds,
              );
            },
          ),
        ],
      );
    },
  );
}

Future<void> _runReportGeneration(
  BuildContext context, {
  required bool includeAiAnalysis,
  required List<String> selectedTraineeIds,
}) async {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.generatingComprehensiveReport)),
          ],
        ),
      );
    },
  );

  try {
    // 1. جلب البيانات الأساسية بالتوازي
    final List<dynamic> initialData = await Future.wait([
      FirebaseFirestore.instance.collection('trainings').get(),
      FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: selectedTraineeIds)
          .get(),
      FirebaseFirestore.instance.collection('results').get(),
      FirebaseFirestore.instance.collection('daily_notes').get(),
    ]);

    final allTrainings = (initialData[0] as QuerySnapshot).docs;
    final traineeDocs = (initialData[1] as QuerySnapshot).docs;
    final allResults = (initialData[2] as QuerySnapshot).docs;
    final allNotes = (initialData[3] as QuerySnapshot).docs;

    // 2. تجميع النتائج والملاحظات حسب هوية المتدرب
    final resultsByTrainee = groupBy(allResults, (doc) => doc['traineeUid']);
    final notesByTrainee = groupBy(allNotes, (doc) => doc['traineeUid']);

    Map<String, String> aiSummaries = {};
    if (includeAiAnalysis) {
      final notesForAiAnalysis = <String, List<String>>{};
      for (var traineeDoc in traineeDocs) {
        final traineeId = traineeDoc.id;
        final notesList = (notesByTrainee[traineeId] ?? [])
            .map((doc) => doc['note'] as String)
            .toList();
        if (notesList.isNotEmpty) {
          notesForAiAnalysis[traineeId] = notesList;
        }
      }
      if (notesForAiAnalysis.isNotEmpty) {
        aiSummaries = await AiAnalyzerService.summarizeAllTraineesNotes(
          notesForAiAnalysis,
        );
      }
    }

    List<PdfReportData> allTraineesData = [];
    // طباعة بداية معالجة المتدربين
    print(
      'Starting to process ${traineeDocs.length} trainees for the report...',
    );

    for (int i = 0; i < traineeDocs.length; i++) {
      final traineeDoc = traineeDocs[i];
      final traineeId = traineeDoc.id;
      final traineeName = traineeDoc['displayName'] ?? 'Unknown';

      final resultsForTrainee = resultsByTrainee[traineeId] ?? [];
      final notesForTrainee = notesByTrainee[traineeId] ?? [];
      final aiSummary = aiSummaries[traineeId];

      // طباعة تقدم كل متدرب
      print(
        '(${i + 1}/${traineeDocs.length}) Processing data for: $traineeName',
      );

      double? averageMastery;
      if (resultsForTrainee.isNotEmpty) {
        double totalMastery = resultsForTrainee.fold(
          0,
          (sum, res) => sum + ((res['masteryPercentage'] as num?) ?? 0),
        );
        averageMastery = totalMastery / resultsForTrainee.length;
      }

      LevelProgress? levelProgress;
      final completedTrainingIds = resultsForTrainee
          .map((doc) => doc['trainingId'] as String)
          .toSet();

      int highestLevel = 0;
      if (completedTrainingIds.isNotEmpty) {
        final completedTrainingsDetails = allTrainings
            .where((t) => completedTrainingIds.contains(t.id))
            .toList();
        highestLevel = completedTrainingsDetails.fold<int>(
          0,
          (max, t) =>
              ((t['level'] as int? ?? 0) > max) ? (t['level'] as int) : max,
        );
      }

      if (highestLevel > 0) {
        final trainingsInLevel = allTrainings
            .where((t) => (t['level'] as int? ?? 0) == highestLevel)
            .toList();
        final totalInLevel = trainingsInLevel.length;
        int completedInLevel = trainingsInLevel
            .where((t) => completedTrainingIds.contains(t.id))
            .length;

        levelProgress = LevelProgress(
          level: highestLevel,
          completedTrainings: completedInLevel,
          totalTrainingsInLevel: totalInLevel,
        );
      }

      allTraineesData.add(
        PdfReportData(
          traineeName: traineeName,
          results: resultsForTrainee,
          notes: notesForTrainee,
          aiSummary: aiSummary,
          levelProgress: levelProgress,
          averageMastery: averageMastery,
        ),
      );
    }

    print('All trainee data processed. Generating PDF file...');

    if (context.mounted) {
      // إغلاق نافذة "جاري الإنشاء" قبل عرض نافذة الطباعة
      Navigator.of(context).pop();
      await pdf_gen.generateAllTraineesReport(allTraineesData);
      if (context.mounted) {
        print('Report generation process finished. Print layout displayed.');
      }
    }
  } catch (e) {
    print('An error occurred during report generation: $e');
    if (context.mounted) {
      Navigator.of(context).pop();
      showCustomSnackBar(context, '${l10n.reportGenerationFailed}: $e');
    }
  }
}
