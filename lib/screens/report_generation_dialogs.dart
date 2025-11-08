// --- استيراد الحزم الأساسية ---
import 'dart:typed_data'; // مطلوب لتحميل الخطوط
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مطلوب لـ rootBundle

// --- استيراد حزم Firestore ومعالجة البيانات ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // مطلوب لـ groupBy

// --- استيراد حزم إنشاء الـ PDF والطباعة ---
import 'package:intl/intl.dart'; // مطلوب لتنسيق التاريخ
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // الاسم المستعار pw لـ widgets
import 'package:printing/printing.dart'; // مطلوب لمعاينة الطباعة

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
  // ... (الكود الداخلي لهذه الدالة كما هو - لا يحتاج تتبع مفصل)
  // ... (الكود محذوف للإيجاز، استخدم الكود الأصلي)
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

      // !!! نقطة الدمج: استدعاء دالة إنشاء الـ PDF المحلية !!!
      print(
        '[PDF_TRACE] _runReportGeneration: بدء استدعاء _generateAndShowPdf...',
      ); // تتبع
      await _generateAndShowPdf(allTraineesData);
      print(
        '[PDF_TRACE] _runReportGeneration: اكتمل استدعاء _generateAndShowPdf.',
      ); // تتبع

      if (context.mounted) {
        // إظهار رسالة نجاح
        print(
          '[PDF_TRACE] _runReportGeneration: إظهار رسالة النجاح (Snackbar).',
        ); // تتبع
        showCustomSnackBar(context, l10n.reportGeneratedSuccessfully);
      }
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
// القسم 3: دوال إنشاء وتصميم الـ PDF (من الكود الثاني)
//======================================================================

/// الدالة التي تنشئ ملف الـ PDF وتعرضه للمعاينة
Future<void> _generateAndShowPdf(List<PdfReportData> allTraineesData) async {
  print('[PDF_TRACE] _generateAndShowPdf: بدأت دالة إنشاء الـ PDF.'); // تتبع
  final doc = pw.Document();
  // 1. تحميل الخط العربي من مجلد assets
  print(
    '[PDF_TRACE] _generateAndShowPdf: بدء تحميل الخط \'Cairo-Regular.ttf\'...',
  ); // تتبع
  final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());
  print('[PDF_TRACE] _generateAndShowPdf: اكتمل تحميل الخط.'); // تتبع

  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  // المرور على بيانات كل متدرب وإنشاء صفحة له
  print(
    '[PDF_TRACE] _generateAndShowPdf: بدء إنشاء الصفحات لـ ${allTraineesData.length} متدرب...',
  ); // تتبع
  for (var traineeData in allTraineesData) {
    print(
      '[PDF_TRACE] \t... إضافة صفحة للمتدرب: ${traineeData.traineeName}',
    ); // تتبع
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // 2. تحديد اتجاه الصفحة من اليمين لليسار
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        // 3. بناء رأس الصفحة (Header)
        header: (pw.Context context) =>
            _buildPdfHeader(now: now, traineeName: traineeData.traineeName),
        // 4. بناء محتوى الصفحة (Body)
        build: (pw.Context context) {
          print(
            '[PDF_TRACE] \t\t... بناء محتوى (body) لـ ${traineeData.traineeName}',
          ); // تتبع
          return _buildPdfBody(
            levelProgress: traineeData.levelProgress,
            aiSummary: traineeData.aiSummary,
            averageMastery: traineeData.averageMastery,
            results: traineeData.results,
            notes: traineeData.notes,
          );
        },
      ),
    );
  }
  print('[PDF_TRACE] _generateAndShowPdf: اكتمل بناء جميع الصفحات.'); // تتبع

  // 5. عرض نافذة معاينة الطباعة
  print(
    '[PDF_TRACE] _generateAndShowPdf: بدء استدعاء Printing.layoutPdf (نافذة المعاينة)...',
  ); // تتبع
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => doc.save(),
  );
  print(
    '[PDF_TRACE] _generateAndShowPdf: اكتمل استدعاء Printing.layoutPdf.',
  ); // تتبع
}

/// ودجت لبناء رأس الصفحة (Header)
pw.Widget _buildPdfHeader({required String now, required String traineeName}) {
  // هذه الدالة سريعة ولا تحتاج تتبع
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'تقرير أداء المتدرب',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('تاريخ التقرير: $now'),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Text('المتدرب: $traineeName', style: const pw.TextStyle(fontSize: 18)),
      pw.Divider(height: 24),
    ],
  );
}

/// ودجت مشترك لبناء محتوى الصفحة (Body)
List<pw.Widget> _buildPdfBody({
  required LevelProgress? levelProgress,
  required double? averageMastery,
  required String? aiSummary,
  required List<QueryDocumentSnapshot> results,
  required List<QueryDocumentSnapshot> notes,
}) {
  // هذه الدالة سريعة ولا تحتاج تتبع مفصل
  return [
    // ... (الكود الداخلي لهذه الدالة كما هو - لا يحتاج تتبع مفصل)
    // ... (الكود محذوف للإيجاز، استخدم الكود الأصلي)
    // --- قسم الإحصائيات العامة ---
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        if (levelProgress != null)
          pw.Text(
            'المستوى الحالي: ${levelProgress.level}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        if (averageMastery != null)
          pw.Text(
            'متوسط الإتقان العام: ${averageMastery.toStringAsFixed(1)}%',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
      ],
    ),
    pw.SizedBox(height: 16),

    // --- قسم إحصائيات المستوى ---
    if (levelProgress != null) ...[
      pw.Text(
        'إحصائيات المستوى الحالي (${levelProgress.level})',
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text('التدريبات المكتملة: ${levelProgress.completedTrainings}'),
          pw.Text('التدريبات المتبقية: ${levelProgress.remainingTrainings}'),
          pw.Text('الإجمالي: ${levelProgress.totalTrainingsInLevel}'),
        ],
      ),
      pw.SizedBox(height: 16),
    ],

    // --- قسم تحليل الذكاء الاصطناعي (يظهر فقط إذا كان موجوداً) ---
    if (aiSummary != null && aiSummary.isNotEmpty) ...[
      pw.Text(
        'تحليل الأداء (AI):',
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Text(
          aiSummary.replaceAll('**', ''), // إزالة علامات التنسيق
          style: const pw.TextStyle(lineSpacing: 2),
        ),
      ),
      pw.SizedBox(height: 16),
    ],

    // --- قسم النتائج ---
    pw.Text(
      'سجل النتائج:',
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 8),
    if (results.isNotEmpty)
      pw.Table.fromTextArray(
        headers: ['التاريخ', 'نسبة الإتقان', 'عنوان التدريب'],
        data: results.map((result) {
          final date = (result['date'] as Timestamp).toDate();
          final formattedDate = DateFormat.yMMMd().format(date);
          return [
            formattedDate,
            '${result['masteryPercentage']}%',
            result['trainingTitle'],
          ];
        }).toList(),
        border: pw.TableBorder.all(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(),
        cellAlignment: pw.Alignment.centerRight,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      )
    else
      pw.Text('لا توجد نتائج مسجلة.'),
    pw.SizedBox(height: 16),

    // --- قسم الملاحظات اليومية ---
    pw.Text(
      'الملاحظات اليومية:',
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 8),
    if (notes.isNotEmpty)
      ...notes.map((note) {
        final date = (note['date'] as Timestamp).toDate();
        final formattedDate = DateFormat.yMMMd().format(date);
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$formattedDate: ${note['note']}'),
              pw.Divider(color: PdfColors.grey400),
            ],
          ),
        );
      }).toList()
    else
      pw.Text('لا توجد ملاحظات مسجلة.'),
  ];
}
