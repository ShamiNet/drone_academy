import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:drone_academy/services/ai_analyzer_service.dart';
import 'package:drone_academy/utils/pdf_generator.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:firebase_auth/firebase_auth.dart'; // هام: لجلب اسم المستخدم
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

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
        // نظهر حوار الخيارات بدلاً من الحوار البسيط
        await _showReportOptionsDialog(context, selectedTraineeIds);
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
            backgroundColor: const Color(0xFF1E2230),
            title: Text(
              l10n.selectTrainee,
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: l10n.searchTrainee,
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        child: const Text("تحديد الكل"),
                        onPressed: () {
                          setDialogState(() {
                            selectedIds.clear();
                            for (var t in trainees) selectedIds.add(t.id);
                          });
                        },
                      ),
                      TextButton(
                        child: const Text("إلغاء الكل"),
                        onPressed: () {
                          setDialogState(() {
                            selectedIds.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredTrainees.length,
                      itemBuilder: (context, index) {
                        final trainee = filteredTrainees[index];
                        final isSelected = selectedIds.contains(trainee.id);
                        return CheckboxListTile(
                          title: Text(
                            trainee['displayName'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                          value: isSelected,
                          activeColor: const Color(0xFF8FA1B4),
                          checkColor: Colors.black,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true)
                                selectedIds.add(trainee.id);
                              else
                                selectedIds.remove(trainee.id);
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
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(selectedIds.toList()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8FA1B4),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
                child: Text(l10n.ok),
              ),
            ],
          );
        },
      );
    },
  );
}

// --- حوار الخيارات الجديد ---
Future<void> _showReportOptionsDialog(
  BuildContext context,
  List<String> selectedTraineeIds,
) async {
  final l10n = AppLocalizations.of(context)!;
  bool includeAi = false;
  bool showWatermark = true;

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E2230),
            title: const Text(
              'خيارات التقرير',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(
                    l10n.includeAiAnalysis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'قد يستغرق وقتاً أطول',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  value: includeAi,
                  activeColor: const Color(0xFF8FA1B4),
                  onChanged: (val) => setState(() => includeAi = val),
                ),
                SwitchListTile(
                  title: const Text(
                    'إظهار العلامة المائية',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: showWatermark,
                  activeColor: const Color(0xFF8FA1B4),
                  onChanged: (val) => setState(() => showWatermark = val),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: Colors.grey),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8FA1B4),
                  foregroundColor: Colors.black,
                ),
                child: const Text('إنشاء التقرير'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // نمرر كل الخيارات
                  _processAndShowSuccessDialog(
                    context,
                    selectedTraineeIds,
                    includeAiAnalysis: includeAi,
                    showWatermark: showWatermark,
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _processAndShowSuccessDialog(
  BuildContext context,
  List<String> selectedTraineeIds, {
  required bool includeAiAnalysis,
  required bool showWatermark, // معلمة جديدة
}) async {
  final l10n = AppLocalizations.of(context)!;
  final currentUser = FirebaseAuth.instance.currentUser;
  final creatorName = currentUser?.displayName ?? 'Admin'; // اسم المنشئ

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF8FA1B4)),
            const SizedBox(height: 15),
            Text(
              l10n.generatingComprehensiveReport,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );

  try {
    final initialData =
        await Future.wait([
          FirebaseFirestore.instance.collection('trainings').get(),
          FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: selectedTraineeIds)
              .get(),
          FirebaseFirestore.instance.collection('results').get(),
          FirebaseFirestore.instance.collection('daily_notes').get(),
        ]).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException("فشل الاتصال بقاعدة البيانات (بطء الشبكة).");
          },
        );

    final allTrainings = (initialData[0] as QuerySnapshot).docs;
    final traineeDocs = (initialData[1] as QuerySnapshot).docs;
    final allResults = (initialData[2] as QuerySnapshot).docs;
    final allNotes = (initialData[3] as QuerySnapshot).docs;

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
        try {
          aiSummaries = await AiAnalyzerService.summarizeAllTraineesNotes(
            notesForAiAnalysis,
          ).timeout(const Duration(seconds: 20));
        } catch (e) {
          // ignore error
        }
      }
    }

    List<PdfReportData> allTraineesData = [];
    for (var traineeDoc in traineeDocs) {
      final traineeId = traineeDoc.id;
      final traineeName = traineeDoc['displayName'] ?? 'Unknown';
      final resultsForTrainee = resultsByTrainee[traineeId] ?? [];
      final notesForTrainee = notesByTrainee[traineeId] ?? [];

      resultsForTrainee.sort(
        (a, b) => (b['date'] as Timestamp).compareTo(a['date'] as Timestamp),
      );

      double? averageMastery;
      if (resultsForTrainee.isNotEmpty) {
        double total = resultsForTrainee.fold(
          0,
          (sum, res) => sum + ((res['masteryPercentage'] as num?) ?? 0),
        );
        averageMastery = total / resultsForTrainee.length;
      }

      LevelProgress? levelProgress;
      final completedTrainingIds = resultsForTrainee
          .map((doc) => doc['trainingId'] as String)
          .toSet();
      int highestLevel = 0;
      for (var t in allTrainings) {
        if (completedTrainingIds.contains(t.id)) {
          final lvl = t['level'] as int? ?? 0;
          if (lvl > highestLevel) highestLevel = lvl;
        }
      }

      if (highestLevel > 0) {
        final trainingsInLevel = allTrainings
            .where((t) => (t['level'] as int? ?? 0) == highestLevel)
            .toList();
        int completedInLevel = trainingsInLevel
            .where((t) => completedTrainingIds.contains(t.id))
            .length;
        levelProgress = LevelProgress(
          level: highestLevel,
          completedTrainings: completedInLevel,
          totalTrainingsInLevel: trainingsInLevel.length,
        );
      }

      allTraineesData.add(
        PdfReportData(
          traineeName: traineeName,
          results: resultsForTrainee,
          notes: notesForTrainee,
          aiSummary: aiSummaries[traineeId],
          levelProgress: levelProgress,
          averageMastery: averageMastery,
        ),
      );
    }

    // --- هنا تم إصلاح الاستدعاء بتمرير الوسائط المفقودة ---
    final pdfDoc = await createAllTraineesPdfDocument(
      allTraineesData,
      creatorName: creatorName, // اسم المنشئ
      showWatermark: showWatermark, // خيار العلامة المائية
    );

    if (context.mounted) {
      Navigator.of(context).pop();
      showReportReadyDialog(context, pdfDoc);
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      showCustomSnackBar(context, '${l10n.failed}: $e');
    }
  }
}

void showReportReadyDialog(BuildContext context, pw.Document pdfDoc) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.reportReadyTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.reportReadyContent,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await Printing.layoutPdf(
                      onLayout: (format) async => await pdfDoc.save(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB3C5FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.previewAndPrint,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await savePdfToDownloads(context, pdfDoc);
                },
                child: Text(
                  l10n.saveToDownloads,
                  style: const TextStyle(
                    color: Color(0xFF8FA1B4),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> savePdfToDownloads(
  BuildContext context,
  pw.Document pdfDoc,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    var status = await Permission.storage.request();
    if (!status.isGranted)
      status = await Permission.manageExternalStorage.request();

    final directory = await getDownloadsDirectory();
    if (directory != null) {
      final fileName =
          'Drone_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      final bytes = await pdfDoc.save();
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        Navigator.pop(context);
        showCustomSnackBar(
          context,
          l10n.reportSavedSuccessfully,
          isError: false,
        );
      }
    }
  } catch (e) {
    if (context.mounted) showCustomSnackBar(context, '${l10n.failed}: $e');
  }
}
