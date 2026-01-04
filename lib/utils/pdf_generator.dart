import 'dart:math' as math;
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:translator/translator.dart';

const PdfColor kPrimaryColor = PdfColor.fromInt(0xFF0D47A1);
const PdfColor kSecondaryColor = PdfColor.fromInt(0xFF1565C0);
const PdfColor kSuccessColor = PdfColor.fromInt(0xFF00695C);
const PdfColor kLightGrey = PdfColor.fromInt(0xFFF5F5F5);
const PdfColor kDarkGrey = PdfColor.fromInt(0xFF424242);

// دالة للتقرير الفردي
Future<pw.Document> createPdfDocument({
  required String traineeName,
  required String creatorName,
  required bool showWatermark,
  required List<dynamic> results,
  required List<dynamic> notes,
  String? aiSummary,
  LevelProgress? levelProgress,
  double? averageMastery,
  String language = 'ar', // اللغة الافتراضية العربية
}) async {
  return _buildDocument(
    [
      PdfReportData(
        traineeName: traineeName,
        results: results,
        notes: notes,
        aiSummary: aiSummary,
        levelProgress: levelProgress,
        averageMastery: averageMastery,
      ),
    ],
    creatorName: creatorName,
    showWatermark: showWatermark,
    languageCode: language,
  );
}

// تم التعديل لاستقبال كود اللغة
Future<pw.Document> createAllTraineesPdfDocument(
  List<PdfReportData> allTraineesData, {
  required String creatorName,
  required bool showWatermark,
  required String languageCode, // ✅ معلمة جديدة
}) async {
  return _buildDocument(
    allTraineesData,
    creatorName: creatorName,
    showWatermark: showWatermark,
    languageCode: languageCode,
  );
}

// دالة للترجمة الآلية للنصوص
final _translator = GoogleTranslator();
final Map<String, Map<String, String>> _translationCache = {};

Future<String> _translateText(String text, String targetLanguage) async {
  // إذا كانت اللغة العربية، لا نترجم
  if (targetLanguage == 'ar' || text.trim().isEmpty) {
    return text;
  }

  // التحقق من الكاش أولاً
  final cacheKey = '${text}_$targetLanguage';
  if (_translationCache.containsKey(targetLanguage) &&
      _translationCache[targetLanguage]!.containsKey(text)) {
    return _translationCache[targetLanguage]![text]!;
  }

  try {
    final translation = await _translator.translate(
      text,
      from: 'ar',
      to: targetLanguage,
    );

    // حفظ الترجمة في الكاش
    _translationCache[targetLanguage] ??= {};
    _translationCache[targetLanguage]![text] = translation.text;

    return translation.text;
  } catch (e) {
    print('خطأ في الترجمة: $e');
    return text; // إرجاع النص الأصلي في حالة الخطأ
  }
}

Future<pw.Document> _buildDocument(
  List<PdfReportData> dataList, {
  required String creatorName,
  required bool showWatermark,
  required String languageCode,
}) async {
  final doc = pw.Document();

  print('📑 جاري بناء وثيقة PDF...');
  print('   📋 عدد صفحات التقرير: ${dataList.length}');
  print('   🎨 الخط: ${languageCode == 'ar' ? 'Cairo' : 'Roboto'}');
  print(
    '   ↔️ اتجاه النص: ${languageCode == 'ar' ? 'RTL (اليمين واليسار)' : 'LTR (اليسار واليمين)'}',
  );

  // ✅ تحميل الخط المناسب بناءً على اللغة
  final fontAndLogo = await _loadAssets(languageCode);

  // ✅ تحديد اتجاه النص (العربية يمين-يسار، الباقي يسار-يمين)
  final bool isRtl = languageCode == 'ar';
  final textDirection = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
  print('⏰ التاريخ والوقت: $now');

  for (var i = 0; i < dataList.length; i++) {
    var data = dataList[i];
    print('   ├─ إضافة صفحة ${i + 1}: ${data.traineeName}');

    // ترجمة البيانات مسبقاً
    final translatedName = await _translateText(data.traineeName, languageCode);
    final translatedAiSummary = data.aiSummary != null
        ? await _translateText(data.aiSummary!, languageCode)
        : null;

    // ترجمة عناوين التدريبات
    final translatedResults = await Future.wait(
      data.results.map((doc) async {
        final trainingTitle = doc['trainingTitle'] ?? '';
        final translatedTitle = await _translateText(
          trainingTitle,
          languageCode,
        );
        DateTime date = (doc['date'] is String)
            ? (DateTime.tryParse(doc['date']) ?? DateTime.now())
            : DateTime.now();
        return {
          'trainingTitle': translatedTitle,
          'masteryPercentage': doc['masteryPercentage'],
          'date': DateFormat('yyyy-MM-dd').format(date),
        };
      }).toList(),
    );

    // ترجمة الملاحظات
    final translatedNotes = await Future.wait(
      data.notes.map((note) async {
        final noteText = note['note'] ?? '';
        final translatedNote = await _translateText(noteText, languageCode);
        DateTime date = (note['date'] is String)
            ? (DateTime.tryParse(note['date']) ?? DateTime.now())
            : DateTime.now();
        return {'note': translatedNote, 'date': date};
      }).toList(),
    );

    doc.addPage(
      pw.MultiPage(
        maxPages: 1000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: textDirection, // ✅ استخدام الاتجاه المحدد
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(
            base: fontAndLogo.font,
            bold: fontAndLogo.font,
          ),
          buildBackground: (context) {
            if (showWatermark) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -math.pi / 4,
                    child: pw.Opacity(
                      opacity: 0.05,
                      child: pw.Text(
                        'Drone Academy',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 60,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey,
                          font: fontAndLogo.font,
                          fontFallback: [fontAndLogo.fallbackFont],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return pw.Container();
          },
        ),
        header: (context) => _buildHeader(
          fontAndLogo.logo,
          now,
          languageCode,
          fontAndLogo.font,
          fontAndLogo.fallbackFont,
        ),
        footer: (context) => _buildFooter(
          context,
          creatorName,
          fontAndLogo.font,
          fontAndLogo.fallbackFont,
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 20),
          _buildTitleBanner(
            translatedName,
            languageCode,
            fontAndLogo.font,
            fontAndLogo.fallbackFont,
          ),
          pw.SizedBox(height: 20),
          _buildMainStatsRow(
            data.averageMastery,
            data.levelProgress,
            languageCode,
            fontAndLogo.font,
            fontAndLogo.fallbackFont,
          ),
          pw.SizedBox(height: 15),
          if (data.levelProgress != null)
            _buildLevelDetailsSection(
              data.levelProgress!,
              languageCode,
              fontAndLogo.font,
              fontAndLogo.fallbackFont,
            ),
          pw.SizedBox(height: 20),
          if (translatedAiSummary != null)
            _buildAiSection(
              translatedAiSummary,
              languageCode,
              fontAndLogo.font,
              fontAndLogo.fallbackFont,
            ),

          ..._buildResultsTable(
            translatedResults,
            languageCode,
            fontAndLogo.font,
            fontAndLogo.fallbackFont,
          ),

          pw.SizedBox(height: 20),
          if (translatedNotes.isNotEmpty)
            ..._buildNotesSection(
              translatedNotes,
              languageCode,
              fontAndLogo.font,
              fontAndLogo.fallbackFont,
            ),
        ],
      ),
    );
  }

  print('✅ تم بناء وثيقة PDF بـ ${dataList.length} صفحة');
  return doc;
}

class _Assets {
  final pw.Font font;
  final pw.Font fallbackFont;
  final pw.MemoryImage logo;
  _Assets(this.font, this.fallbackFont, this.logo);
}

// دالة تحميل الأصول معدلة لاختيار الخط المناسب
Future<_Assets> _loadAssets(String languageCode) async {
  ByteData mainFontData;
  ByteData fallbackFontData;

  print('🔤 جاري تحميل الخط للغة: $languageCode');

  if (languageCode == 'ar') {
    // للعربية: Cairo رئيسي و Roboto كبديل
    print('   └─ تم اختيار خط Cairo للعربية (مع Roboto كبديل)');
    mainFontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    fallbackFontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  } else {
    // للإنجليزية والروسية: Roboto رئيسي و Cairo كبديل للنصوص العربية
    print('   └─ تم اختيار خط Roboto للغة: $languageCode (مع Cairo كبديل)');
    mainFontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    fallbackFontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
  }

  final mainFont = pw.Font.ttf(mainFontData.buffer.asByteData());
  final fallbackFont = pw.Font.ttf(fallbackFontData.buffer.asByteData());
  final logoData = await rootBundle.load('assets/images/logo.png');
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
  print('✅ تم تحميل الخط والشعار بنجاح');
  return _Assets(mainFont, fallbackFont, logoImage);
}

// --- Widgets ---
pw.Widget _buildHeader(
  pw.MemoryImage logo,
  String date,
  String languageCode,
  pw.Font font,
  pw.Font fallbackFont,
) {
  final String dateLabel = languageCode == 'ar'
      ? 'تاريخ التقرير'
      : (languageCode == 'ru' ? 'Дата отчета' : 'Report Date');
  final bool isRtl = languageCode == 'ar';

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: isRtl
        ? [
            pw.Container(height: 40, width: 40, child: pw.Image(logo)),
            pw.Text(
              '$dateLabel: $date',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
                font: font,
                fontFallback: [fallbackFont],
              ),
            ),
          ]
        : [
            pw.Text(
              '$dateLabel: $date',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
                font: font,
                fontFallback: [fallbackFont],
              ),
            ),
            pw.Container(height: 40, width: 40, child: pw.Image(logo)),
          ],
  );
}

// دالة للحصول على النصوص المترجمة
Map<String, String> _getTranslations(String languageCode) {
  final translations = {
    'ar': {
      'traineeReport': 'تقرير أداء المتدرب',
      'avgMastery': 'الإتقان العام',
      'level': 'المستوى',
      'levelStats': 'إحصائيات المستوى',
      'completed': 'المكتمل',
      'remaining': 'المتبقي',
      'total': 'الإجمالي',
      'results': 'النتائج',
      'training': 'التدريب',
      'mastery': 'الإتقان',
      'date': 'التاريخ',
      'dailyNotes': 'الملاحظات اليومية',
      'aiAnalysis': 'تحليل الذكاء الاصطناعي',
    },
    'en': {
      'traineeReport': 'Trainee Performance Report',
      'avgMastery': 'Avg Mastery',
      'level': 'Level',
      'levelStats': 'Level Statistics',
      'completed': 'Completed',
      'remaining': 'Remaining',
      'total': 'Total',
      'results': 'Results',
      'training': 'Training',
      'mastery': 'Mastery',
      'date': 'Date',
      'dailyNotes': 'Daily Notes',
      'aiAnalysis': 'AI Analysis',
    },
    'ru': {
      'traineeReport': 'Отчет об успеваемости стажера',
      'avgMastery': 'Средний уровень',
      'level': 'Уровень',
      'levelStats': 'Статистика уровня',
      'completed': 'Завершено',
      'remaining': 'Осталось',
      'total': 'Всего',
      'results': 'Результаты',
      'training': 'Тренировка',
      'mastery': 'Уровень',
      'date': 'Дата',
      'dailyNotes': 'Ежедневные заметки',
      'aiAnalysis': 'Анализ ИИ',
    },
  };

  return translations[languageCode] ?? translations['ar']!;
}

pw.Widget _buildTitleBanner(
  String name,
  String languageCode,
  pw.Font font,
  pw.Font fallbackFont,
) {
  final trans = _getTranslations(languageCode);

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
          trans['traineeReport']!,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            font: font,
            fontFallback: [fallbackFont],
          ),
        ),
        pw.Text(
          name,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 14,
            font: font,
            fontFallback: [fallbackFont],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildMainStatsRow(
  double? mastery,
  LevelProgress? level,
  String languageCode,
  pw.Font font,
  pw.Font fallbackFont,
) {
  final trans = _getTranslations(languageCode);

  return pw.Row(
    children: [
      pw.Expanded(
        child: _buildStatCard(
          title: trans['avgMastery']!,
          value: mastery != null ? '${mastery.toStringAsFixed(1)}%' : 'N/A',
          color: kSuccessColor,
          svgIcon: _starSvg,
          font: font,
          fallbackFont: fallbackFont,
        ),
      ),
      pw.SizedBox(width: 15),
      pw.Expanded(
        child: _buildStatCard(
          title: trans['level']!,
          value: level != null ? '${level.level}' : '1',
          color: kSecondaryColor,
          svgIcon: _trendingUpSvg,
          font: font,
          fallbackFont: fallbackFont,
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
  required pw.Font font,
  required pw.Font fallbackFont,
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
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                font: font,
                fontFallback: [fallbackFont],
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                font: font,
                fontFallback: [fallbackFont],
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

pw.Widget _buildLevelDetailsSection(
  LevelProgress level,
  String languageCode,
  pw.Font font,
  pw.Font fallbackFont,
) {
  final trans = _getTranslations(languageCode);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '${trans['levelStats']!} (${level.level})',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: kPrimaryColor,
          font: font,
          fontFallback: [fallbackFont],
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildMiniStatBox(
            trans['completed']!,
            '${level.completedTrainings}',
            font,
            fallbackFont,
          ),
          pw.SizedBox(width: 10),
          _buildMiniStatBox(
            trans['remaining']!,
            '${level.remainingTrainings}',
            font,
            fallbackFont,
          ),
          pw.SizedBox(width: 10),
          _buildMiniStatBox(
            trans['total']!,
            '${level.totalTrainingsInLevel}',
            font,
            fallbackFont,
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildMiniStatBox(
  String label,
  String value,
  pw.Font font,
  pw.Font fallbackFont,
) {
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
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
              font: font,
              fontFallback: [fallbackFont],
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: kDarkGrey,
              font: font,
              fontFallback: [fallbackFont],
            ),
          ),
        ],
      ),
    ),
  );
}

List<pw.Widget> _buildResultsTable(
  List<dynamic> results,
  String languageCode,
  pw.Font font,
  pw.Font fallbackFont,
) {
  if (results.isEmpty) return [];
  final trans = _getTranslations(languageCode);

  // البيانات مترجمة مسبقاً
  final tableData = results.map((doc) {
    return [
      doc['trainingTitle'] ?? '',
      '${doc['masteryPercentage']}%',
      doc['date'] ?? '',
    ];
  }).toList();

  return [
    pw.Text(
      trans['results']!,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: kPrimaryColor,
        font: font,
        fontFallback: [fallbackFont],
      ),
    ),
    pw.SizedBox(height: 8),
    pw.TableHelper.fromTextArray(
      headers: [trans['training']!, trans['mastery']!, trans['date']!],
      data: tableData,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        color: kDarkGrey,
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
        font: font,
        fontFallback: [fallbackFont],
      ),
      headerDecoration: const pw.BoxDecoration(color: kLightGrey),
      cellStyle: pw.TextStyle(
        fontSize: 10,
        color: kDarkGrey,
        font: font,
        fontFallback: [fallbackFont],
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      cellAlignment: pw.Alignment.centerLeft,
    ),
  ];
}

List<pw.Widget> _buildNotesSection(
  List<dynamic> notes,
  String languageCode,
  pw.Font font,
  pw.Font fallbackFont,
) {
  if (notes.isEmpty) return [];
  final trans = _getTranslations(languageCode);

  return [
    pw.Text(
      trans['dailyNotes']!,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: kPrimaryColor,
        font: font,
        fontFallback: [fallbackFont],
      ),
    ),
    pw.SizedBox(height: 10),
    ...notes.map((note) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(
          color: kLightGrey,
          border: pw.Border(
            left: pw.BorderSide(color: kSecondaryColor, width: 3),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              DateFormat('yyyy-MM-dd').format(note['date']),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: kSecondaryColor,
                font: font,
                fontFallback: [fallbackFont],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              note['note'] ?? '',
              style: pw.TextStyle(
                fontSize: 10,
                color: kDarkGrey,
                font: font,
                fontFallback: [fallbackFont],
              ),
            ),
          ],
        ),
      );
    }).toList(),
  ];
}

pw.Widget _buildAiSection(
  String summary,
  String languageCode,
  pw.Font font,
  pw.Font fallbackFont,
) {
  final trans = _getTranslations(languageCode);

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
        pw.Text(
          trans['aiAnalysis']!,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
            color: PdfColors.orange800,
            font: font,
            fontFallback: [fallbackFont],
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          summary,
          style: pw.TextStyle(
            fontSize: 10,
            lineSpacing: 1.5,
            color: kDarkGrey,
            font: font,
            fontFallback: [fallbackFont],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildFooter(
  pw.Context context,
  String creatorName,
  pw.Font font,
  pw.Font fallbackFont,
) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 20),
    child: pw.Text(
      '${context.pageNumber} / ${context.pagesCount}',
      style: pw.TextStyle(
        color: PdfColors.grey,
        fontSize: 10,
        font: font,
        fontFallback: [fallbackFont],
      ),
    ),
  );
}

const String _starSvg =
    '<svg viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>';
const String _trendingUpSvg =
    '<svg viewBox="0 0 24 24"><path d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"/></svg>';
