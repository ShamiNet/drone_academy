import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:drone_academy/services/ai_analyzer_service.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/pdf_generator.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

final ApiService _apiService = ApiService();

// --- 1. دالة البدء ---
Future<void> generateAllTraineesReport(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  print('═══════════════════════════════════════════════════════════');
  print('🔵 بدء عملية إنشاء التقرير الشامل');
  print('═══════════════════════════════════════════════════════════');

  try {
    print('📥 جاري جلب قائمة المتدربين...');
    final allUsers = await _apiService.getUsers();
    final trainees = allUsers.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      return role == 'trainee';
    }).toList();
    print('✅ تم جلب ${trainees.length} متدرب');

    if (context.mounted) {
      final selectedTraineeIds = await _showTraineeSelectionDialog(
        context,
        trainees,
      );

      if (selectedTraineeIds != null && selectedTraineeIds.isNotEmpty) {
        print('✅ تم تحديد ${selectedTraineeIds.length} متدرب للتقرير');
        if (context.mounted) {
          await _showReportOptionsDialog(context, selectedTraineeIds);
        }
      } else {
        print('⚠️ لم يتم تحديد أي متدرب');
      }
    }
  } catch (e) {
    print('❌ خطأ أثناء جلب بيانات المتدربين: $e');
    if (context.mounted) {
      showCustomSnackBar(context, '${l10n.failed}: $e');
    }
  }
}

// --- 2. نافذة اختيار المتدربين ---
Future<List<String>?> _showTraineeSelectionDialog(
  BuildContext context,
  List<dynamic> trainees,
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
                            for (var t in trainees) {
                              final uid = t['uid'] ?? t['id'];
                              if (uid != null) selectedIds.add(uid);
                            }
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
                        final uid = trainee['uid'] ?? trainee['id'];
                        final isSelected = selectedIds.contains(uid);
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
                                selectedIds.add(uid);
                              else
                                selectedIds.remove(uid);
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

// --- 3. نافذة الخيارات ---
Future<void> _showReportOptionsDialog(
  BuildContext context,
  List<String> selectedTraineeIds,
) async {
  final l10n = AppLocalizations.of(context)!;
  bool includeAi = false;
  bool showWatermark = true;
  String selectedLanguage = 'ar'; // اللغة الافتراضية

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
                // 🆕 اختيار اللغة
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3142),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8FA1B4).withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLanguage,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2A3142),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF8FA1B4),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ar',
                          child: Text('🇸🇦 العربية'),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text('🇬🇧 English'),
                        ),
                        DropdownMenuItem(
                          value: 'ru',
                          child: Text('🇷🇺 Русский'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedLanguage = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                child: const Text('إنشاء'),
                onPressed: () {
                  print(
                    '🎯 تم اختيار اللغة: $selectedLanguage (العربية=ar, الإنجليزية=en, الروسية=ru)',
                  );
                  print('🤖 تضمين الذكاء الاصطناعي: $includeAi');
                  print('💧 العلامة المائية: $showWatermark');
                  Navigator.of(dialogContext).pop();
                  _processAndShowSuccessDialog(
                    context,
                    selectedTraineeIds,
                    includeAiAnalysis: includeAi,
                    showWatermark: showWatermark,
                    selectedLanguage:
                        selectedLanguage, // 🆕 تمرير اللغة المختارة
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

// --- 4. المعالجة والإنشاء ---
Future<void> _processAndShowSuccessDialog(
  BuildContext context,
  List<String> selectedTraineeIds, {
  required bool includeAiAnalysis,
  required bool showWatermark,
  required String selectedLanguage, // 🆕 معامل جديد
}) async {
  final l10n = AppLocalizations.of(context)!;
  final currentUser = FirebaseAuth.instance.currentUser;
  final creatorName = currentUser?.displayName ?? 'Admin';

  print('═══════════════════════════════════════════════════════════');
  print('⚙️ بدء معالجة التقرير الشامل');
  print('   عدد المتدربين: ${selectedTraineeIds.length}');
  print('   اللغة: $selectedLanguage');
  print('   منشئ التقرير: $creatorName');
  print('═══════════════════════════════════════════════════════════');

  // حفظ BuildContext الصحيح قبل إغلاق أي dialogs
  // نستخدم rootNavigator للتأكد من أننا نعمل مع أعلى مستوى
  late NavigatorState navigator;
  late BuildContext safeContext;

  try {
    navigator = Navigator.of(context, rootNavigator: true);
    safeContext = context; // حفظ context قبل أي عملية async
    print('✅ تم الحصول على Navigator و context بنجاح');
  } catch (e) {
    print('⚠️ خطأ في الحصول على Navigator: $e');
    return;
  }

  print('🔍 عرض dialog التحميل...');
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) {
      print('🎬 بناء محتوى dialog التحميل');
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2230),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const CircularProgressIndicator(color: Color(0xFF8FA1B4)),
        ),
      );
    },
  );
  print('✅ تم عرض dialog التحميل');

  try {
    print('📊 جاري جلب البيانات الأساسية...');
    final initialData = await Future.wait([
      _apiService.getTrainings(),
      _apiService.getUsers(),
      _apiService.getResults(),
      _apiService.getDailyNotes(),
    ]).timeout(const Duration(seconds: 90));

    final allTrainings = initialData[0] as List<dynamic>;
    final allUsers = initialData[1] as List<dynamic>;
    final allResults = initialData[2] as List<dynamic>;
    final allNotes = initialData[3] as List<dynamic>;

    print('✅ تم جلب البيانات:');
    print('   📚 عدد التدريبات: ${allTrainings.length}');
    print('   👥 عدد المستخدمين: ${allUsers.length}');
    print('   📈 عدد النتائج: ${allResults.length}');
    print('   📝 عدد الملاحظات: ${allNotes.length}');

    final traineeDocs = allUsers.where((u) {
      final uid = u['uid'] ?? u['id'];
      return selectedTraineeIds.contains(uid);
    }).toList();

    final resultsByTrainee = groupBy(allResults, (doc) => doc['traineeUid']);
    final notesByTrainee = groupBy(allNotes, (doc) => doc['traineeUid']);

    Map<String, String> aiSummaries = {};
    if (includeAiAnalysis) {
      print('🤖 جاري تحليل الملاحظات بالذكاء الاصطناعي...');
      final notesForAiAnalysis = <String, List<String>>{};
      for (var trainee in traineeDocs) {
        final uid = trainee['uid'] ?? trainee['id'];
        final notes = notesByTrainee[uid] ?? [];
        final notesList = notes.map((doc) => doc['note'] as String).toList();
        if (notesList.isNotEmpty) {
          notesForAiAnalysis[uid] = notesList;
        }
      }
      print('   📌 عدد المتدربين لديهم ملاحظات: ${notesForAiAnalysis.length}');

      if (notesForAiAnalysis.isNotEmpty) {
        try {
          aiSummaries = await AiAnalyzerService.summarizeAllTraineesNotes(
            notesForAiAnalysis,
          ).timeout(const Duration(seconds: 60));
          print('✅ تم إنشاء ${aiSummaries.length} تلخيص ذكاء اصطناعي');
        } catch (e) {
          print('⚠️ خطأ في تحليل الذكاء الاصطناعي: $e');
        }
      }
    } else {
      print('⊘ تم تخطي تحليل الذكاء الاصطناعي');
    }

    print('📋 جاري معالجة بيانات المتدربين...');
    List<PdfReportData> allTraineesData = [];
    for (var i = 0; i < traineeDocs.length; i++) {
      final trainee = traineeDocs[i];
      final traineeId = trainee['uid'] ?? trainee['id'];
      final traineeName = trainee['displayName'] ?? 'Unknown';

      final myResults = resultsByTrainee[traineeId] ?? [];
      final myNotes = notesByTrainee[traineeId] ?? [];

      print('   🔄 معالجة متدرب ${i + 1}/${traineeDocs.length}: $traineeName');
      print('      ├─ النتائج: ${myResults.length}');
      print('      ├─ الملاحظات: ${myNotes.length}');
      print(
        '      └─ تحليل ذكاء اصطناعي: ${aiSummaries.containsKey(traineeId) ? '✅' : '❌'}',
      );

      myResults.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      final processedResults = myResults.map((doc) {
        final data = Map<String, dynamic>.from(doc);
        data['masteryPercentage'] ??= 0;
        data['trainingTitle'] ??= 'تدريب';
        return data;
      }).toList();

      final processedNotes = myNotes.map((doc) {
        return Map<String, dynamic>.from(doc);
      }).toList();

      double? averageMastery;
      if (processedResults.isNotEmpty) {
        double total = processedResults.fold(
          0,
          (sum, res) => sum + ((res['masteryPercentage'] as num?) ?? 0),
        );
        averageMastery = total / processedResults.length;
      }

      LevelProgress? levelProgress;
      if (allTrainings.isNotEmpty) {
        final completedTrainingIds = processedResults
            .map((doc) => doc['trainingId'] as String)
            .toSet();
        int highestLevel = 0;
        for (var training in allTrainings) {
          final tId = training['id'] ?? training['_id'];
          if (completedTrainingIds.contains(tId)) {
            final lvl = int.tryParse(training['level'].toString()) ?? 0;
            if (lvl > highestLevel) highestLevel = lvl;
          }
        }
        if (highestLevel > 0) {
          final trainingsInLevel = allTrainings
              .where(
                (t) =>
                    (int.tryParse(t['level'].toString()) ?? 0) == highestLevel,
              )
              .toList();
          int completedInLevel = trainingsInLevel.where((t) {
            final tId = t['id'] ?? t['_id'];
            return completedTrainingIds.contains(tId);
          }).length;
          levelProgress = LevelProgress(
            level: highestLevel,
            completedTrainings: completedInLevel,
            totalTrainingsInLevel: trainingsInLevel.length,
          );
        }
      }

      allTraineesData.add(
        PdfReportData(
          traineeName: traineeName,
          results: processedResults,
          notes: processedNotes,
          aiSummary: aiSummaries[traineeId],
          levelProgress: levelProgress,
          averageMastery: averageMastery,
        ),
      );
    }

    print('═══════════════════════════════════════════════════════════');
    print('📄 جاري إنشاء وثيقة PDF...');
    print('   🎨 الخط: ${selectedLanguage == 'ar' ? 'Cairo' : 'Roboto'}');
    print(
      '   ↔️ اتجاه النص: ${selectedLanguage == 'ar' ? 'من اليمين لليسار (RTL)' : 'من اليسار لليمين (LTR)'}',
    );
    print('   💧 العلامة المائية: ${showWatermark ? '✅' : '❌'}');

    // ✅ تمرير كود اللغة إلى مولد الـ PDF
    final pdfDoc = await createAllTraineesPdfDocument(
      allTraineesData,
      creatorName: creatorName,
      showWatermark: showWatermark,
      languageCode:
          selectedLanguage, // 🆕 استخدام اللغة المختارة بدلاً من locale
    );

    print('✅ تم إنشاء وثيقة PDF بنجاح');
    print('═══════════════════════════════════════════════════════════');

    // إغلاق dialog التحميل
    print('🔍 محاولة إغلاق dialog التحميل...');
    try {
      navigator.pop();
      print('✅ تم إغلاق dialog التحميل من خلال Navigator');
    } catch (e) {
      print('⚠️ خطأ في إغلاق dialog: $e');
    }

    // انتظار 500ms لضمان انغلاق الـ dialog تماماً
    print('⏳ انتظار 500ms لإنهاء عملية إغلاق dialog...');
    await Future.delayed(const Duration(milliseconds: 500));
    print('✅ انتهى الانتظار');

    // عرض نافذة النجاح باستخدام Future.delayed بدون اعتماد على context.mounted
    // لأن context قد يكون من dialog تم إغلاقه
    print('📞 جدولة عرض نافذة النجاح...');
    // ignore: unawaited_futures
    Future.delayed(Duration.zero).then((_) {
      print('🎯 محاولة عرض نافذة النجاح...');
      try {
        // نحاول أولاً مع safeContext
        if (safeContext.mounted) {
          print('✅ safeContext آمن - عرض النافذة');
          showReportReadyDialog(safeContext, pdfDoc);
        } else {
          print('⚠️ safeContext غير صالح - محاولة بديلة');
          // إذا فشل safeContext، نحاول عرض النافذة مباشرة من خلال Navigator
          // باستخدام Material route
          try {
            navigator.push(
              MaterialPageRoute(
                builder: (ctx) => _ReportReadyPage(pdfDoc: pdfDoc),
                fullscreenDialog: true,
              ),
            );
            print('✅ تم عرض نافذة النجاح عبر Navigator');
          } catch (e2) {
            print('❌ فشل عرض النافذة: $e2');
          }
        }
      } catch (e) {
        print('❌ خطأ في عرض نافذة النجاح: $e');
      }
    });
  } catch (e) {
    print('═══════════════════════════════════════════════════════════');
    print('❌ خطأ أثناء إنشاء التقرير: $e');
    print('═══════════════════════════════════════════════════════════');
    if (context.mounted) {
      navigator.pop();
      showCustomSnackBar(context, 'خطأ أثناء إنشاء التقرير: $e');
    }
  }
}

// ... (الدوال المتبقية showReportReadyDialog و savePdfToDownloads كما هي في النسخة السابقة) ...
void showReportReadyDialog(BuildContext context, pw.Document pdfDoc) {
  print('🎉 ==================== بدء عرض نافذة النجاح ====================');
  print('📱 استدعاء showDialog...');
  final l10n = AppLocalizations.of(context)!;
  try {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        print('🎨 بناء محتوى نافذة النجاح...');
        return Dialog(
          backgroundColor: const Color(0xFF1E2230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Printing.layoutPdf(
                        onLayout: (format) async => await pdfDoc.save(),
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: Text(l10n.previewAndPrint),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB3C5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    await savePdfToDownloads(context, pdfDoc);
                  },
                  icon: const Icon(Icons.download),
                  label: Text(l10n.saveToDownloads),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8FA1B4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    print('✅ تم استدعاء showDialog بنجاح - النافذة يجب أن تظهر الآن');
    print('🎉 ==================== نافذة النجاح معروضة ====================');
  } catch (e) {
    print('❌ خطأ في showReportReadyDialog: $e');
    print('📋 Stack trace: $e');
  }
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

// --- Page Widget لعرض نافذة النجاح (بديل آمن للـ showDialog) ---
class _ReportReadyPage extends StatelessWidget {
  final pw.Document pdfDoc;

  const _ReportReadyPage({required this.pdfDoc});

  @override
  Widget build(BuildContext context) {
    print('🎉 ==================== عرض صفحة نافذة النجاح ====================');
    final l10n = AppLocalizations.of(context)!;

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
              child: ElevatedButton.icon(
                onPressed: () async {
                  print('🖨️ استدعاء وظيفة الطباعة');
                  await Printing.layoutPdf(
                    onLayout: (format) async => await pdfDoc.save(),
                  );
                },
                icon: const Icon(Icons.print),
                label: Text(l10n.previewAndPrint),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB3C5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                print('💾 استدعاء وظيفة حفظ PDF');
                await savePdfToDownloads(context, pdfDoc);
              },
              icon: const Icon(Icons.download),
              label: Text(l10n.saveToDownloads),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8FA1B4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
