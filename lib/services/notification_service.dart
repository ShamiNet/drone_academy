import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    // 1. طلب إذن إرسال الإشعارات من المستخدم
    await _firebaseMessaging.requestPermission();

    // 2. الحصول على "عنوان" الجهاز الفريد (FCM Token)
    final fcmToken = await _firebaseMessaging.getToken();

    print('=======================================');
    print('FCM Token: $fcmToken');
    print('=======================================');

    // لاحقاً، سنقوم بحفظ هذا الـ Token في ملف المستخدم في Firestore
  }
}
