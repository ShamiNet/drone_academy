import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// --- ثوابت الألوان ---
const PdfColor kPrimaryColor = PdfColor.fromInt(0xFF0D47A1);
const PdfColor kSecondaryColor = PdfColor.fromInt(0xFF1565C0);
const PdfColor kSuccessColor = PdfColor.fromInt(0xFF00695C);
const PdfColor kLightGrey = PdfColor.fromInt(0xFFF5F5F5);
const PdfColor kDarkGrey = PdfColor.fromInt(0xFF424242);

// --- الدالة 1: إنشاء تقرير لمتدرب واحد ---
Future<pw.Document> createPdfDocument({
  required String traineeName,
  required List<QueryDocumentSnapshot> results,
  required List<QueryDocumentSnapshot> notes,
  String? aiSummary,
  LevelProgress? levelProgress,
  double? averageMastery,
}) async {
  return _buildDocument([
    PdfReportData(
      traineeName: traineeName,
      results: results,
      notes: notes,
      aiSummary: aiSummary,
      levelProgress: levelProgress,
      averageMastery: averageMastery,
    ),
  ]);
}

// --- الدالة 2: إنشاء تقرير شامل لكل المتدربين ---
Future<pw.Document> createAllTraineesPdfDocument(
  List<PdfReportData> allTraineesData,
) async {
  return _buildDocument(allTraineesData);
}

// --- دالة البناء الداخلية المشتركة ---
Future<pw.Document> _buildDocument(List<PdfReportData> dataList) async {
  final doc = pw.Document();
  final fontAndLogo = await _loadAssets();
  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  for (var data in dataList) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: fontAndLogo.font,
          bold: fontAndLogo.font,
        ),
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildHeader(fontAndLogo.logo, now),
        footer: (context) => _buildFooter(context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 20),
          _buildTitleBanner(data.traineeName),
          pw.SizedBox(height: 20),

          _buildMainStatsRow(data.averageMastery, data.levelProgress),
          pw.SizedBox(height: 15),

          if (data.levelProgress != null)
            _buildLevelDetailsSection(data.levelProgress!),
          pw.SizedBox(height: 20),

          if (data.aiSummary != null) _buildAiSection(data.aiSummary!),

          _buildResultsTable(data.results),
          pw.SizedBox(height: 20),

          if (data.notes.isNotEmpty) _buildNotesSection(data.notes),
        ],
      ),
    );
  }
  return doc;
}

class _Assets {
  final pw.Font font;
  final pw.MemoryImage logo;
  _Assets(this.font, this.logo);
}

Future<_Assets> _loadAssets() async {
  final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());
  final logoData = await rootBundle.load('assets/images/logo.png');
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
  return _Assets(ttf, logoImage);
}

// ========================== المكونات البصرية ============================

pw.Widget _buildHeader(pw.MemoryImage logo, String date) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Container(height: 40, width: 40, child: pw.Image(logo)),
      pw.Text(
        'تاريخ التقرير: $date',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    ],
  );
}

pw.Widget _buildTitleBanner(String name) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 15),
    decoration: const pw.BoxDecoration(
      color: kPrimaryColor,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'تقرير أداء المتدرب',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'المتدرب: $name',
          style: const pw.TextStyle(color: PdfColors.white, fontSize: 14),
        ),
      ],
    ),
  );
}

pw.Widget _buildMainStatsRow(double? mastery, LevelProgress? level) {
  return pw.Row(
    children: [
      pw.Expanded(
        child: _buildStatCard(
          title: 'متوسط الإتقان العام',
          value: mastery != null ? '${mastery.toStringAsFixed(1)}%' : 'N/A',
          color: kSuccessColor,
          svgIcon: _starSvg,
        ),
      ),
      pw.SizedBox(width: 15),
      pw.Expanded(
        child: _buildStatCard(
          title: 'المستوى الحالي',
          value: level != null ? '${level.level}' : '1',
          color: kSecondaryColor,
          svgIcon: _trendingUpSvg,
        ),
      ),
    ],
  );
}

pw.Widget _buildStatCard({
  required String title,
  required String value,
  required PdfColor color,
  required String svgIcon,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SvgImage(
          svg: svgIcon,
          width: 20,
          height: 20,
          colorFilter: PdfColors.white,
        ),
      ],
    ),
  );
}

pw.Widget _buildLevelDetailsSection(LevelProgress level) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'إحصائيات المستوى الحالي (${level.level})',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: kPrimaryColor,
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildMiniStatBox(
            'التدريبات المكتملة',
            '${level.completedTrainings}',
          ),
          pw.SizedBox(width: 10),
          _buildMiniStatBox(
            'التدريبات المتبقية',
            '${level.remainingTrainings}',
          ),
          pw.SizedBox(width: 10),
          _buildMiniStatBox('الإجمالي', '${level.totalTrainingsInLevel}'),
        ],
      ),
    ],
  );
}

pw.Widget _buildMiniStatBox(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: kDarkGrey,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _buildResultsTable(List<QueryDocumentSnapshot> results) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'سجل النتائج',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: kPrimaryColor,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Table.fromTextArray(
        headers: ['عنوان التدريب', 'نسبة الإتقان', 'التاريخ'],
        data: results.map((doc) {
          final date = (doc['date'] as Timestamp).toDate();
          return [
            doc['trainingTitle'] ?? '',
            '${doc['masteryPercentage']}%',
            DateFormat('MMM dd, yyyy').format(date),
          ];
        }).toList(),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(
          color: kDarkGrey,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        headerDecoration: const pw.BoxDecoration(color: kLightGrey),
        cellStyle: const pw.TextStyle(fontSize: 10, color: kDarkGrey),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        cellAlignment: pw.Alignment.centerLeft,
      ),
    ],
  );
}

// --- تم الإصلاح: إزالة borderRadius لمنع توقف التطبيق ---
pw.Widget _buildNotesSection(List<QueryDocumentSnapshot> notes) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'الملاحظات اليومية',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: kPrimaryColor,
        ),
      ),
      pw.SizedBox(height: 10),
      ...notes.map((note) {
        final date = (note['date'] as Timestamp).toDate();
        return pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: kLightGrey,
            // هام: إزالة borderRadius ليتوافق مع Border(left)
            border: pw.Border(
              left: pw.BorderSide(color: kSecondaryColor, width: 3),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'التاريخ: ${DateFormat('yyyy/MM/dd').format(date)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: kSecondaryColor,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                note['note'],
                style: const pw.TextStyle(fontSize: 10, color: kDarkGrey),
              ),
            ],
          ),
        );
      }).toList(),
    ],
  );
}

pw.Widget _buildAiSection(String summary) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 20),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.orange200),
      color: PdfColor.fromInt(0xFFFFF3E0),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.SvgImage(
              svg: _starSvg,
              width: 12,
              height: 12,
              colorFilter: PdfColors.orange800,
            ),
            pw.SizedBox(width: 5),
            pw.Text(
              'تحليل الذكاء الاصطناعي',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: PdfColors.orange800,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          summary.replaceAll('**', ''),
          style: const pw.TextStyle(
            fontSize: 10,
            lineSpacing: 1.5,
            color: kDarkGrey,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildFooter(pw.Context context) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 20),
    child: pw.Text(
      '${context.pageNumber} / ${context.pagesCount}',
      style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
    ),
  );
}

// ========================== أيقونات SVG ==============================

const String _starSvg =
    '<svg viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>';

const String _trendingUpSvg =
    '<svg viewBox="0 0 24 24"><path d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"/></svg>';
