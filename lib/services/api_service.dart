import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // تأكد من أن هذا الرابط صحيح ويعمل
  final String baseUrl = 'http://qaaz.live:3000/api';
  final Duration pollingInterval = const Duration(seconds: 5);

  static Map<String, dynamic>? currentUser;
  static const String _userKey = 'cached_user_data';

  // --- دوال التسجيل (Logging) ---

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
    final deviceId = await _getDeviceId();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'deviceId': deviceId,
        }),
      );

      _log("LOGIN", "Response Code: ${response.statusCode}");

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        currentUser = data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, json.encode(data));
        return {'success': true};
      } else {
        String errorReason = data['error'] ?? 'Login failed';
        String? banReason = data['reason'];

        // [تعديل] هنا نمرر الإيميل ليظهر في السجل بدلاً من Unknown
        _logError(
          "LOGIN_FAIL",
          "Status: ${response.statusCode} - Body: ${response.body}",
          tempUserName: "محاولة دخول: $email",
        );

        return {'success': false, 'error': errorReason, 'reason': banReason};
      }
    } catch (e) {
      // [تعديل] وهنا أيضاً نمرر الإيميل
      _logError(
        "LOGIN_EXCEPTION",
        e.toString(),
        tempUserName: "محاولة دخول: $email",
      );
      return {'success': false, 'error': 'Connection error'};
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
    _log("FETCH_USER", "Requesting user data for UID: $uid");
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
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
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
        return List<dynamic>.from(json.decode(response.body));
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
      if (response.statusCode == 200) return json.decode(response.body)['id'];
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
      return response.statusCode == 200;
    } catch (e) {
      _logError("DELETE_TRAINING", e.toString());
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

  Stream<List<dynamic>> streamSteps(String tid) => _createSmartStream(
    fetcher: () => fetchSteps(tid),
    cacheKey: 'CACHE_STEPS_$tid',
  );

  Future<bool> addTrainingStep(String tid, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trainings/$tid/steps'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("ADD_STEP", response.body);
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
      if (response.statusCode != 200) _logError("UPDATE_STEP", response.body);
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
      if (response.statusCode != 200) _logError("DELETE_STEP", response.body);
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

  Future<bool> addCompetitionEntry(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/competition_entries'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200)
        _logError("ADD_COMP_ENTRY", response.body);
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
      if (response.statusCode != 200) _logError("SET_PROGRESS", response.body);
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

  Stream<Map<String, dynamic>> streamAppConfig() => Stream.periodic(
    pollingInterval,
  ).asyncMap((_) => fetchAppConfig()).asBroadcastStream();

  Future<Map<String, dynamic>> fetchAppConfig() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/app_config'));
      if (res.statusCode == 200) return json.decode(res.body);
      _logError("FETCH_CONFIG", "Status: ${res.statusCode}");
      return {'isEnabled': true, 'forceUpdate': false};
    } catch (e) {
      _logError("FETCH_CONFIG", e.toString());
      return {'isEnabled': true, 'forceUpdate': false};
    }
  }

  Future<String> analyzeNotes(List<String> notes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze_notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'notes': notes}),
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

  Future<bool> updateAppConfig(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/app_config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode != 200) _logError("UPDATE_CONFIG", response.body);
      return true;
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
  }) {
    late StreamController<List<dynamic>> controller;
    Timer? timer;

    void tick() async {
      if (controller.isClosed) return;
      try {
        final data = await fetcher();
        if (!controller.isClosed && data.isNotEmpty) {
          controller.add(data);
          _saveToDisk(cacheKey, data);
        }
      } catch (e) {
        // Errors are logged inside fetchers now
      }
    }

    void start() async {
      final cachedData = await _loadFromDisk(cacheKey);
      if (cachedData.isNotEmpty && !controller.isClosed) {
        controller.add(cachedData);
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
}
