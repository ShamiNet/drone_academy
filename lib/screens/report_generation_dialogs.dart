// --- استيراد الحزم الأساسية ---
import 'dart:typed_data'; // مطلوب لتحميل الخطوط
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مطلوب لـ rootBundle

// --- استيراد حزم Firestore ومعالجة البيانات ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // مطلوب لـ groupBy

// --- استيراد حزم إنشاء الـ PDF والطباعة ---
import 'package:intl/intl.dart'; // مطلوب لتنسيق التاريخ
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // الاسم المستعار pw لـ widgets
import 'package:printing/printing.dart'; // مطلوب لمعاينة الطباعة وخطوط جوجل

// --- استيراد ملفات المشروع الداخلية ---
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:drone_academy/services/ai_analyzer_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';

//======================================================================
// القسم 1: دوال التنظيم والواجهات (من الكود الأول)
//======================================================================

/// الدالة الرئيسية لبدء عملية إنشاء التقرير
Future<void> generateAllTraineesReport(BuildContext context) async {
  print(
    '[PDF_TRACE] generateAllTraineesReport: بدء العملية.',
  ); // تتبع: بداية العملية
  // جلب لقطة للمتدربين من Firestore
  final traineesSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'trainee')
      .get();
  print(
    '[PDF_TRACE] generateAllTraineesReport: تم جلب المتدربين.',
  ); // تتبع: تم الجلب

  // التحقق مما إذا كان السياق (context) لا يزال ساريًا
  if (context.mounted) {
    // إظهار نافذة اختيار المتدرب
    print(
      '[PDF_TRACE] generateAllTraineesReport: إظهار نافذة اختيار المتدرب...',
    ); // تتبع
    final selectedTraineeIds = await _showTraineeSelectionDialog(
      context,
      traineesSnapshot.docs,
    );

    // إذا اختار المستخدم متدربين
    if (selectedTraineeIds != null && selectedTraineeIds.isNotEmpty) {
      print(
        '[PDF_TRACE] generateAllTraineesReport: اختار المستخدم ${selectedTraineeIds.length} متدرب.',
      ); // تتبع
      if (context.mounted) {
        // إظهار نافذة اختيار تضمين الذكاء الاصطناعي
        print(
          '[PDF_TRACE] generateAllTraineesReport: إظهار نافذة اختيار AI...',
        ); // تتبع
        await _showAiInclusionDialog(context, selectedTraineeIds);
      }
    } else {
      print(
        '[PDF_TRACE] generateAllTraineesReport: ألغى المستخدم اختيار المتدربين.',
      ); // تتبع
    }
  }
}

/// إظهار نافذة لاختيار المتدربين
Future<List<String>?> _showTraineeSelectionDialog(
  BuildContext context,
  List<QueryDocumentSnapshot> trainees,
) async {
  // مجموعة (Set) لتخزين المعرفات المختارة لضمان عدم التكرار
  final selectedIds = <String>{};
  // متحكم لحقل البحث
  final searchController = TextEditingController();
  // جلب نصوص التطبيق المترجمة (Localization)
  final l10n = AppLocalizations.of(context)!;

  return showDialog<List<String>>(
    context: context,
    builder: (context) {
      // استخدام StatefulBuilder لإدارة الحالة داخل النافذة المنبثقة
      return StatefulBuilder(
        builder: (context, setDialogState) {
          // الحصول على نص البحث وتحويله لأحرف صغيرة
          final searchQuery = searchController.text.toLowerCase();
          // تصفية قائمة المتدربين بناءً على نص البحث
          final filteredTrainees = trainees.where((trainee) {
            final name = (trainee['displayName'] as String? ?? '')
                .toLowerCase();
            return name.contains(searchQuery);
          }).toList();

          return AlertDialog(
            key: const Key('traineeSelectionDialog'),
            title: Text(l10n.selectTrainee), // "تحديد المتدربين للتقرير"
            content: SizedBox(
              width: double.maxFinite, // جعل النافذة تأخذ أقصى عرض متاح
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: l10n.searchTrainee, // "ابحث عن متدرب"
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    // عند تغيير النص، أعد بناء واجهة النافذة
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  // قائمة قابلة للتمرير للمتدربين
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredTrainees.length,
                      itemBuilder: (context, index) {
                        final trainee = filteredTrainees[index];
                        final traineeId = trainee.id;
                        final isSelected = selectedIds.contains(traineeId);
                        // عنصر قائمة مع مربع اختيار
                        return CheckboxListTile(
                          title: Text(
                            trainee['displayName'] ?? 'Unknown',
                          ), // اسم المتدرب
                          value: isSelected, // هل تم اختياره؟
                          onChanged: (bool? value) {
                            // تحديث الحالة عند الاختيار أو إلغاء الاختيار
                            setDialogState(() {
                              if (value == true) {
                                selectedIds.add(traineeId); // إضافة
                              } else {
                                selectedIds.remove(traineeId); // إزالة
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
              // زر إلغاء
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // إغلاق النافذة
                child: Text(l10n.cancel), // "إلغاء"
              ),
              // زر موافق
              ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(selectedIds.toList()), // إغلاق وإرجاع القائمة
                child: Text(l10n.ok), // "موافق"
              ),
            ],
          );
        },
      );
    },
  );
}

/// إظهار نافذة لسؤال المستخدم عن تضمين تحليل AI
Future<void> _showAiInclusionDialog(
  BuildContext originalContext, // <-- 1. تم تغيير الاسم إلى "السياق الأصلي"
  List<String> selectedTraineeIds,
) async {
  // 2. نستخدم السياق الأصلي لجلب الترجمة
  final l10n = AppLocalizations.of(originalContext)!;

  return showDialog<void>(
    context: originalContext, // <-- 3. نستخدم السياق الأصلي لإظهار النافذة
    builder: (BuildContext dialogContext) {
      // <-- 4. هذا هو "سياق النافذة" الجديد
      return AlertDialog(
        key: const Key('aiInclusionDialog'),
        title: Text(l10n.comprehensiveReport), // "تقرير شامل"
        content: Text(
          l10n.includeAiAnalysis,
        ), // "هل تريد تضمين تحليل الذكاء الاصطناعي..."
        actions: <Widget>[
          // زر إلغاء
          TextButton(
            child: Text(l10n.cancel), // "إلغاء"
            onPressed: () {
              print(
                '[PDF_TRACE] _showAiInclusionDialog: المستخدم اختار "إلغاء".',
              );
              // 5. نستخدم "سياق النافذة" لإغلاقها
              Navigator.of(dialogContext).pop();
            },
          ),
          // زر "بدون تحليل"
          TextButton(
            child: Text(
              l10n.withoutAiAnalysis,
            ), // "بدون تحليل الذكاء الاصطناعي"
            onPressed: () {
              print(
                '[PDF_TRACE] _showAiInclusionDialog: المستخدم اختار "بدون AI".',
              );
              // 5. نستخدم "سياق النافذة" لإغلاقها
              Navigator.of(dialogContext).pop();

              // 6. !!! الحل: نستدعي الدالة التالية بالسياق الأصلي (الصالح) !!!
              _runReportGeneration(
                originalContext,
                includeAiAnalysis: false,
                selectedTraineeIds: selectedTraineeIds,
              );
            },
          ),
          // زر "مع تحليل"
          ElevatedButton(
            child: Text(l10n.withAiAnalysis), // "مع تحليل الذكاء الاصطناعي"
            onPressed: () {
              print(
                '[PDF_TRACE] _showAiInclusionDialog: المستخدم اختار "مع AI".',
              );
              // 5. نستخدم "سياق النافذة" لإغلاقها
              Navigator.of(dialogContext).pop();

              // 6. !!! الحل: نستدعي الدالة التالية بالسياق الأصلي (الصالح) !!!
              _runReportGeneration(
                originalContext,
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

//======================================================================
// القسم 2: دالة جلب ومعالجة البيانات (من الكود الأول)
//======================================================================

/// الدالة الرئيسية التي تجلب البيانات وتعالجها
Future<void> _runReportGeneration(
  BuildContext context, {
  required bool includeAiAnalysis,
  required List<String> selectedTraineeIds,
}) async {
  print(
    '[PDF_TRACE] _runReportGeneration: بدأت دالة المعالجة الرئيسية.',
  ); // تتبع
  final l10n = AppLocalizations.of(context)!;
  // إظهار نافذة تحميل
  print(
    '[PDF_TRACE] _runReportGeneration: إظهار نافذة "جاري الإنشاء"...',
  ); // تتبع
  showDialog(
    context: context,
    barrierDismissible: false, // لا يمكن إغلاقها بالضغط خارجها
    builder: (BuildContext context) {
      return AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(), // مؤشر تحميل
            const SizedBox(width: 20),
            Expanded(
              child: Text(l10n.generatingComprehensiveReport),
            ), // "جاري إنشاء التقرير..."
          ],
        ),
      );
    },
  );

  try {
    // 1. جلب البيانات الأساسية بالتوازي (أسرع)
    print(
      '[PDF_TRACE] _runReportGeneration: بدء جلب البيانات (trainings, users, results, notes)...',
    ); // تتبع
    final initialData = await Future.wait([
      FirebaseFirestore.instance.collection('trainings').get(), // كل التدريبات
      FirebaseFirestore.instance
          .collection('users')
          .where(
            FieldPath.documentId,
            whereIn: selectedTraineeIds, // *** فقط المتدربون المختارون ***
          )
          .get(),
      FirebaseFirestore.instance.collection('results').get(), // كل النتائج
      FirebaseFirestore.instance
          .collection('daily_notes')
          .get(), // كل الملاحظات
    ]);
    print('[PDF_TRACE] _runReportGeneration: اكتمل جلب البيانات.'); // تتبع

    // استخراج البيانات من النتائج المتوازية
    final allTrainings = (initialData[0] as QuerySnapshot).docs;
    final traineeDocs = (initialData[1] as QuerySnapshot).docs;
    final allResults = (initialData[2] as QuerySnapshot).docs;
    final allNotes = (initialData[3] as QuerySnapshot).docs;
    print('[PDF_TRACE] _runReportGeneration: تم استخراج البيانات.'); // تتبع

    // 2. تجميع النتائج والملاحظات حسب هوية المتدرب (للبحث السريع)
    print(
      '[PDF_TRACE] _runReportGeneration: بدء تجميع النتائج والملاحظات...',
    ); // تتبع
    final resultsByTrainee = groupBy(allResults, (doc) => doc['traineeUid']);
    final notesByTrainee = groupBy(allNotes, (doc) => doc['traineeUid']);
    print('[PDF_TRACE] _runReportGeneration: اكتمل التجميع.'); // تتبع

    // 3. تحليل الذكاء الاصطناعي (إذا طُلب)
    Map<String, String> aiSummaries = {};
    if (includeAiAnalysis) {
      print(
        '[PDF_TRACE] _runReportGeneration: مطلوب تحليل AI. بدء تجميع ملاحظات AI...',
      ); // تتبع
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
        print(
          '[PDF_TRACE] _runReportGeneration: إرسال الملاحظات إلى خدمة AI...',
        ); // تتبع
        aiSummaries = await AiAnalyzerService.summarizeAllTraineesNotes(
          notesForAiAnalysis,
        );
        print('[PDF_TRACE] _runReportGeneration: تم استلام ملخصات AI.'); // تتبع
      } else {
        print(
          '[PDF_TRACE] _runReportGeneration: لا توجد ملاحظات لإرسالها إلى AI.',
        ); // تتبع
      }
    } else {
      print(
        '[PDF_TRACE] _runReportGeneration: تم تخطي تحليل AI (غير مطلوب).',
      ); // تتبع
    }

    // 4. بناء كائنات بيانات التقرير لكل متدرب
    List<PdfReportData> allTraineesData = [];
    // هذه الرسالة موجودة لديك بالفعل
    print(
      '[PDF_TRACE] Starting to process ${traineeDocs.length} trainees for the report...',
    );

    for (int i = 0; i < traineeDocs.length; i++) {
      final traineeDoc = traineeDocs[i];
      final traineeId = traineeDoc.id;
      final traineeName = traineeDoc['displayName'] ?? 'Unknown';

      // هذه الرسالة موجودة لديك بالفعل
      print(
        '[PDF_TRACE] (${i + 1}/${traineeDocs.length}) Processing data for: $traineeName',
      );

      final resultsForTrainee = resultsByTrainee[traineeId] ?? [];
      final notesForTrainee = notesByTrainee[traineeId] ?? [];
      final aiSummary = aiSummaries[traineeId];

      // حساب متوسط الإتقان
      double? averageMastery;
      if (resultsForTrainee.isNotEmpty) {
        double totalMastery = resultsForTrainee.fold(
          0,
          (sum, res) => sum + ((res['masteryPercentage'] as num?) ?? 0),
        );
        averageMastery = totalMastery / resultsForTrainee.length;
      }
      print('[PDF_TRACE] \t... حساب متوسط الإتقان: $averageMastery'); // تتبع

      // حساب تقدم المستوى
      LevelProgress? levelProgress;
      final completedTrainingIds = resultsForTrainee
          .map((doc) => doc['trainingId'] as String)
          .toSet();

      int highestLevel = 0;
      final completedTrainingsDetails = allTrainings
          .where((t) => completedTrainingIds.contains(t.id))
          .toList();
      highestLevel = completedTrainingsDetails.fold<int>(
        0,
        (max, t) =>
            ((t['level'] as int? ?? 0) > max) ? (t['level'] as int) : max,
      );

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
      print(
        '[PDF_TRACE] \t... حساب تقدم المستوى: ${levelProgress?.level ?? 'N/A'}',
      ); // تتبع

      // إضافة بيانات المتدرب الجاهزة للقائمة
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

    // هذه الرسالة موجودة لديك بالفعل
    print('[PDF_TRACE] All trainee data processed. Generating PDF file...');

    // 5. إنشاء الـ PDF وعرض النتيجة
    if (context.mounted) {
      print(
        '[PDF_TRACE] _runReportGeneration: إغلاق نافذة "جاري الإنشاء"...',
      ); // تتبع
      // إغلاق نافذة "جاري الإنشاء"
      Navigator.of(context).pop();
      // !!! --- بداية التعديل --- !!!
      // بدلاً من استدعاء دالة الطباعة مباشرة، نستدعي دالة الخيارات
      print(
        '[PDF_TRACE] _runReportGeneration: بدء استدعاء _handlePdfOutput...',
      );
      await _handlePdfOutput(context, allTraineesData, l10n);
      // تم نقل كل منطق الإخراج (الحفظ/الطباعة/رسائل النجاح) إلى داخل _handlePdfOutput
      // لذلك لا حاجة لأي كود إضافي هنا.
      print(
        '[PDF_TRACE] _runReportGeneration: اكتملت عملية إنشاء التقرير بنجاح.',
      );
    }
  } catch (e, s) {
    // إضافة 's' لرؤية StackTrace
    // 6. معالجة الأخطاء
    print(
      '[PDF_TRACE_ERROR] _runReportGeneration: حدث خطأ فادح: $e',
    ); // تتبع الخطأ
    print(
      '[PDF_TRACE_ERROR] _runReportGeneration: StackTrace: $s',
    ); // تتبع الخطأ
    if (context.mounted) {
      Navigator.of(context).pop();
      showCustomSnackBar(context, '${l10n.reportGenerationFailed}: $e');
    }
  }
}

//======================================================================
// القسم 3: دوال إنشاء وتصميم الـ PDF (نسخة مُحسّنة جمالياً)
//======================================================================

/// 1. الدالة التي تنظم الناتج: تنشئ الـ PDF وتُظهر نافذة الخيارات
Future<void> _handlePdfOutput(
  BuildContext context,
  List<PdfReportData> allTraineesData,
  AppLocalizations l10n, // نحتاج l10n لرسائل النجاح
) async {
  print('[PDF_TRACE] _handlePdfOutput: بدأت دالة معالجة الناتج.');

  // --- 1. بناء مستند الـ PDF ---
  final doc = pw.Document();

  // --- 1أ. تحميل الأصول (الخطوط، الأيقونات، الشعار) ---
  print('[PDF_TRACE] _handlePdfOutput: بدء تحميل الخطوط والصور...');

  // الخط الأساسي (تجوال عادي)
  final pw.Font ttf = await PdfGoogleFonts.tajawalRegular();
  // الخط العريض الأساسي (تجوال عريض)
  final pw.Font ttfBold = await PdfGoogleFonts.tajawalBold();

  // !!! --- هذا هو التعديل الجديد --- !!!
  // تحميل خط "الأميري العريض" خصيصاً لعنوان التدريب
  final pw.Font titleTrainingFont = await PdfGoogleFonts.amiriBold();

  // ما زلنا نحتاج الشعار من الأصول
  final logoData = await rootBundle.load('assets/images/academy_logo.png');
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

  // تحميل الأيقونات
  final iconFont = await PdfGoogleFonts.materialIcons();
  print('[PDF_TRACE] _handlePdfOutput: اكتمل تحميل الخطوط والصور.');

  // --- 1ب. تعريف الألوان المتناسقة ---
  final primaryColor = PdfColor.fromHex('#0D47A1'); // أزرق داكن
  final secondaryColor = PdfColor.fromHex(
    '#00796B',
  ); // أخضر/تيال للبطاقة الثانية
  final lightGreyColor = PdfColor.fromHex('#F4F4F4'); // خلفية الجداول والبطاقات
  final titleColor = PdfColor.fromHex('#002171'); // لون العناوين (أغمق)

  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  print('[PDF_TRACE] _handlePdfOutput: بدء إنشاء صفحات الـ PDF...');
  for (var traineeData in allTraineesData) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: ttf, // <-- استخدام الخط العادي (تجوال)
          bold: ttfBold, // <-- استخدام الخط العريض (تجوال)
          icons: iconFont,
        ),
        header: (pw.Context context) => _buildPdfHeader(
          now: now,
          traineeName: traineeData.traineeName,
          logoImage: logoImage,
          primaryColor: primaryColor,
        ),
        build: (pw.Context context) => _buildPdfBody(
          levelProgress: traineeData.levelProgress,
          aiSummary: traineeData.aiSummary,
          averageMastery: traineeData.averageMastery,
          results: traineeData.results,
          notes: traineeData.notes,
          titleColor: titleColor,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          lightGreyColor: lightGreyColor,
          // !!! --- تمرير الخط الجديد --- !!!
          titleTrainingFont: titleTrainingFont,
        ),
      ),
    );
  }
  print('[PDF_TRACE] _handlePdfOutput: اكتمل بناء الصفحات.');

  // --- 2. تحويل الـ PDF إلى بيانات (Bytes) ---
  print('[PDF_TRACE] _handlePdfOutput: بدء حفظ الـ PDF إلى bytes...');
  final Uint8List bytes = await doc.save();
  print('[PDF_TRACE] _handlePdfOutput: اكتمل حفظ الـ PDF إلى bytes.');

  // --- 3. إظهار نافذة الخيارات للمستخدم ---
  if (!context.mounted) return;
  print('[PDF_TRACE] _handlePdfOutput: إظهار نافذة الخيارات (حفظ / طباعة)...');
  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(l10n.reportReadyTitle), // "اكتمل إنشاء التقرير"
        content: Text(l10n.reportReadyContent), // "ماذا تريد أن تفعل؟"
        actions: [
          // زر الحفظ
          TextButton(
            child: Text(l10n.saveToDownloads), // "حفظ في التنزيلات"
            onPressed: () {
              Navigator.of(dialogContext).pop();
              print('[PDF_TRACE] _handlePdfOutput: المستخدم اختار "حفظ".');
              _savePdfToDownloads(context, bytes, l10n);
            },
          ),
          // زر المعاينة
          ElevatedButton(
            child: Text(l10n.previewAndPrint), // "معاينة وطباعة"
            onPressed: () {
              Navigator.of(dialogContext).pop();
              print('[PDF_TRACE] _handlePdfOutput: المستخدم اختار "معاينة".');
              _showPrintPreview(bytes, l10n);
            },
          ),
        ],
      );
    },
  );
}

/// 2. الدالة الخاصة بـ "الحفظ في التنزيلات" (كما هي)
Future<void> _savePdfToDownloads(
  BuildContext context,
  Uint8List bytes,
  AppLocalizations l10n,
) async {
  print(
    '[PDF_TRACE] _savePdfToDownloads: بدء عملية الحفظ المباشر (بدون طلب إذن)...',
  );
  try {
    // 2. إنشاء اسم فريد للملف
    final String fileName =
        'Trainee_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    // 3. استدعاء saveFile مباشرة
    String? path = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );

    // 4. التحقق مما إذا كان المسار صالحاً
    if (path != null) {
      print(
        '[PDF_TRACE] _savePdfToDownloads: اكتمل حفظ الملف بنجاح في المسار العام: $path',
      );
      if (context.mounted) {
        showCustomSnackBar(
          context,
          l10n.reportSavedSuccess, // "تم حفظ التقرير في مجلد التنزيلات"
          isError: false,
        );
      }
    } else {
      print(
        '[PDF_TRACE_ERROR] _savePdfToDownloads: فشل الحفظ (أرجعت الحزمة null).',
      );
      if (context.mounted) {
        showCustomSnackBar(context, l10n.reportGenerationFailed);
      }
    }
  } catch (e) {
    print('[PDF_TRACE_ERROR] _savePdfToDownloads: فشل حفظ الملف بسبب خطأ: $e');
    if (context.mounted) {
      showCustomSnackBar(context, "${l10n.reportGenerationFailed}: $e");
    }
  }
}

/// 3. الدالة الخاصة بـ "معاينة وطباعة" (كما هي)
Future<void> _showPrintPreview(Uint8List bytes, AppLocalizations l10n) async {
  print('[PDF_TRACE] _showPrintPreview: بدء استدعاء Printing.layoutPdf...');
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
  print('[PDF_TRACE] _showPrintPreview: اكتمل استدعاء Printing.layoutPdf.');
}

//======================================================================
// القسم 4: دوال بناء واجهة الـ PDF (مُعاد تصميمها)
//======================================================================

/// ودجت لبناء رأس الصفحة (Header) - تصميم جديد
pw.Widget _buildPdfHeader({
  required String now,
  required String traineeName,
  required pw.ImageProvider logoImage,
  required PdfColor primaryColor,
}) {
  return pw.Column(
    children: [
      // --- الصف العلوي: الشعار والتاريخ ---
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // التاريخ (على اليسار في RTL)
          pw.Text('تاريخ التقرير: $now'),
          // الشعار (على اليمين في RTL)
          pw.Container(height: 50, child: pw.Image(logoImage)),
        ],
      ),
      pw.SizedBox(height: 16),
      // --- شريط العنوان الملون ---
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: primaryColor,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'تقرير أداء المتدرب',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'المتدرب: $traineeName',
              style: const pw.TextStyle(fontSize: 18, color: PdfColors.white),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 24), // كان Divider
    ],
  );
}

/// ودجت مشترك لبناء محتوى الصفحة (Body) - تصميم جديد
List<pw.Widget> _buildPdfBody({
  required LevelProgress? levelProgress,
  required double? averageMastery,
  required String? aiSummary,
  required List<QueryDocumentSnapshot> results,
  required List<QueryDocumentSnapshot> notes,
  // الألوان والأيقونات
  required PdfColor titleColor,
  required PdfColor primaryColor,
  required PdfColor secondaryColor,
  required PdfColor lightGreyColor,
  // !!! --- هذا هو المتغير الجديد الذي يجب تمريره --- !!!
  required pw.Font titleTrainingFont,
}) {
  return [
    // --- القسم 1: بطاقات الإحصائيات ---
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        // بطاقة المستوى
        if (levelProgress != null)
          _buildStatCard(
            title: 'المستوى الحالي',
            value: '${levelProgress.level}',
            // استخدمنا رمز 'leaderboard' من Material Icons
            icon: const pw.IconData(0xe31b),
            color: primaryColor,
          ),
        // بطاقة متوسط الإتقان
        if (averageMastery != null)
          _buildStatCard(
            title: 'متوسط الإتقان العام',
            value: '${averageMastery.toStringAsFixed(1)}%',
            // استخدمنا رمز 'star'
            icon: const pw.IconData(0xe838),
            color: secondaryColor,
          ),
      ],
    ),
    pw.SizedBox(height: 16),

    // --- قسم إحصائيات المستوى (المتبقي والمكتمل) ---
    if (levelProgress != null) ...[
      // استخدام الدالة المساعدة لعنوان القسم
      _buildSectionTitle(
        title: 'إحصائيات المستوى الحالي (${levelProgress.level})',
        color: titleColor,
      ),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text('التدريبات المكتملة: ${levelProgress.completedTrainings}'),
          pw.Text('التدريبات المتبقية: ${levelProgress.remainingTrainings}'),
          pw.Text('الإجمالي: ${levelProgress.totalTrainingsInLevel}'),
        ],
      ),
      pw.SizedBox(height: 24),
    ],

    // --- قسم تحليل الذكاء الاصطناعي ---
    if (aiSummary != null && aiSummary.isNotEmpty) ...[
      _buildSectionTitle(title: 'تحليل الأداء (AI)', color: titleColor),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(5),
          color: lightGreyColor, // خلفية رمادية فاتحة
        ),
        child: pw.Text(
          aiSummary.replaceAll('**', ''), // إزالة علامات التنسيق
          style: const pw.TextStyle(lineSpacing: 2),
        ),
      ),
      pw.SizedBox(height: 24),
    ],

    // --- قسم النتائج (جدول ملون) ---
    _buildSectionTitle(title: 'سجل النتائج', color: titleColor),
    if (results.isNotEmpty)
      // استخدام pw.Table بدلاً من Table.fromTextArray للتحكم الكامل
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400),
        // تحديد عرض الأعمدة
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(3),
        },
        children: [
          // --- صف الرأس (Header) ---
          pw.TableRow(
            decoration: pw.BoxDecoration(color: lightGreyColor),
            children: ['التاريخ', 'نسبة الإتقان', 'عنوان التدريب'].map((
              header,
            ) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right,
                ),
              );
            }).toList(),
          ),
          // --- صفوف البيانات (مع تلوين متبادل) ---
          ...results.asMap().entries.map((entry) {
            final int index = entry.key;
            final result = entry.value;
            final bool isEven = index % 2 == 0;
            final date = (result['date'] as Timestamp).toDate();
            final formattedDate = DateFormat.yMMMd().format(date);

            // !!! --- هذا هو التعديل المطلوب --- !!!
            return pw.TableRow(
              // التلوين المتبادل (Zebra-striping)
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : lightGreyColor,
              ),
              // بناء الخلايا يدوياً لتطبيق التنسيق
              children: [
                // الخلية 1: التاريخ (تنسيق عادي)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(formattedDate, textAlign: pw.TextAlign.right),
                ),
                // الخلية 2: النسبة (تنسيق عادي)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    '${result['masteryPercentage']}%',
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                // الخلية 3: عنوان التدريب (تنسيق مميز بخط مختلف)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    result['trainingTitle'],
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: titleTrainingFont, // <-- استخدام الخط المخصص
                      color: primaryColor, // <-- اللون المختلف
                      // لا نحتاج "bold" لأن الخط هو "Amiri-Bold" أصلاً
                    ),
                  ),
                ),
              ],
            );
            // !!! --- نهاية التعديل --- !!!
          }),
        ],
      )
    else
      pw.Text('لا توجد نتائج مسجلة.'),
    pw.SizedBox(height: 24),

    // --- قسم الملاحظات اليومية (تصميم بطاقات) ---
    _buildSectionTitle(title: 'الملاحظات اليومية', color: titleColor),
    if (notes.isNotEmpty)
      ...notes.map((note) {
        final date = (note['date'] as Timestamp).toDate();
        final formattedDate = DateFormat.yMMMd().format(date);
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(5),
            color: PdfColors.white, // يمكنك تغييرها إلى lightGreyColor إذا أردت
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // صف التاريخ مع أيقونة
              pw.Row(
                children: [
                  // رمز 'calendar_today'
                  pw.Icon(
                    const pw.IconData(0xe8df),
                    size: 16,
                    color: PdfColors.grey700,
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    formattedDate,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              // نص الملاحظة
              pw.Text(note['note']),
            ],
          ),
        );
      }).toList()
    else
      pw.Text('لا توجد ملاحظات مسجلة.'),
  ];
}
//======================================================================
// القسم 5: دوال مساعدة جديدة للتصميم
//======================================================================

/// دالة مساعدة لبناء بطاقة إحصائيات (Stat Card)
pw.Widget _buildStatCard({
  required String title,
  required String value,
  required pw.IconData icon,
  required PdfColor color,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min, // لجعل البطاقة تحتضن المحتوى
      children: [
        // الأيقونة
        pw.Icon(icon, size: 28, color: PdfColors.white),
        pw.SizedBox(width: 12),
        // النص
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// دالة مساعدة لبناء عنوان قسم (Section Title)
pw.Widget _buildSectionTitle({required String title, required PdfColor color}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: color, // استخدام اللون الممرر
        ),
      ),
      pw.SizedBox(height: 4),
      // الخط السفلي الملون
      pw.Container(
        height: 3,
        width: 70, // عرض ثابت
        color: color.shade(0.3), // استخدام درجة أفتح من اللون
      ),
      pw.SizedBox(height: 16),
    ],
  );
}
