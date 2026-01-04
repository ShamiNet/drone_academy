import 'package:drone_academy/services/api_service.dart';

class AiAnalyzerService {
  // --- 1. تلخيص ملاحظات متدرب واحد ---
  static Future<String> summarizeTraineeNotes(List<String> notes) async {
    if (notes.isEmpty) {
      return "لا توجد ملاحظات لتحليلها.";
    }
    // الاتصال بالسيرفر
    return await ApiService().analyzeNotes(notes);
  }

  // --- 2. تلخيص ملاحظات كل المتدربين (تم التعديل لتعمل الآن) ---
  static Future<Map<String, String>> summarizeAllTraineesNotes(
    Map<String, List<String>> notesByTrainee,
  ) async {
    Map<String, String> results = {};

    // نقوم بالمرور على كل متدرب وتحليل ملاحظاته بشكل منفصل
    // ملاحظة: هذا الحل مؤقت ويعمل، لكنه قد يكون بطيئاً إذا كان العدد كبيراً جداً
    // الحل الأمثل هو دعم Bulk Analysis في السيرفر لاحقاً.
    for (var entry in notesByTrainee.entries) {
      final traineeId = entry.key;
      final notes = entry.value;

      try {
        if (notes.isNotEmpty) {
          // ننتظر قليلاً بين الطلبات لتجنب الضغط
          await Future.delayed(const Duration(milliseconds: 100));
          final summary = await summarizeTraineeNotes(notes);
          results[traineeId] = summary;
        }
      } catch (e) {
        print("Error analyzing notes for $traineeId: $e");
      }
    }

    return results;
  }

  // --- 3. التوصية بالتدريب التالي ---
  static Future<String> recommendNextTraining(
    List<dynamic> allTrainings,
    List<dynamic> traineeResults,
  ) async {
    return "ميزة التوصيات الذكية قادمة قريباً.";
  }
}
