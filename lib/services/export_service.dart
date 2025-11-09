// lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  // تجميع كل بيانات قاعدة البيانات في خريطة واحدة
  static Future<Map<String, dynamic>> _buildFullDatabase() async {
    Map<String, dynamic> fullDatabase = {};

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
    fullDatabase['user_favorites'] = await _fetchCollection('user_favorites');
    fullDatabase['user_favorite_competitions'] = await _fetchCollection(
      'user_favorite_competitions',
    );
    fullDatabase['step_progress'] = await _fetchCollection('step_progress');

    return fullDatabase;
  }

  // إرجاع محتوى النسخة الاحتياطية كـ Bytes (بدون حفظ)
  static Future<Uint8List> generateBackupBytes() async {
    final fullDatabase = await _buildFullDatabase();
    final jsonString = const JsonEncoder.withIndent('  ').convert(fullDatabase);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  // الدالة الرئيسية لحفظ النسخة الاحتياطية
  static Future<String> exportDatabase() async {
    try {
      // 1. بناء البيانات وتهيئتها
      final bytes = await generateBackupBytes();
      final String jsonString = utf8.decode(bytes);

      final String fileName =
          'drone_academy_backup_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}';

      // 3. حفظ بطريقة متوافقة مع الأنظمة المختلفة
      // - على Android/iOS/Web: نستخدم FileSaver ليطلب من المستخدم اختيار مكان الحفظ عبر SAF/المشاركة
      // - على سطح المكتب: نحاول الحفظ في مجلد التنزيلات مباشرة
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        try {
          final savedPath = await FileSaver.instance.saveFile(
            name: '$fileName.json',
            bytes: bytes,
            mimeType: MimeType.json,
          );
          return savedPath.isNotEmpty ? "تم الحفظ بنجاح" : "تم إنشاء الملف";
        } catch (e) {
          // fallback إلى الحفظ في مجلد مستندات التطبيق
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/$fileName.json';
          final file = File(path);
          await file.writeAsString(jsonString);
          return "تم الحفظ في مجلد التطبيق: $path";
        }
      } else {
        // أنظمة سطح المكتب
        final Directory? directory = await getDownloadsDirectory();
        final dirPath =
            directory?.path ?? (await getApplicationDocumentsDirectory()).path;
        final String path = '$dirPath/$fileName.json';
        final File file = File(path);
        await file.writeAsString(jsonString);
        return "تم الحفظ بنجاح في: $path";
      }
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
