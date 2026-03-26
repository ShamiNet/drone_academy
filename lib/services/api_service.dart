import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // ضروري للـ Navigator و Scaffold
import 'package:drone_academy/models/ai_query_history.dart';

// ⚡ نظام تخزين مؤقت مع وقت انتهاء الصلاحية
class CachedData {
  final List<dynamic> data;
  final DateTime expiresAt;

  CachedData(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // متغير التايمر الخاص بفحص الحظر
  Timer? _statusCheckTimer;

  // تأكد من أن هذا الرابط صحيح ويعمل
  final String baseUrl = 'http://qaaz.live:3000/api';
  // ⚡ تحسين: تقليل معدل الـ polling من 5 ثوانٍ إلى 60 ثانية لتوفير الحصص
  final Duration pollingInterval = const Duration(seconds: 60);

  // نظام ذاكرة مؤقتة مع TTL
  final Map<String, CachedData> _memoryCache = {};
  final Duration _cacheTTL = const Duration(minutes: 5);

  static Map<String, dynamic>? currentUser;
  static const String _userKey = 'cached_user_data';

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<dynamic> _sortTrainingsList(List<dynamic> trainings) {
    final sorted = List<dynamic>.from(trainings);
    sorted.sort((a, b) {
      final levelComparison = _asInt(a['level']).compareTo(_asInt(b['level']));
      if (levelComparison != 0) return levelComparison;

      final orderComparison = _asInt(
        a['order'],
        fallback: 999999,
      ).compareTo(_asInt(b['order'], fallback: 999999));
      if (orderComparison != 0) return orderComparison;

      final titleA = (a['title'] ?? '').toString().toLowerCase();
      final titleB = (b['title'] ?? '').toString().toLowerCase();
      return titleA.compareTo(titleB);
    });
    return sorted;
  }

  Future<void> _invalidateCacheKey(String key) async {
    _memoryCache.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> _invalidateTrainingsCache() async {
    await _invalidateCacheKey('CACHE_TRAININGS');
  }

  Future<void> _invalidateStepsCache(String trainingId) async {
    await _invalidateCacheKey('CACHE_STEPS_$trainingId');
  }

  // نظام مراقبة حالة المستخدم (الحظر)
  // ===========================================================================

  // دالة لبدء مراقبة حالة المستخدم (هل تم حظره؟)
  void startUserStatusMonitoring(BuildContext context) {
    _statusCheckTimer?.cancel();

    // فحص كل 10 ثواني
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      final user = currentUser;
      if (user == null) return; // لا يوجد مستخدم

      final uid = user['uid'] ?? user['id'];
      if (uid == null) return;

      try {
        // جلب أحدث بيانات للمستخدم من السيرفر
        final freshData = await fetchUser(uid);

        if (freshData != null) {
          // التحقق من الحظر
          if (freshData['isBlocked'] == true) {
            _log("SECURITY", "User is banned! Logging out...");

            // إيقاف التايمر
            timer.cancel();

            // تسجيل الخروج
            await logout();

            // توجيه المستخدم لشاشة الدخول (إذا كان التطبيق مفتوحاً)
            if (context.mounted) {
              // افتراض أن '/' هو مسار شاشة تسجيل الدخول أو AuthGate
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);

              // عرض رسالة
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "⛔ تم حظر حسابك من قبل الإدارة. تم تسجيل الخروج.",
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          } else {
            // تحديث البيانات في الذاكرة (مثلاً لو تغير المستوى أو الاسم)
            currentUser = freshData;
            // حفظ التحديث
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_userKey, json.encode(freshData));
          }
        }
      } catch (e) {
        print("Error checking user status: $e");
      }
    });
  }

  // إيقاف المراقبة عند الخروج
  void stopMonitoring() {
    _statusCheckTimer?.cancel();
  }

  // ===========================================================================
  // دوال التسجيل (Logging)
  // ===========================================================================

  void _log(String tag, String message) {
    print("🚀 [API][$tag] $message");
  }

  // [تعديل] إضافة معامل اختياري (tempUserName)
  void _logError(String tag, String error, {String? tempUserName}) {
    print("🔴 [API_ERROR][$tag] $error");
    logAppError(
      error: "API Error [$tag]: $error",
      stackTrace: StackTrace.current.toString(),
      customUserName: tempUserName, // تمرير الاسم
    );
  }

  // [تعديل] استقبال الاسم المخصص
  Future<void> logAppError({
    required String error,
    required String stackTrace,
    String? customUserName, // معامل جديد
  }) async {
    try {
      final user = currentUser;

      // المنطق الجديد:
      // 1. إذا مررنا اسماً مخصصاً (مثل الإيميل عند فشل الدخول) نستخدمه.
      // 2. وإلا، نحاول جلب الاسم من المستخدم المسجل حالياً.
      // 3. وإلا، نكتب "زائر مجهول".
      String finalName =
          customUserName ??
          user?['displayName'] ??
          user?['email'] ??
          'Unknown (Not Logged In)';

      await http.post(
        Uri.parse('$baseUrl/system_errors'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'error': error,
          'stackTrace': stackTrace,
          'userId': user?['uid'] ?? user?['id'] ?? 'Anonymous',
          'userName': finalName, // استخدام الاسم المحسن
          'deviceInfo': Platform.isAndroid ? 'Android' : 'iOS',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print("Failed to log error to server: $e");
    }
  }

  Future<String?> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      print("Error getting device ID: $e");
    }
    return null;
  }

  // ===========================================================================
  // Connectivity & Debugging Utilities
  // ===========================================================================

  /// Test if the server is reachable and responsive
  Future<Map<String, dynamic>> testServerConnectivity() async {
    _log("CONNECTIVITY_TEST", "Testing connection to: $baseUrl");

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Server connection timeout'),
          );

      if (response.statusCode == 200) {
        _log("CONNECTIVITY_TEST", "✅ Server is reachable!");
        return {
          'success': true,
          'message': 'Server is online and responding',
          'statusCode': 200,
          'responseTime': 'Received within 10 seconds',
        };
      } else {
        _logError(
          "CONNECTIVITY_TEST",
          "Server returned unexpected status: ${response.statusCode}",
        );
        return {
          'success': false,
          'message': 'Server returned status ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } on TimeoutException catch (e) {
      _logError("CONNECTIVITY_TEST", "Connection timeout: $e");
      return {
        'success': false,
        'message': 'Connection timeout (10 seconds)',
        'error': 'The server is not responding in time. It may be offline.',
        'suggestion': 'Check if qaaz.live is accessible from your network',
      };
    } on SocketException catch (e) {
      _logError("CONNECTIVITY_TEST", "Network error: ${e.message}");
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
        'error': 'Cannot reach the server',
        'suggestion': 'Check your internet connection and firewall settings',
      };
    } catch (e) {
      _logError("CONNECTIVITY_TEST", "Unexpected error: $e");
      return {
        'success': false,
        'message': 'Unexpected error: $e',
        'error': e.toString(),
      };
    }
  }

  // ===========================================================================
  // 0. Auth & Signup & Device Blocking
  // ===========================================================================

  // ✅ دالة إنشاء الحساب عبر السيرفر (ضرورية للحظر)
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    _log("SIGNUP", "Attempting signup for: $email");

    final deviceId = await _getDeviceId();
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print("FCM Token Error: $e");
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'displayName': displayName,
          'role': role,
          'deviceId': deviceId, // إرسال هوية الجهاز
          'fcmToken': fcmToken,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _log("SIGNUP", "Signup Successful: ${data['uid']}");
        // تسجيل الدخول تلقائياً بعد النجاح
        await login(email, password);
        return {'success': true};
      } else {
        _logError("SIGNUP_FAIL", data['error'] ?? response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Signup failed',
          'reason': data['reason'], // سبب الحظر
        };
      }
    } catch (e) {
      _logError("SIGNUP_EXCEPTION", e.toString());
      return {'success': false, 'error': 'Connection error'};
    }
  }

  // استبدل دالة login القديمة بهذه الدالة المحدثة
  Future<Map<String, dynamic>> login(String email, String password) async {
    _log("LOGIN", "Attempting login for: $email");
    _log("LOGIN", "Server URL: $baseUrl/login");

    final deviceId = await _getDeviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': email,
              'password': password,
              'deviceId': deviceId,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Server connection timeout'),
          );

      _log("LOGIN", "Response Code: ${response.statusCode}");
      _log("LOGIN", "Response Body: ${response.body}");

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        currentUser = data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, json.encode(data));
        _log("LOGIN", "✅ Login successful for: $email");
        return {'success': true};
      } else {
        String errorReason = data['error'] ?? 'Login failed';
        String? banReason = data['reason'];

        // [تعديل] هنا نمرر الإيميل ليظهر في السجل بدلاً من Unknown
        _logError(
          "LOGIN_FAIL",
          "Status: ${response.statusCode} - Error: $errorReason - Body: ${response.body}",
          tempUserName: "محاولة دخول: $email",
        );

        return {'success': false, 'error': errorReason, 'reason': banReason};
      }
    } on TimeoutException catch (e) {
      _logError(
        "LOGIN_TIMEOUT",
        "Request timed out. Server not responding: $e",
        tempUserName: "محاولة دخول: $email",
      );
      return {
        'success': false,
        'error': 'Connection timeout',
        'details':
            'The server is not responding. Please check your internet connection.',
      };
    } on SocketException catch (e) {
      _logError(
        "LOGIN_SOCKET_ERROR",
        "Network error: ${e.message} - Server: $baseUrl",
        tempUserName: "محاولة دخول: $email",
      );
      return {
        'success': false,
        'error': 'SocketException',
        'details':
            'Cannot reach the server. Check your internet connection or try again later.',
      };
    } catch (e) {
      // [تعديل] وهنا أيضاً نمرر الإيميل
      _logError(
        "LOGIN_EXCEPTION",
        "Unexpected error: ${e.runtimeType} - $e - Server: $baseUrl",
        tempUserName: "محاولة دخول: $email",
      );
      return {
        'success': false,
        'error': 'Connection error',
        'details': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> checkDeviceBan() async {
    try {
      final deviceId = await _getDeviceId();
      if (deviceId == null) return {'isBanned': false};

      final response = await http.post(
        Uri.parse('$baseUrl/check_device_ban'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'deviceId': deviceId}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      _logError("CHECK_BAN", "Status: ${response.statusCode}");
    } catch (e) {
      _logError("CHECK_BAN", e.toString());
    }
    return {'isBanned': false};
  }

  Future<bool> banDevice(String deviceId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ban_device'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'deviceId': deviceId,
          'reason': reason,
          'bannedBy': currentUser?['uid'],
        }),
      );
      if (response.statusCode != 200) _logError("BAN_DEVICE", response.body);
      return response.statusCode == 200;
    } catch (e) {
      _logError("BAN_DEVICE", e.toString());
      return false;
    }
  }

  Future<bool> unbanDevice(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/unban_device'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'deviceId': deviceId}),
      );
      if (response.statusCode != 200) _logError("UNBAN_DEVICE", response.body);
      return response.statusCode == 200;
    } catch (e) {
      _logError("UNBAN_DEVICE", e.toString());
      return false;
    }
  }

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_userKey)) return false;
      final userDataString = prefs.getString(_userKey);
      if (userDataString != null) {
        currentUser = json.decode(userDataString);
        return true;
      }
      return false;
    } catch (e) {
      _logError("AUTO_LOGIN", e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try {
      _log("LOGOUT", "Clearing session...");
      stopMonitoring(); // ✅ إيقاف المراقبة عند الخروج
      currentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      _logError("LOGOUT", e.toString());
    }
  }

  // ===========================================================================
  // 1. Users
  // ===========================================================================

  Stream<List<dynamic>> streamUsers() =>
      _createSmartStream(fetcher: fetchUsers, cacheKey: 'CACHE_USERS');

  Future<List<dynamic>> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users'));
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_USERS", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_USERS", e.toString());
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchUser(String uid) async {
    // _log("FETCH_USER", "Requesting user data for UID: $uid"); // تعليق لتخفيف السجلات
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/$uid'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      _logError("FETCH_USER", "Failed for $uid: ${response.body}");
      return null;
    } catch (e) {
      _logError("FETCH_USER", e.toString());
      return null;
    }
  }

  Future<bool> updateUser(Map<String, dynamic> userData) async {
    try {
      final dataToSend = Map<String, dynamic>.from(userData);
      dataToSend['requester'] = currentUser;
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dataToSend),
      );
      if (response.statusCode != 200) _logError("UPDATE_USER", response.body);
      return response.statusCode == 200;
    } catch (e) {
      _logError("UPDATE_USER", e.toString());
      return false;
    }
  }

  Future<bool> deleteUser(String uid) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/users/$uid'));
      if (response.statusCode != 200) _logError("DELETE_USER", response.body);
      return response.statusCode == 200;
    } catch (e) {
      _logError("DELETE_USER", e.toString());
      return false;
    }
  }

  // --- 🆕 جلب المستخدمين حسب التبعية (Affiliation) ---
  Future<List<dynamic>> getUsersByAffiliation(String affiliation) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/by-affiliation/$affiliation'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      _logError("GET_USERS_BY_AFFILIATION", response.body);
      return [];
    } catch (e) {
      _logError("GET_USERS_BY_AFFILIATION", e.toString());
      return [];
    }
  }

  // --- 🆕 جلب المستخدمين حسب التبعية والدور ---
  Future<List<dynamic>> getUsersByAffiliationAndRole(
    String affiliation,
    String role,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/by-affiliation-and-role/$affiliation/$role'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      _logError("GET_USERS_BY_AFFILIATION_AND_ROLE", response.body);
      return [];
    } catch (e) {
      _logError("GET_USERS_BY_AFFILIATION_AND_ROLE", e.toString());
      return [];
    }
  }

  // --- 🆕 جلب جميع المستخدمين مع فلترة اختيارية ---
  Future<List<dynamic>> getUsersFiltered({
    String? role,
    String? affiliation,
  }) async {
    try {
      String url = '$baseUrl/users';
      final params = <String, String>{};

      if (role != null) params['role'] = role;
      if (affiliation != null) params['affiliation'] = affiliation;

      if (params.isNotEmpty) {
        final queryString = params.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url = '$url?$queryString';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      _logError("GET_USERS_FILTERED", response.body);
      return [];
    } catch (e) {
      _logError("GET_USERS_FILTERED", e.toString());
      return [];
    }
  }

  // ===========================================================================
  // 2. Equipment
  // ===========================================================================

  Stream<List<dynamic>> streamEquipment() =>
      _createSmartStream(fetcher: fetchEquipment, cacheKey: 'CACHE_EQUIPMENT');

  Future<List<dynamic>> fetchEquipment() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/equipment'));
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_EQUIPMENT", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_EQUIPMENT", e.toString());
      return [];
    }
  }

  Future<bool> updateEquipment(String id, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/equipment/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );
      if (response.statusCode != 200)
        _logError("UPDATE_EQUIPMENT", response.body);
      return response.statusCode == 200;
    } catch (e) {
      _logError("UPDATE_EQUIPMENT", e.toString());
      return false;
    }
  }

  Future<bool> addEquipment(Map<String, dynamic> data) async {
    try {
      if (data['createdAt'] != null) {
        data['createdAt'] = DateTime.now().toIso8601String();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/equipment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_EQUIPMENT", response.body);
      return response.statusCode == 200;
    } catch (e) {
      _logError("ADD_EQUIPMENT", e.toString());
      return false;
    }
  }

  Future<bool> addEquipmentLog(Map<String, dynamic> data) async {
    try {
      if (data['checkOutTime'] != null) {
        data['checkOutTime'] = data['checkOutTime'].toIso8601String();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/equipment_log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_EQUIP_LOG", response.body);
      return true;
    } catch (e) {
      _logError("ADD_EQUIP_LOG", e.toString());
      return false;
    }
  }

  Future<List<dynamic>> fetchEquipmentLogs(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipment_log?equipmentId=$id'),
      );
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_EQUIP_LOGS", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_EQUIP_LOGS", e.toString());
      return [];
    }
  }

  Future<bool> deleteEquipment(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/equipment/$id'));
      if (response.statusCode != 200)
        _logError("DELETE_EQUIPMENT", response.body);
      return true;
    } catch (e) {
      _logError("DELETE_EQUIPMENT", e.toString());
      return false;
    }
  }

  Future<bool> deleteEquipmentLog(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/equipment_log/$id'),
      );
      if (response.statusCode != 200)
        _logError("DELETE_EQUIP_LOG", response.body);
      return true;
    } catch (e) {
      _logError("DELETE_EQUIP_LOG", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 3. Inventory
  // ===========================================================================

  Stream<List<dynamic>> streamInventory() =>
      _createSmartStream(fetcher: fetchInventory, cacheKey: 'CACHE_INVENTORY');

  Future<List<dynamic>> fetchInventory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/inventory'));
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_INVENTORY", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_INVENTORY", e.toString());
      return [];
    }
  }

  Future<bool> updateInventoryItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inventory/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );
      if (response.statusCode != 200)
        _logError("UPDATE_INVENTORY", response.body);
      return response.statusCode == 200;
    } catch (e) {
      _logError("UPDATE_INVENTORY", e.toString());
      return false;
    }
  }

  Future<bool> addInventoryItem(Map<String, dynamic> data) async {
    try {
      if (data['createdAt'] != null) {
        data['createdAt'] = DateTime.now().toIso8601String();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/inventory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_INVENTORY", response.body);
      return true;
    } catch (e) {
      _logError("ADD_INVENTORY", e.toString());
      return false;
    }
  }

  Future<bool> addInventoryLog(Map<String, dynamic> data) async {
    try {
      if (data['date'] != null) data['date'] = data['date'].toIso8601String();
      final response = await http.post(
        Uri.parse('$baseUrl/inventory_log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_INV_LOG", response.body);
      return true;
    } catch (e) {
      _logError("ADD_INV_LOG", e.toString());
      return false;
    }
  }

  Future<List<dynamic>> fetchInventoryLogs(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory_log?itemId=$id'),
      );
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_INV_LOGS", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_INV_LOGS", e.toString());
      return [];
    }
  }

  Future<bool> deleteInventoryItem(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/inventory/$id'));
      if (response.statusCode != 200)
        _logError("DELETE_INVENTORY", response.body);
      return true;
    } catch (e) {
      _logError("DELETE_INVENTORY", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 4. Trainings
  // ===========================================================================

  Stream<List<dynamic>> streamTrainings() =>
      _createSmartStream(fetcher: fetchTrainings, cacheKey: 'CACHE_TRAININGS');

  Future<List<dynamic>> fetchTrainings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/trainings'));
      if (response.statusCode == 200) {
        final trainings = _sortTrainingsList(
          List<dynamic>.from(json.decode(response.body)),
        );
        _log(
          "FETCH_TRAININGS",
          "Loaded ${trainings.length} trainings: ${trainings.map((t) => '${t['title'] ?? t['id']}[L${t['level'] ?? '-'}|O${t['order'] ?? '-'}]').join(' | ')}",
        );
        return trainings;
      }
      _logError("FETCH_TRAININGS", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_TRAININGS", e.toString());
      return [];
    }
  }

  Future<String?> addTraining(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trainings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        await _invalidateTrainingsCache();
        return json.decode(response.body)['id'];
      }
      _logError("ADD_TRAINING", response.body);
      return null;
    } catch (e) {
      _logError("ADD_TRAINING", e.toString());
      return null;
    }
  }

  Future<bool> updateTraining(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trainings/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200)
        _logError("UPDATE_TRAINING", response.body);
      if (response.statusCode == 200) {
        await _invalidateTrainingsCache();
      }
      return response.statusCode == 200;
    } catch (e) {
      _logError("UPDATE_TRAINING", e.toString());
      return false;
    }
  }

  Future<bool> deleteTraining(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/trainings/$id'));
      if (response.statusCode != 200)
        _logError("DELETE_TRAINING", response.body);
      if (response.statusCode == 200) {
        await _invalidateTrainingsCache();
      }
      return response.statusCode == 200;
    } catch (e) {
      _logError("DELETE_TRAINING", e.toString());
      return false;
    }
  }

  Future<bool> updateTrainingOrders(List<dynamic> trainings) async {
    try {
      _log(
        "UPDATE_TRAINING_ORDER",
        "Sending ${trainings.length} reordered trainings: ${trainings.map((t) => '${t['id']}=>${t['order']}').join(', ')}",
      );
      final payload = {
        'trainings': trainings
            .map(
              (training) => {'id': training['id'], 'order': training['order']},
            )
            .toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trainings/reorder'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode != 200) {
        _logError("UPDATE_TRAINING_ORDER", response.body);
        return false;
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final returnedTrainings = (decoded['trainings'] as List<dynamic>? ?? []);
      _log(
        "UPDATE_TRAINING_ORDER",
        "Server persisted ${returnedTrainings.length} trainings: ${returnedTrainings.map((t) => '${t['id']}=>${t['order']}').join(', ')}",
      );

      await _invalidateTrainingsCache();
      _log(
        "UPDATE_TRAINING_ORDER",
        "Trainings cache invalidated after reorder",
      );
      return true;
    } catch (e) {
      _logError("UPDATE_TRAINING_ORDER", e.toString());
      return false;
    }
  }

  Future<bool> updateTrainingStepOrders(
    String trainingId,
    List<dynamic> steps,
  ) async {
    try {
      _log(
        "UPDATE_STEP_ORDER",
        "Sending ${steps.length} reordered steps for training $trainingId: ${steps.map((step) => '${step['id']}=>${step['order']}').join(', ')}",
      );

      final payload = {
        'steps': steps
            .map((step) => {'id': step['id'], 'order': step['order']})
            .toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trainings/$trainingId/steps/reorder'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode != 200) {
        _logError("UPDATE_STEP_ORDER", response.body);
        return false;
      }

      await _invalidateStepsCache(trainingId);
      _log(
        "UPDATE_STEP_ORDER",
        "Steps cache invalidated after reorder for training $trainingId",
      );
      return true;
    } catch (e) {
      _logError("UPDATE_STEP_ORDER", e.toString());
      return false;
    }
  }

  Future<List<dynamic>> fetchSteps(String trainingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trainings/$trainingId/steps'),
      );
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_STEPS", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_STEPS", e.toString());
      return [];
    }
  }

  // --- ⚡ محرك الكاش الجديد (Future-based) لتوفير القراءات ---
  Future<List<dynamic>> fetchWithCache({
    required String cacheKey,
    required Future<List<dynamic>> Function() fetcher,
    bool forceRefresh = false, // لتحديد ما إذا كان المستخدم سحب الشاشة للتحديث
  }) async {
    // 1. إذا لم يكن هناك طلب تحديث إجباري، نبحث في الكاش أولاً
    if (!forceRefresh) {
      // البحث في الذاكرة العشوائية السريعة
      final cachedInMemory = _memoryCache[cacheKey];
      if (cachedInMemory != null && !cachedInMemory.isExpired) {
        return cachedInMemory.data;
      }

      // البحث في الذاكرة التخزينية (القرص)
      final cachedDisk = await _loadFromDisk(cacheKey);
      if (cachedDisk.isNotEmpty) {
        // رفعها للذاكرة السريعة للمرات القادمة
        _memoryCache[cacheKey] = CachedData(
          cachedDisk,
          DateTime.now().add(_cacheTTL),
        );
        return cachedDisk;
      }
    }

    // 2. إذا كان الكاش فارغاً، أو منتهي الصلاحية، أو المستخدم طلب تحديث إجباري -> نكلم السيرفر
    try {
      final data =
          await fetcher(); // استدعاء دالة الجلب الأصلية (مثل fetchTrainings)
      if (data.isNotEmpty) {
        // حفظ البيانات الجديدة في الكاش
        _saveToDisk(cacheKey, data);
        _memoryCache[cacheKey] = CachedData(
          data,
          DateTime.now().add(_cacheTTL),
        );
      }
      return data;
    } catch (e) {
      // 3. في حالة فشل الإنترنت، نعيد آخر نسخة محفوظة في الجهاز (إن وجدت)
      return await _loadFromDisk(cacheKey);
    }
  }

  // --- 🚀 دوال الجلب الجديدة للاستخدام في الواجهات ---

  // جلب التدريبات
  Future<List<dynamic>> getTrainings({bool forceRefresh = false}) {
    return fetchWithCache(
      cacheKey: 'CACHE_TRAININGS',
      fetcher: fetchTrainings,
      forceRefresh: forceRefresh,
    ).then(_sortTrainingsList);
  }

  // جلب المعدات
  Future<List<dynamic>> getEquipment({bool forceRefresh = false}) {
    return fetchWithCache(
      cacheKey: 'CACHE_EQUIPMENT',
      fetcher: fetchEquipment,
      forceRefresh: forceRefresh,
    );
  }

  // جلب المستخدمين (بالكاش)
  Future<List<dynamic>> getUsers({bool forceRefresh = false}) {
    return fetchWithCache(
      cacheKey: 'CACHE_USERS_FUTURE',
      fetcher: fetchUsers,
      forceRefresh: forceRefresh,
    );
  }

  // جلب المخزون (بالكاش)
  Future<List<dynamic>> getInventory({bool forceRefresh = false}) {
    return fetchWithCache(
      cacheKey: 'CACHE_INVENTORY_FUTURE',
      fetcher: fetchInventory,
      forceRefresh: forceRefresh,
    );
  }

  // جلب المسابقات (بالكاش)
  Future<List<dynamic>> getCompetitions({bool forceRefresh = false}) {
    return fetchWithCache(
      cacheKey: 'CACHE_COMPETITIONS_FUTURE',
      fetcher: fetchCompetitions,
      forceRefresh: forceRefresh,
    );
  }

  // جلب النتائج (بالكاش) - يدعم traineeUid اختياري
  Future<List<dynamic>> getResults({
    String? traineeUid,
    bool forceRefresh = false,
  }) {
    final cacheKey = traineeUid != null
        ? 'CACHE_RESULTS_$traineeUid'
        : 'CACHE_RESULTS_ALL';

    return fetchWithCache(
      cacheKey: cacheKey,
      fetcher: () => fetchResults(traineeUid: traineeUid),
      forceRefresh: forceRefresh,
    );
  }

  // جلب الملاحظات اليومية (بالكاش) - يدعم traineeUid اختياري
  Future<List<dynamic>> getDailyNotes({
    String? traineeUid,
    bool forceRefresh = false,
  }) {
    final cacheKey = traineeUid != null
        ? 'CACHE_DAILY_NOTES_$traineeUid'
        : 'CACHE_DAILY_NOTES_ALL';

    return fetchWithCache(
      cacheKey: cacheKey,
      fetcher: () => fetchDailyNotes(traineeUid: traineeUid),
      forceRefresh: forceRefresh,
    );
  }

  // دالة طلب التحليل المجمع من السيرفر
  Future<Map<String, dynamic>> analyzeBulkNotes(
    Map<String, List<String>> traineesNotes,
  ) async {
    try {
      final user = currentUser;
      final response = await http.post(
        Uri.parse('$baseUrl/analyze_bulk_notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'traineesNotes': traineesNotes,
          'requester': {'email': user?['email']},
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['summaries'] ?? {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Stream<List<dynamic>> streamSteps(String tid) => _createSmartStream(
    fetcher: () => fetchSteps(tid),
    cacheKey: 'CACHE_STEPS_$tid',
    emitEmptyResults: true,
  );

  Future<bool> addTrainingStep(String tid, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trainings/$tid/steps'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) {
        _logError("ADD_STEP", response.body);
        return false;
      }

      await _invalidateStepsCache(tid);
      return true;
    } catch (e) {
      _logError("ADD_STEP", e.toString());
      return false;
    }
  }

  Future<bool> updateTrainingStep(
    String tid,
    String sid,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trainings/$tid/steps/$sid'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) {
        _logError("UPDATE_STEP", response.body);
        return false;
      }

      await _invalidateStepsCache(tid);
      return true;
    } catch (e) {
      _logError("UPDATE_STEP", e.toString());
      return false;
    }
  }

  Future<bool> deleteTrainingStep(String tid, String sid) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trainings/$tid/steps/$sid'),
      );
      if (response.statusCode != 200) {
        _logError("DELETE_STEP", response.body);
        return false;
      }

      await _invalidateStepsCache(tid);
      return true;
    } catch (e) {
      _logError("DELETE_STEP", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 5. Results & Notes
  // ===========================================================================

  Future<List<dynamic>> fetchResults({String? traineeUid}) async {
    try {
      String url = '$baseUrl/results';
      if (traineeUid != null) url += '?traineeUid=$traineeUid';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_RESULTS", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_RESULTS", e.toString());
      return [];
    }
  }

  Future<bool> addResult(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/results'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_RESULT", response.body);
      return true;
    } catch (e) {
      _logError("ADD_RESULT", e.toString());
      return false;
    }
  }

  Future<List<dynamic>> fetchDailyNotes({String? traineeUid}) async {
    try {
      String url = '$baseUrl/daily_notes';
      if (traineeUid != null) url += '?traineeUid=$traineeUid';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_NOTES", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_NOTES", e.toString());
      return [];
    }
  }

  Future<bool> addDailyNote(Map<String, dynamic> data) async {
    try {
      if (data['date'] != null && data['date'] is DateTime) {
        data['date'] = (data['date'] as DateTime).toIso8601String();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/daily_notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_NOTE", response.body);
      return true;
    } catch (e) {
      _logError("ADD_NOTE", e.toString());
      return false;
    }
  }

  Future<bool> updateDailyNote(String id, Map<String, dynamic> data) async {
    try {
      if (data['date'] != null && data['date'] is DateTime) {
        data['date'] = (data['date'] as DateTime).toIso8601String();
      }
      final response = await http.put(
        Uri.parse('$baseUrl/daily_notes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("UPDATE_NOTE", response.body);
      return true;
    } catch (e) {
      _logError("UPDATE_NOTE", e.toString());
      return false;
    }
  }

  Future<bool> deleteDailyNote(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/daily_notes/$id'));
      if (response.statusCode != 200) _logError("DELETE_NOTE", response.body);
      return true;
    } catch (e) {
      _logError("DELETE_NOTE", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 6. Competitions
  // ===========================================================================

  Stream<List<dynamic>> streamCompetitions() => _createSmartStream(
    fetcher: fetchCompetitions,
    cacheKey: 'CACHE_COMPETITIONS',
  );

  Future<List<dynamic>> fetchCompetitions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/competitions'));
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_COMPETITIONS", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_COMPETITIONS", e.toString());
      return [];
    }
  }

  Future<bool> addCompetition(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/competitions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200)
        _logError("ADD_COMPETITION", response.body);
      return true;
    } catch (e) {
      _logError("ADD_COMPETITION", e.toString());
      return false;
    }
  }

  Future<bool> updateCompetition(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/competitions/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200)
        _logError("UPDATE_COMPETITION", response.body);
      return true;
    } catch (e) {
      _logError("UPDATE_COMPETITION", e.toString());
      return false;
    }
  }

  Future<bool> deleteCompetition(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/competitions/$id'),
      );
      if (response.statusCode != 200)
        _logError("DELETE_COMPETITION", response.body);
      return true;
    } catch (e) {
      _logError("DELETE_COMPETITION", e.toString());
      return false;
    }
  }

  Stream<List<dynamic>> streamCompetitionEntries(String id) =>
      _createSmartStream(
        fetcher: () => fetchCompetitionEntries(id),
        cacheKey: 'CACHE_COMP_ENTRIES_$id',
      );

  Future<List<dynamic>> fetchCompetitionEntries(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/competition_entries?competitionId=$id'),
      );
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_COMP_ENTRIES", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_COMP_ENTRIES", e.toString());
      return [];
    }
  }

  Future<List<dynamic>> fetchCompetitionEntriesForTrainee(
    String traineeUid,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/competition_entries?traineeUid=${Uri.encodeQueryComponent(traineeUid)}',
        ),
      );
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_TRAINEE_COMP_ENTRIES", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_TRAINEE_COMP_ENTRIES", e.toString());
      return [];
    }
  }

  Future<List<dynamic>> getCompetitionEntriesForTrainee({
    required String traineeUid,
    bool forceRefresh = false,
  }) {
    return fetchWithCache(
      cacheKey: 'CACHE_COMP_ENTRIES_TRAINEE_$traineeUid',
      fetcher: () => fetchCompetitionEntriesForTrainee(traineeUid),
      forceRefresh: forceRefresh,
    );
  }

  Future<bool> addCompetitionEntry(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/competition_entries'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) {
        _logError("ADD_COMP_ENTRY", response.body);
        return false;
      }
      return true;
    } catch (e) {
      _logError("ADD_COMP_ENTRY", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 7. Schedule
  // ===========================================================================

  Stream<List<dynamic>> streamSchedule({required String traineeId}) =>
      _createSmartStream(
        fetcher: () => fetchSchedule(traineeId),
        cacheKey: 'CACHE_SCHEDULE_$traineeId',
      );

  Future<List<dynamic>> fetchSchedule(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schedule?traineeId=$id'),
      );
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      _logError("FETCH_SCHEDULE", "Status: ${response.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_SCHEDULE", e.toString());
      return [];
    }
  }

  Future<bool> addScheduleEvent(Map<String, dynamic> data) async {
    try {
      if (data['startTime'] != null) {
        data['startTime'] = data['startTime'].toIso8601String();
      }
      if (data['endTime'] != null) {
        data['endTime'] = data['endTime'].toIso8601String();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_SCHEDULE", response.body);
      return true;
    } catch (e) {
      _logError("ADD_SCHEDULE", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 8. Favorites & Progress
  // ===========================================================================

  Stream<List<dynamic>> streamUserFavorites(String id) => _createSmartStream(
    fetcher: () => fetchUserFavorites(id),
    cacheKey: 'CACHE_FAVS_$id',
  );

  Future<List<dynamic>> fetchUserFavorites(String id) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/user_favorites?trainerId=$id'),
      );
      if (res.statusCode == 200) {
        return List<dynamic>.from(json.decode(res.body));
      }
      _logError("FETCH_FAVS", "Status: ${res.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_FAVS", e.toString());
      return [];
    }
  }

  Future<bool> toggleTrainingFavorite(
    String trainerId,
    String trainingId,
    bool isFavorite, {
    String? docId,
  }) async {
    try {
      http.Response response;
      if (isFavorite && docId != null) {
        response = await http.delete(
          Uri.parse('$baseUrl/user_favorites/$docId'),
        );
      } else {
        response = await http.post(
          Uri.parse('$baseUrl/user_favorites'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'trainerId': trainerId, 'trainingId': trainingId}),
        );
      }
      if (response.statusCode != 200) _logError("TOGGLE_FAV", response.body);
      return true;
    } catch (e) {
      _logError("TOGGLE_FAV", e.toString());
      return false;
    }
  }

  Stream<List<dynamic>> streamUserFavoriteCompetitions(String id) =>
      _createSmartStream(
        fetcher: () => fetchUserFavoriteCompetitions(id),
        cacheKey: 'CACHE_FAV_COMPS_$id',
      );

  Future<List<dynamic>> fetchUserFavoriteCompetitions(String id) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/user_favorite_competitions?trainerId=$id'),
      );
      if (res.statusCode == 200) {
        return List<dynamic>.from(json.decode(res.body));
      }
      _logError("FETCH_FAV_COMPS", "Status: ${res.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_FAV_COMPS", e.toString());
      return [];
    }
  }

  Stream<List<dynamic>> streamStepProgress(String uid, String tid) =>
      _createSmartStream(
        fetcher: () => fetchStepProgress(uid, tid),
        cacheKey: 'CACHE_STEP_$uid\_$tid',
      );

  Future<List<dynamic>> fetchStepProgress(String uid, String tid) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/step_progress?userId=$uid&trainingId=$tid'),
      );
      if (res.statusCode == 200) {
        return List<dynamic>.from(json.decode(res.body));
      }
      _logError("FETCH_PROGRESS", "Status: ${res.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_PROGRESS", e.toString());
      return [];
    }
  }

  Future<bool> setStepProgress(
    String uid,
    String tid,
    String sid,
    bool isCompleted,
  ) async {
    try {
      final cacheKey = 'CACHE_STEP_${uid}_$tid';
      http.Response response;
      if (isCompleted) {
        response = await http.post(
          Uri.parse('$baseUrl/step_progress'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': uid,
            'trainingId': tid,
            'stepId': sid,
            'completedAt': DateTime.now().toIso8601String(),
          }),
        );
      } else {
        response = await http.delete(
          Uri.parse('$baseUrl/step_progress'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'userId': uid, 'trainingId': tid, 'stepId': sid}),
        );
      }
      if (response.statusCode != 200) {
        _logError("SET_PROGRESS", response.body);
        return false;
      }

      await _invalidateCacheKey(cacheKey);
      _log(
        "SET_PROGRESS",
        "Updated step progress uid=$uid tid=$tid sid=$sid completed=$isCompleted and invalidated $cacheKey",
      );
      return true;
    } catch (e) {
      _logError("SET_PROGRESS", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 9. Org, Config & AI
  // ===========================================================================

  Future<List<dynamic>> fetchOrgNodes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/org_nodes'));
      if (res.statusCode == 200) {
        return List<dynamic>.from(json.decode(res.body));
      }
      _logError("FETCH_ORG", "Status: ${res.statusCode}");
      return [];
    } catch (e) {
      _logError("FETCH_ORG", e.toString());
      return [];
    }
  }

  Future<bool> addOrgNode(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/org_nodes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_ORG", response.body);
      return true;
    } catch (e) {
      _logError("ADD_ORG", e.toString());
      return false;
    }
  }

  Future<bool> updateOrgNode(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/org_nodes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("UPDATE_ORG", response.body);
      return true;
    } catch (e) {
      _logError("UPDATE_ORG", e.toString());
      return false;
    }
  }

  Future<bool> deleteOrgNode(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/org_nodes/$id'));
      if (response.statusCode != 200) _logError("DELETE_ORG", response.body);
      return true;
    } catch (e) {
      _logError("DELETE_ORG", e.toString());
      return false;
    }
  }

  // ✅ تم التعديل لجلب البيانات فوراً ثم التكرار كل 60 ثانية
  Stream<Map<String, dynamic>> streamAppConfig() {
    late StreamController<Map<String, dynamic>> controller;
    Timer? timer;

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () async {
        // 1. جلب البيانات فوراً عند الاستماع
        controller.add(await fetchAppConfig());

        // 2. تشغيل المؤقت لتحديث البيانات كل 60 ثانية من server.js
        timer = Timer.periodic(const Duration(seconds: 60), (_) async {
          controller.add(await fetchAppConfig());
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Map<String, dynamic> _getDefaultConfig() {
    return {
      'isEnabled': true,
      'minVersion': '1.0.0',
      'latestVersion': '1.0.2',
      'updateRequired': false,
      'updateUrl': '',
      'updateMessage': 'تحديث جديد متاح',
    };
  }

  // قراءة الإعدادات من server.js الذي يقرأ من Firebase ويقوم بالمقارنات
  Future<Map<String, dynamic>> fetchAppConfig() async {
    try {
      print('🌐 [FETCH_CONFIG] Requesting: $baseUrl/app_config');
      final response = await http.get(Uri.parse('$baseUrl/app_config'));

      if (response.statusCode == 200) {
        final config = Map<String, dynamic>.from(json.decode(response.body));
        print('✅ [FETCH_CONFIG] Success: $config');
        return config;
      }

      print('⚠️ [FETCH_CONFIG] Failed with status: ${response.statusCode}');
      _logError("FETCH_CONFIG", "Status: ${response.statusCode}");
      final defaultConfig = _getDefaultConfig();
      print('🔄 [FETCH_CONFIG] Using default config: $defaultConfig');
      return defaultConfig;
    } catch (e) {
      print('❌ [FETCH_CONFIG] Error: $e');
      _logError("FETCH_CONFIG", e.toString());
      final defaultConfig = _getDefaultConfig();
      print(
        '🔄 [FETCH_CONFIG] Using default config due to error: $defaultConfig',
      );
      return defaultConfig;
    }
  }

  Future<String> analyzeNotes(List<String> notes) async {
    try {
      final user = currentUser;
      final response = await http.post(
        Uri.parse('$baseUrl/analyze_notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'notes': notes,
          'requester': {'email': user?['email']},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['summary'] ?? 'لا يوجد رد من الذكاء الاصطناعي.';
      }
      _logError("AI_ANALYZE", "Status: ${response.statusCode}");
      return 'فشل التحليل (خطأ ${response.statusCode})';
    } catch (e) {
      _logError("AI_ANALYZE", e.toString());
      return 'حدث خطأ في الاتصال بالسيرفر.';
    }
  }

  Future<Map<String, dynamic>> aiAdminQuery({
    required String question,
    required Map<String, bool> scope,
    String mode = 'general',
    int limit = 50, // ⚡ حد افتراضي 50 بدلاً من 200 لتقليل الاستهلاك
    String editId = '', // ID للتعديل
    String trainingId = '', // ID للتدريب عند التعامل مع الخطوات
  }) async {
    try {
      // ⚡ تحقق من وجود نفس الاستعلام في الذاكرة المؤقتة
      final cacheKey = 'AI_QUERY_${question}_${mode}_${scope.toString()}';
      final cached = _memoryCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return {
          'success': true,
          'answer': (cached.data.isNotEmpty ? cached.data[0] : ''),
          'cached': true,
        };
      }

      final user = currentUser;
      final response = await http.post(
        Uri.parse('$baseUrl/ai_admin_query'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'question': question,
          'mode': mode,
          'scope': scope,
          'limit': limit, // ⚡ إرسال الحد للسيرفر
          'editId': editId, // إرسال ID للتعديل
          'trainingId': trainingId, // إرسال ID للتدريب
          'requester': {
            'uid': user?['uid'] ?? user?['id'],
            'role': user?['role'],
            'email': user?['email'],
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final answer = data['answer']?.toString() ?? '';

        // ⚡ حفظ النتيجة في الذاكرة المؤقتة لمدة 10 دقائق
        _memoryCache[cacheKey] = CachedData([
          answer,
        ], DateTime.now().add(const Duration(minutes: 10)));

        // 💾 حفظ تلقائياً في السجل المحلي
        final historyItem = AiQueryHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          question: question,
          answer: answer,
          mode: mode,
          scope: scope,
          timestamp: DateTime.now(),
          userName: user?['displayName'] ?? user?['email'] ?? 'Unknown',
          dataLimit: limit,
        );
        await saveAiQueryToHistory(historyItem);

        return {'success': true, 'answer': answer};
      }

      _logError(
        "AI_ADMIN",
        "Status: ${response.statusCode} - ${response.body}",
      );
      return {
        'success': false,
        'error': 'فشل الطلب (خطأ ${response.statusCode})',
      };
    } catch (e) {
      _logError("AI_ADMIN", e.toString());
      return {'success': false, 'error': 'تعذر الاتصال بالسيرفر.'};
    }
  }

  Future<bool> updateAppConfig(Map<String, dynamic> data) async {
    try {
      // إرسال البيانات إلى server.js ليقوم بالحفظ والتحقق من Firebase
      final response = await http.post(
        Uri.parse('$baseUrl/app_config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return true;
      }

      _logError(
        "UPDATE_CONFIG",
        "Status: ${response.statusCode} - ${response.body}",
      );
      return false;
    } catch (e) {
      _logError("UPDATE_CONFIG", e.toString());
      return false;
    }
  }

  // ===========================================================================
  // 10. System Errors Fetching (خاص بالمدير)
  // ===========================================================================

  Stream<List<dynamic>> streamSystemErrors() =>
      _createSmartStream(fetcher: fetchSystemErrors, cacheKey: 'CACHE_ERRORS');

  Future<List<dynamic>> fetchSystemErrors() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/system_errors'));
      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      // لا نسجل خطأ جلب الأخطاء لتجنب الدوران اللانهائي
      print("Error fetching logs: $e");
      return [];
    }
  }

  Future<void> deleteErrorLog(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/system_errors/$id'));
    } catch (e) {
      print("Error deleting log: $e");
    }
  }

  // ===========================================================================
  // 11. Core Engine (Smart Stream & Disk Cache)
  // ===========================================================================

  Stream<List<dynamic>> _createSmartStream({
    required Future<List<dynamic>> Function() fetcher,
    required String cacheKey,
    bool emitEmptyResults = false,
  }) {
    late StreamController<List<dynamic>> controller;
    Timer? timer;

    void tick() async {
      if (controller.isClosed) return;

      // ⚡ تحقق من الذاكرة المؤقتة أولاً قبل الطلب من السيرفر
      final cachedInMemory = _memoryCache[cacheKey];
      if (cachedInMemory != null && !cachedInMemory.isExpired) {
        // البيانات موجودة في الذاكرة وصالحة، لا حاجة للطلب
        if (!controller.isClosed) {
          controller.add(cachedInMemory.data);
        }
        return;
      }

      try {
        final data = await fetcher();
        if (!controller.isClosed && (emitEmptyResults || data.isNotEmpty)) {
          controller.add(data);
          _saveToDisk(cacheKey, data);
          // ⚡ حفظ في الذاكرة المؤقتة مع وقت انتهاء الصلاحية
          _memoryCache[cacheKey] = CachedData(
            data,
            DateTime.now().add(_cacheTTL),
          );
        }
      } catch (e) {
        // Errors are logged inside fetchers now
      }
    }

    void start() async {
      // تحقق من memory cache أولاً
      final cachedInMemory = _memoryCache[cacheKey];
      if (cachedInMemory != null && !cachedInMemory.isExpired) {
        if (!controller.isClosed) {
          controller.add(cachedInMemory.data);
        }
      } else {
        // جلب من disk cache
        final cachedData = await _loadFromDisk(cacheKey);
        if (cachedData.isNotEmpty && !controller.isClosed) {
          controller.add(cachedData);
          // حفظ في memory أيضاً
          _memoryCache[cacheKey] = CachedData(
            cachedData,
            DateTime.now().add(_cacheTTL),
          );
        }
      }
      tick();
      timer = Timer.periodic(pollingInterval, (_) => tick());
    }

    void stop() {
      timer?.cancel();
    }

    controller = StreamController<List<dynamic>>(
      onListen: start,
      onCancel: stop,
    );

    return controller.stream.asBroadcastStream();
  }

  Future<void> _saveToDisk(String key, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json.encode(data));
    } catch (e) {
      print("Cache Save Error ($key): $e");
    }
  }

  Future<List<dynamic>> _loadFromDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(key)) {
        final String? dataString = prefs.getString(key);
        if (dataString != null) {
          return List<dynamic>.from(json.decode(dataString));
        }
      }
    } catch (e) {
      print("Cache Load Error ($key): $e");
    }
    return [];
  }

  /// ⚡ تنظيف الذاكرة المؤقتة من البيانات المنتهية الصلاحية
  void cleanExpiredCache() {
    _memoryCache.removeWhere((key, value) => value.isExpired);
  }

  /// ⚡ مسح كل الذاكرة المؤقتة (للإدمنز فقط أو عند الحاجة)
  void clearAllCache() {
    _memoryCache.clear();
    SharedPreferences.getInstance().then((prefs) {
      final keys = prefs.getKeys().where((k) => k.startsWith('CACHE_'));
      for (final key in keys) {
        prefs.remove(key);
      }
    });
  }

  // ===========================================================================
  // 12. نظام حفظ سجل استعلامات الذكاء الاصطناعي محلياً
  // ===========================================================================

  static const String _aiHistoryKey = 'AI_QUERY_HISTORY';
  static const int _maxHistoryItems = 100; // الحد الأقصى للسجلات المحفوظة

  /// حفظ استعلام جديد في السجل المحلي
  Future<bool> saveAiQueryToHistory(AiQueryHistory query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<AiQueryHistory> history = await getAiQueryHistory();

      // إضافة الاستعلام الجديد في البداية
      history.insert(0, query);

      // الاحتفاظ بآخر _maxHistoryItems فقط
      if (history.length > _maxHistoryItems) {
        history.removeRange(_maxHistoryItems, history.length);
      }

      // تحويل إلى JSON وحفظ
      final jsonList = history.map((q) => q.toJson()).toList();
      await prefs.setString(_aiHistoryKey, json.encode(jsonList));

      final preview = query.question.length > 30
          ? '${query.question.substring(0, 30)}...'
          : query.question;
      _log("AI_HISTORY", "Saved query: $preview");
      return true;
    } catch (e) {
      _logError("AI_HISTORY_SAVE", e.toString());
      return false;
    }
  }

  /// جلب جميع السجلات المحفوظة
  Future<List<AiQueryHistory>> getAiQueryHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_aiHistoryKey);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => AiQueryHistory.fromJson(json)).toList();
    } catch (e) {
      _logError("AI_HISTORY_GET", e.toString());
      return [];
    }
  }

  /// البحث في السجل بكلمة مفتاحية
  Future<List<AiQueryHistory>> searchAiQueryHistory(String keyword) async {
    try {
      final List<AiQueryHistory> allHistory = await getAiQueryHistory();
      final lowerKeyword = keyword.toLowerCase();

      return allHistory.where((query) {
        return query.question.toLowerCase().contains(lowerKeyword) ||
            query.answer.toLowerCase().contains(lowerKeyword) ||
            query.getModeLabel().toLowerCase().contains(lowerKeyword);
      }).toList();
    } catch (e) {
      _logError("AI_HISTORY_SEARCH", e.toString());
      return [];
    }
  }

  /// حذف استعلام محدد من السجل
  Future<bool> deleteAiQueryFromHistory(String queryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<AiQueryHistory> history = await getAiQueryHistory();

      // إزالة الاستعلام المطلوب
      history.removeWhere((q) => q.id == queryId);

      // حفظ القائمة المحدثة
      final jsonList = history.map((q) => q.toJson()).toList();
      await prefs.setString(_aiHistoryKey, json.encode(jsonList));

      _log("AI_HISTORY", "Deleted query: $queryId");
      return true;
    } catch (e) {
      _logError("AI_HISTORY_DELETE", e.toString());
      return false;
    }
  }

  /// مسح جميع السجلات
  Future<bool> clearAiQueryHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_aiHistoryKey);
      _log("AI_HISTORY", "Cleared all history");
      return true;
    } catch (e) {
      _logError("AI_HISTORY_CLEAR", e.toString());
      return false;
    }
  }

  /// الحصول على إحصائيات السجل
  Future<Map<String, dynamic>> getAiHistoryStats() async {
    try {
      final List<AiQueryHistory> history = await getAiQueryHistory();

      // حساب الإحصائيات
      final Map<String, int> modeCount = {};
      for (var query in history) {
        modeCount[query.mode] = (modeCount[query.mode] ?? 0) + 1;
      }

      return {
        'total': history.length,
        'byMode': modeCount,
        'oldest': history.isEmpty
            ? null
            : history.last.timestamp.toIso8601String(),
        'newest': history.isEmpty
            ? null
            : history.first.timestamp.toIso8601String(),
      };
    } catch (e) {
      _logError("AI_HISTORY_STATS", e.toString());
      return {'total': 0};
    }
  }
}
