// lib/utils/error_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // من أجل الحافظة (Clipboard)

void showDetailedErrorDialog(
  BuildContext context,
  String title,
  dynamic error,
) {
  showDialog(
    context: context,
    barrierDismissible: false, // لا تغلق عند النقر في الخارج
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'حدثت مشكلة تقنية. يرجى نسخ الكود أدناه وإرساله للمطور:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: SelectableText(
                  // يسمح بتحديد النص
                  error.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace', // خط يشبه الكود
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // زر النسخ
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('نسخ الخطأ'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: error.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ كود الخطأ بنجاح!')),
              );
            },
          ),
          // زر الإغلاق
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}
