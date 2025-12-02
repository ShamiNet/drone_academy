import 'package:drone_academy/services/api_service.dart';

class AiAnalyzerService {
  // --- 1. تلخيص ملاحظات متدرب واحد (يعمل عبر السيرفر) ---
  static Future<String> summarizeTraineeNotes(List<String> notes) async {
    if (notes.isEmpty) {
      return "لا توجد ملاحظات لتحليلها.";
    }

    // الاتصال بالسيرفر الذي يتصل بـ Gemini
    return await ApiService().analyzeNotes(notes);
  }

  // --- 2. تلخيص ملاحظات كل المتدربين (Placeholder) ---
  // هذه الوظيفة تتطلب تحديثاً في السيرفر لدعم تحليل الـ Bulk JSON.
  // حالياً سنرجع خريطة فارغة لتجنب الأخطاء.
  static Future<Map<String, String>> summarizeAllTraineesNotes(
    Map<String, List<String>> notesByTrainee,
  ) async {
    // TODO: تحديث السيرفر لدعم endpoint: /api/analyze_bulk_notes
    print("⚠️ Bulk analysis requires server update. Returning empty map.");
    return {};
  }

  // --- 3. التوصية بالتدريب التالي (Placeholder) ---
  // هذه الوظيفة تتطلب تحديثاً في السيرفر لدعم منطق التوصيات.
  static Future<String> recommendNextTraining(
    List<dynamic> allTrainings,
    List<dynamic> traineeResults,
  ) async {
    // TODO: تحديث السيرفر لدعم endpoint: /api/recommend_training
    return "ميزة التوصيات الذكية قادمة قريباً.";
  }
}
