// lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ExportService {
  // الدالة الرئيسية التي سنستدعيها
  static Future<String> exportDatabase() async {
    try {
      // 1. طلب إذن الوصول للذاكرة (تم التحديث ليتوافق مع أندرويد الحديث)
      var manageStatus = await Permission.manageExternalStorage.request();
      var storageStatus = await Permission.storage
          .request(); // كإجراء احتياطي للإصدارات القديمة

      // التحقق من أن أحد الإذنَين على الأقل قد تم منحه
      if (!manageStatus.isGranted && !storageStatus.isGranted) {
        return "إذن الوصول مرفوض. لا يمكن حفظ الملف.";
      }

      // 2. إنشاء خريطة لتخزين كل بياناتنا
      Map<String, dynamic> fullDatabase = {};

      // 3. جلب كل مجلد على حدة
      fullDatabase['users'] = await _fetchCollection('users');
      fullDatabase['trainings'] = await _fetchCollectionWithSubcollections(
        'trainings',
        'steps',
      );
      fullDatabase['results'] = await _fetchCollection('results');
      fullDatabase['daily_notes'] = await _fetchCollection('daily_notes');
      fullDatabase['schedule'] = await _fetchCollection('schedule');
      fullDatabase['competitions'] = await _fetchCollection('competitions');
      fullDatabase['competition_entries'] = await _fetchCollection(
        'competition_entries',
      );
      // --- بداية الإضافة: جلب المجموعات الخاصة بالمفضلة ---
      fullDatabase['user_favorites'] = await _fetchCollection('user_favorites');
      fullDatabase['user_favorite_competitions'] = await _fetchCollection(
        'user_favorite_competitions',
      );
      // --- نهاية الإضافة ---
      fullDatabase['step_progress'] = await _fetchCollection('step_progress');

      // 4. تحويل الخريطة إلى نص JSON منسق
      String jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(fullDatabase);

      // 5. إيجاد المسار الصحيح لحفظ الملف (استخدام مجلد التنزيلات)
      final Directory? directory =
          await getDownloadsDirectory(); // مجلد التنزيلات العام
      if (directory == null) {
        return "لا يمكن إيجاد مسار لحفظ الملف.";
      }

      final String fileName =
          'drone_academy_backup_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.json';
      final String path = '${directory.path}/$fileName';
      final File file = File(path);

      // 6. كتابة النص في الملف
      await file.writeAsString(jsonString);

      print("تم حفظ النسخة الاحتياطية في: $path");
      return "تم الحفظ بنجاح في: ${file.path}";
    } catch (e) {
      print("خطأ أثناء التصدير: $e");
      return "فشل التصدير: $e";
    }
  }

  // دالة مساعدة لجلب مجلد
  static Future<List<Map<String, dynamic>>> _fetchCollection(
    String collectionName,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .get();
    return snapshot.docs.map((doc) => _processDocData(doc.data())).toList();
  }

  // دالة مساعدة لجلب مجلد مع مجلداته الفرعية (مثل التدريبات والخطوات)
  static Future<List<Map<String, dynamic>>> _fetchCollectionWithSubcollections(
    String collectionName,
    String subCollectionName,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .get();
    List<Map<String, dynamic>> items = [];

    for (var doc in snapshot.docs) {
      Map<String, dynamic> itemData = _processDocData(doc.data());
      // جلب المجلد الفرعي وإضافته للبيانات
      final subCollectionSnapshot = await doc.reference
          .collection(subCollectionName)
          .orderBy('order')
          .get();
      itemData[subCollectionName] = subCollectionSnapshot.docs
          .map((step) => _processDocData(step.data()))
          .toList();
      items.add(itemData);
    }
    return items;
  }

  // دالة مساعدة لمعالجة بيانات المستند وتحويل Timestamps
  static Map<String, dynamic> _processDocData(Map<String, dynamic> data) {
    final Map<String, dynamic> processedData = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        // تحويل Timestamp إلى سلسلة نصية بتنسيق ISO 8601
        processedData[key] = value.toDate().toIso8601String();
      } else {
        processedData[key] = value;
      }
    });
    return processedData;
  }
}
