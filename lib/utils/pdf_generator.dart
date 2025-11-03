import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:flutter/services.dart'; // Required for rootBundle
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> generateAndPrintPdf(
  String traineeName,
  List<QueryDocumentSnapshot> results,
  List<QueryDocumentSnapshot> notes,
  String? aiSummary,
  LevelProgress? levelProgress,
  double? averageMastery,
) async {
  final doc = pw.Document();
  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  // 1. تحميل الخط العربي من مجلد assets
  final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  doc.addPage(
    pw.MultiPage(
      // 2. تحديد اتجاه الصفحة من اليمين لليسار
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
      pageFormat: PdfPageFormat.a4,
      // --- بداية الإصلاح: فصل رأس الصفحة عن المحتوى ---
      header: (pw.Context context) =>
          _buildPdfHeader(now: now, traineeName: traineeName),
      build: (pw.Context context) => _buildPdfBody(
        levelProgress: levelProgress,
        aiSummary: aiSummary,
        averageMastery: averageMastery,
        results: results,
        notes: notes,
      ),
      // --- نهاية الإصلاح ---
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => doc.save(),
  );
}

Future<void> generateAllTraineesReport(
  List<PdfReportData> allTraineesData,
) async {
  final doc = pw.Document();
  final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());
  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
  for (var traineeData in allTraineesData) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        // --- بداية الإصلاح: فصل رأس الصفحة عن المحتوى ---
        header: (pw.Context context) =>
            _buildPdfHeader(now: now, traineeName: traineeData.traineeName),
        build: (pw.Context context) => _buildPdfBody(
          levelProgress: traineeData.levelProgress,
          aiSummary: traineeData.aiSummary,
          averageMastery: traineeData.averageMastery,
          results: traineeData.results,
          notes: traineeData.notes,
        ),
        // --- نهاية الإصلاح ---
      ),
    );
  }

  // --- بداية التعديل: استخدام نافذة معاينة الطباعة بدلاً من الحفظ المباشر ---
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => doc.save(),
  );
  // --- نهاية التعديل ---
}

// --- ودجت جديد لبناء رأس الصفحة ---
pw.Widget _buildPdfHeader({required String now, required String traineeName}) {
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

// --- ودجت مشترك لبناء محتوى الصفحة (الجسم) ---
List<pw.Widget> _buildPdfBody({
  required LevelProgress? levelProgress,
  required double? averageMastery,
  required String? aiSummary,
  required List<QueryDocumentSnapshot> results,
  required List<QueryDocumentSnapshot> notes,
}) {
  return [
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

    // --- قسم تحليل الذكاء الاصطناعي ---
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
