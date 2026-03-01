import 'package:drone_academy/services/api_service.dart';

class AiAnalyzerService {
  // --- 1. التحليل الفردي (الخيار الأفضل والموفر) ---
  // يتم استدعاؤه فقط عندما يضغط المدرب على زر "تحليل" داخل صفحة المتدرب
  static Future<String> summarizeTraineeNotes(List<String> notes) async {
    if (notes.isEmpty) {
      return "لا توجد ملاحظات لتحليلها.";
    }
    return await ApiService().analyzeNotes(notes);
  }

  // --- 2. إيقاف التحليل الجماعي التكراري ---
  // تم تعطيل هذه الدالة لتجنب استهلاك حصص (Quotas) هائلة
  static Future<Map<String, String>> summarizeAllTraineesNotes(
    Map<String, List<String>> notesByTrainee,
  ) async {
    // إرجاع خريطة فارغة لتخطي العملية تلقائياً
    return {};
  }

  // --- 3. التحليل المجمع الاقتصادي (طلب واحد للسيرفر) ---
  // إذا كنت مصراً على تحليل الجميع دفعة واحدة، استخدم هذه الدالة التي تستدعي المسار الجديد
  static Future<Map<String, dynamic>> summarizeAllTraineesBulk(
    Map<String, List<String>> notesByTrainee,
  ) async {
    if (notesByTrainee.isEmpty) return {};
    return await ApiService().analyzeBulkNotes(notesByTrainee);
  }

  // --- 4. التوصية بالتدريب التالي ---
  static Future<String> recommendNextTraining(
    List<dynamic> allTrainings,
    List<dynamic> traineeResults,
  ) async {
    return "ميزة التوصيات الذكية قادمة قريباً.";
  }
}
