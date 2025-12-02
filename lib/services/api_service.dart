import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = 'http://qaaz.live:3000/api';
  final Duration pollingInterval = const Duration(seconds: 5);

  static Map<String, dynamic>? currentUser;
  static const String _userKey = 'cached_user_data';

  void _logError(String context, Object error) {
    print("ApiService Error [$context]: $error");
  }

  // --- دوال الكاش الدائم (Disk Cache) ---
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
          print("📦 Loaded from Disk: $key");
          return List<dynamic>.from(json.decode(dataString));
        }
      }
    } catch (e) {
      print("Cache Load Error ($key): $e");
    }
    return [];
  }

  // --- المحرك الذكي للستريم (مع الكاش الدائم) ---
  Stream<List<dynamic>> _createSmartStream({
    required Future<List<dynamic>> Function() fetcher,
    required String cacheKey, // مفتاح الحفظ في الهاتف
  }) {
    late StreamController<List<dynamic>> controller;
    Timer? timer;

    // دالة الجلب من السيرفر
    void tick() async {
      if (controller.isClosed) return;
      try {
        final data = await fetcher();
        if (!controller.isClosed && data.isNotEmpty) {
          // تحديث فقط إذا وجد بيانات
          controller.add(data); // إرسال للتطبيق
          _saveToDisk(cacheKey, data); // حفظ في الموبايل
        }
      } catch (e) {
        // في حال فشل النت، لا نفعل شيئاً (تبقى البيانات القديمة معروضة)
      }
    }

    void start() async {
      // 1. فوراً: اعرض البيانات المحفوظة في الموبايل (Offline Data)
      final cachedData = await _loadFromDisk(cacheKey);
      if (cachedData.isNotEmpty && !controller.isClosed) {
        controller.add(cachedData);
      }

      // 2. ابدأ الجلب من السيرفر للتحديث (Live Data)
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

  // ===========================================================================
  // 0. Auth
  // ===========================================================================
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        currentUser = data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, json.encode(data));
        return true;
      }
      return false;
    } catch (e) {
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
      return false;
    }
  }

  Future<void> logout() async {
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // مسح كل الكاش عند الخروج
  }

  // ===========================================================================
  // 1. المستخدمين (Users)
  // ===========================================================================
  // نمرر مفتاح الكاش "CACHE_USERS" ليتم الحفظ باسمه
  Stream<List<dynamic>> streamUsers() =>
      _createSmartStream(fetcher: fetchUsers, cacheKey: 'CACHE_USERS');

  Future<List<dynamic>> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUser(String uid) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/users/$uid'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchUser(String uid) async {
    // محاولة البحث في الكاش المحلي للمستخدمين أولاً
    final users = await _loadFromDisk('CACHE_USERS');
    final cachedUser = users.firstWhere(
      (u) => (u['id'] ?? u['uid']) == uid,
      orElse: () => null,
    );
    if (cachedUser != null) return cachedUser;

    try {
      final response = await http.get(Uri.parse('$baseUrl/users/$uid'));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // 2. المعدات (Equipment)
  // ===========================================================================
  Stream<List<dynamic>> streamEquipment() =>
      _createSmartStream(fetcher: fetchEquipment, cacheKey: 'CACHE_EQUIPMENT');

  Future<List<dynamic>> fetchEquipment() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/equipment'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
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
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addEquipment(Map<String, dynamic> data) async {
    try {
      if (data['createdAt'] != null)
        data['createdAt'] = DateTime.now().toIso8601String();
      await http.post(
        Uri.parse('$baseUrl/equipment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addEquipmentLog(Map<String, dynamic> data) async {
    try {
      if (data['checkOutTime'] != null)
        data['checkOutTime'] = data['checkOutTime'].toIso8601String();
      await http.post(
        Uri.parse('$baseUrl/equipment_log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> fetchEquipmentLogs(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipment_log?equipmentId=$id'),
      );
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteEquipment(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/equipment/$id'));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteEquipmentLog(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/equipment_log/$id'));
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 3. المخزون (Inventory)
  // ===========================================================================
  Stream<List<dynamic>> streamInventory() =>
      _createSmartStream(fetcher: fetchInventory, cacheKey: 'CACHE_INVENTORY');

  Future<List<dynamic>> fetchInventory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/inventory'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
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
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addInventoryItem(Map<String, dynamic> data) async {
    try {
      if (data['createdAt'] != null)
        data['createdAt'] = DateTime.now().toIso8601String();
      await http.post(
        Uri.parse('$baseUrl/inventory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addInventoryLog(Map<String, dynamic> data) async {
    try {
      if (data['date'] != null) data['date'] = data['date'].toIso8601String();
      await http.post(
        Uri.parse('$baseUrl/inventory_log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> fetchInventoryLogs(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory_log?itemId=$id'),
      );
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteInventoryItem(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/inventory/$id'));
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 4. التدريبات (Trainings)
  // ===========================================================================
  Stream<List<dynamic>> streamTrainings() =>
      _createSmartStream(fetcher: fetchTrainings, cacheKey: 'CACHE_TRAININGS');

  Future<List<dynamic>> fetchTrainings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/trainings'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
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
      return null;
    } catch (e) {
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
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTraining(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/trainings/$id'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> fetchSteps(String trainingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trainings/$trainingId/steps'),
      );
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Stream<List<dynamic>> streamSteps(String tid) => _createSmartStream(
    fetcher: () => fetchSteps(tid),
    cacheKey: 'CACHE_STEPS_$tid',
  );

  Future<bool> addTrainingStep(String tid, Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/trainings/$tid/steps'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTrainingStep(
    String tid,
    String sid,
    Map<String, dynamic> data,
  ) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/trainings/$tid/steps/$sid'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTrainingStep(String tid, String sid) async {
    try {
      await http.delete(Uri.parse('$baseUrl/trainings/$tid/steps/$sid'));
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Results & Notes ---
  Future<List<dynamic>> fetchResults({String? traineeUid}) async {
    try {
      String url = '$baseUrl/results';
      if (traineeUid != null) url += '?traineeUid=$traineeUid';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addResult(Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/results'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> fetchDailyNotes({String? traineeUid}) async {
    try {
      String url = '$baseUrl/daily_notes';
      if (traineeUid != null) url += '?traineeUid=$traineeUid';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addDailyNote(Map<String, dynamic> data) async {
    try {
      if (data['date'] != null && data['date'] is DateTime)
        data['date'] = (data['date'] as DateTime).toIso8601String();
      await http.post(
        Uri.parse('$baseUrl/daily_notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateDailyNote(String id, Map<String, dynamic> data) async {
    try {
      if (data['date'] != null && data['date'] is DateTime)
        data['date'] = (data['date'] as DateTime).toIso8601String();
      await http.put(
        Uri.parse('$baseUrl/daily_notes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteDailyNote(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/daily_notes/$id'));
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Competitions ---
  Stream<List<dynamic>> streamCompetitions() => _createSmartStream(
    fetcher: fetchCompetitions,
    cacheKey: 'CACHE_COMPETITIONS',
  );

  Future<List<dynamic>> fetchCompetitions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/competitions'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addCompetition(Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/competitions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCompetition(String id, Map<String, dynamic> data) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/competitions/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCompetition(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/competitions/$id'));
      return true;
    } catch (e) {
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
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addCompetitionEntry(Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/competition_entries'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Schedule ---
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
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addScheduleEvent(Map<String, dynamic> data) async {
    try {
      if (data['startTime'] != null)
        data['startTime'] = data['startTime'].toIso8601String();
      if (data['endTime'] != null)
        data['endTime'] = data['endTime'].toIso8601String();
      await http.post(
        Uri.parse('$baseUrl/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Favorites & Progress ---
  Stream<List<dynamic>> streamUserFavorites(String id) => _createSmartStream(
    fetcher: () => fetchUserFavorites(id),
    cacheKey: 'CACHE_FAVS_$id',
  );
  Future<List<dynamic>> fetchUserFavorites(String id) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/user_favorites?trainerId=$id'),
      );
      if (res.statusCode == 200)
        return List<dynamic>.from(json.decode(res.body));
      return [];
    } catch (e) {
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
      if (isFavorite && docId != null)
        await http.delete(Uri.parse('$baseUrl/user_favorites/$docId'));
      else
        await http.post(
          Uri.parse('$baseUrl/user_favorites'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'trainerId': trainerId, 'trainingId': trainingId}),
        );
      return true;
    } catch (e) {
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
      if (res.statusCode == 200)
        return List<dynamic>.from(json.decode(res.body));
      return [];
    } catch (e) {
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
      if (res.statusCode == 200)
        return List<dynamic>.from(json.decode(res.body));
      return [];
    } catch (e) {
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
      if (isCompleted)
        await http.post(
          Uri.parse('$baseUrl/step_progress'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': uid,
            'trainingId': tid,
            'stepId': sid,
            'completedAt': DateTime.now().toIso8601String(),
          }),
        );
      else
        await http.delete(
          Uri.parse('$baseUrl/step_progress'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'userId': uid, 'trainingId': tid, 'stepId': sid}),
        );
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Org & Config ---
  Future<List<dynamic>> fetchOrgNodes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/org_nodes'));
      if (res.statusCode == 200)
        return List<dynamic>.from(json.decode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addOrgNode(Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/org_nodes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateOrgNode(String id, Map<String, dynamic> data) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/org_nodes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteOrgNode(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/org_nodes/$id'));
      return true;
    } catch (e) {
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
      return {'isEnabled': true, 'forceUpdate': false};
    } catch (e) {
      return {'isEnabled': true, 'forceUpdate': false};
    }
  }

  // --- AI Analysis ---
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
      return 'فشل التحليل (خطأ ${response.statusCode})';
    } catch (e) {
      return 'حدث خطأ في الاتصال بالسيرفر.';
    }
  }

  Future<bool> updateAppConfig(Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/app_config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
