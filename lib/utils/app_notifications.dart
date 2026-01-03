import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class AppNotifications {
  // إشعار النجاح (أخضر)
  static void showSuccess(
    BuildContext context,
    String message, {
    String title = "تمت العملية",
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat, // شكل عصري ومسطح
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      description: Text(message),
      alignment:
          Alignment.topRight, // يظهر من الأعلى (أو اختر bottomLeft للأسفل)
      autoCloseDuration: const Duration(seconds: 4),
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: highModeShadow,
      showProgressBar: true, // شريط عداد للوقت
      icon: const Icon(Icons.check_circle, color: Colors.green),
    );
  }

  // إشعار الخطأ (أحمر)
  static void showError(
    BuildContext context,
    String message, {
    String title = "تنبيه",
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle
          .fillColored, // تعبئة كاملة باللون الأحمر للفت الانتباه
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      description: Text(message, style: const TextStyle(color: Colors.white)),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 5),
      borderRadius: BorderRadius.circular(12.0),
      showProgressBar: false,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  // إشعار معلومات (أزرق)
  static void showInfo(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flat,
      title: const Text("معلومة"),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      icon: const Icon(Icons.info, color: Colors.blue),
    );
  }
}
