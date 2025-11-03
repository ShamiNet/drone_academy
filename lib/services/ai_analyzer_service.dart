// lib/services/ai_analyzer_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/services/secrets.dart'; // استيراد المفتاح السري
import 'package:google_generative_ai/google_generative_ai.dart';

class AiAnalyzerService {
  // --- استخدام النموذج المحدث بناءً على طلبك ---
  static final _model = GenerativeModel(
    model: 'gemini-2.5-flash', // استخدام نموذج فلاش السريع
    apiKey: geminiApiKey, // المفتاح الجديد الذي أنشأته
    safetySettings: [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    ],
  );
  // --- نهاية التعديل ---

  // --- الدالة الأولى: تلخيص الملاحظات ---
  static Future<String> summarizeTraineeNotes(List<String> notes) async {
    if (notes.isEmpty) {
      return "لا توجد ملاحظات لتحليلها.";
    }

    final allNotesText = notes.join('\n- ');

    // "البرومبت" أو الأمر الذي نعطيه للذكاء الاصطناعي
    final prompt =
        """
      أنت مدرب طائرات درون خبير ومحلل أداء.
      هذه قائمة بالملاحظات اليومية المسجلة من مدربين مختلفين حول أداء متدرب واحد:
      - $allNotesText

      مهمتك هي قراءة كل هذه الملاحظات وتقديم ملخص احترافي باللغة العربية في 3 نقاط رئيسية:
      1.  **نقاط القوة:** ما هي المهارات التي يتقنها المتدرب بشكل متكرر؟
      2.  **نقاط الضعف:** ما هي الأخطاء أو الصعوبات التي تكررت لديه؟
      3.  **التوصية:** بناءً على ما سبق، ما هي النصيحة المباشرة أو التدريب التالي الذي توصي به؟

      اجعل إجابتك موجزة ومباشرة.
      """;

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "لم أتمكن من إنشاء ملخص.";
    } catch (e) {
      print("خطأ في تحليل الذكاء الاصطناعي: $e");
      if (e.toString().contains('SAFETY')) {
        return "تم حجب الإجابة بسبب قيود الأمان. قد تكون إحدى الملاحظات تحتوي على كلمات غير مناسبة.";
      }
      return "حدث خطأ أثناء محاولة تحليل البيانات: $e";
    }
  }

  // --- الدالة الجديدة: تلخيص ملاحظات كل المتدربين في طلب واحد ---
  static Future<Map<String, String>> summarizeAllTraineesNotes(
    Map<String, List<String>> notesByTrainee,
  ) async {
    if (notesByTrainee.isEmpty) {
      return {};
    }

    // تحويل بيانات المتدربين إلى نص منظم
    final traineesDataText = notesByTrainee.entries
        .map((entry) {
          final traineeId = entry.key;
          final notes = entry.value.join('\n- ');
          return """
      {
        "traineeId": "$traineeId",
        "notes": "- $notes"
      }
      """;
        })
        .join(',\n');

    final prompt =
        """
      أنت مدرب طائرات درون خبير ومحلل أداء.
      أمامك قائمة ببيانات متدربين متعددين، كل متدرب له هوية (traineeId) ومجموعة من الملاحظات.
      
      البيانات:
      [$traineesDataText]

      مهمتك هي المرور على "كل متدرب" على حدة وتقديم ملخص احترافي لكل واحد منهم باللغة العربية في 3 نقاط رئيسية:
      1. **نقاط القوة:**
      2. **نقاط الضعف:**
      3. **التوصية:**

      قم بإرجاع النتيجة النهائية على شكل "JSON Object" فقط بدون أي نصوص إضافية، حيث يكون المفتاح هو "traineeId" والقيمة هي "الملخص النصي الكامل" لذلك المتدرب.
      مثال على التنسيق المطلوب:
      {
        "traineeId_1": "نقاط القوة: ...\nنقاط الضعف: ...\nالتوصية: ...",
        "traineeId_2": "نقاط القوة: ...\nنقاط الضعف: ...\nالتوصية: ..."
      }
      """;

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        print("AI response was empty.");
        return {};
      }

      // تنظيف النص من أي علامات كود أو بادئات/لواحق غير ضرورية
      final cleanedJsonString = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decodedJson =
          json.decode(cleanedJsonString) as Map<String, dynamic>;

      // تحويل القيم إلى String
      return decodedJson.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print("خطأ في تحليل الذكاء الاصطناعي الشامل: $e");
      // في حالة الخطأ، أرجع خريطة فارغة لتجنب تعطل التطبيق
      return {};
    }
  }

  // --- الدالة الثانية: التوصية بالتدريب التالي ---
  static Future<String> recommendNextTraining(
    List<DocumentSnapshot> allTrainings,
    List<DocumentSnapshot> traineeResults,
  ) async {
    if (allTrainings.isEmpty) {
      return "لا توجد تدريبات متاحة للتحليل.";
    }
    if (traineeResults.isEmpty) {
      return "لا توجد نتائج لتحليلها. ابدأ بأول تدريب!";
    }

    // 1. تحويل البيانات إلى نص واضح للذكاء الاصطناعي
    String allTrainingsText = allTrainings
        .map((doc) => "التدريب: ${doc['title']} (المستوى: ${doc['level']})")
        .join('\n');

    String traineeResultsText = traineeResults
        .map(
          (doc) =>
              "التدريب: ${doc['trainingTitle']}, النتيجة: ${doc['masteryPercentage']}%",
        )
        .join('\n');

    // 2. "البرومبت" أو الأمر
    final prompt =
        """
      أنت مدرب طائرات درون خبير ومهمتك تحديد خطة التدريب التالية.
      
      هذه هي قائمة "كل التدريبات" المتاحة في الأكاديمية:
      $allTrainingsText

      وهذا هو "سجل نتائج المتدرب" (مرتب من الأحدث للأقدم):
      $traineeResultsText

      مهمتك:
      1.  قارن بين القائمتين.
      2.  ابحث عن التدريبات التي أكملها المتدرب ولكن بنتيجة ضعيفة (أقل من 80%).
      3.  ابحث عن التدريبات التي لم يكملها المتدرب أبداً (موجودة في القائمة الأولى وغير موجودة في الثانية).
      4.  اقترح "تدريباً واحداً فقط" هو الأهم ليركز عليه المتدرب الآن، مع ذكر السبب في جملة واحدة.
      5.  إذا كان المتدرب قد أتقن كل التدريبات (كل النتائج فوق 80%)، فقم بتهنئته.

      اجعل إجابتك باللغة العربية، وموجزة جداً (فقرة واحدة).
      """;

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "لم أتمكن من إنشاء توصية.";
    } catch (e) {
      print("خطأ في تحليل الذكاء الاصطناعي: $e");
      return "حدث خطأ أثناء محاولة تحليل البيانات.";
    }
  }
}
