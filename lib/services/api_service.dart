import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://qaaz.live:3000/api';
  final Duration pollingInterval = const Duration(seconds: 5);

  void _logError(String context, Object error) {
    print("ApiService Error [$context]: $error");
  }

  // --- Helper for Streams: Emit immediately then periodically ---
  Stream<T> _createPollingStream<T>(Future<T> Function() fetcher) async* {
    // 1. Emit data immediately
    yield await fetcher();
    // 2. Then emit periodically
    yield* Stream.periodic(pollingInterval).asyncMap((_) => fetcher());
  }

  // --- Users ---
  Stream<List<dynamic>> streamUsers() =>
      _createPollingStream(fetchUsers).asBroadcastStream();

  Future<List<dynamic>> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchUsers', e);
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
      _logError('updateUser', e);
      return false;
    }
  }

  Future<bool> deleteUser(String uid) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/users/$uid'));
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteUser', e);
      return false;
    }
  }

  // --- Equipment ---
  Stream<List<dynamic>> streamEquipment() =>
      _createPollingStream(fetchEquipment).asBroadcastStream();

  Future<List<dynamic>> fetchEquipment() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/equipment'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchEquipment', e);
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
      _logError('updateEquipment', e);
      return false;
    }
  }

  Future<bool> addEquipmentLog(Map<String, dynamic> logData) async {
    try {
      if (logData['checkOutTime'] != null)
        logData['checkOutTime'] = logData['checkOutTime'].toIso8601String();
      final response = await http.post(
        Uri.parse('$baseUrl/equipment_log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(logData),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addEquipmentLog', e);
      return false;
    }
  }

  Future<bool> addEquipment(Map<String, dynamic> data) async {
    try {
      if (data['createdAt'] != null)
        data['createdAt'] = DateTime.now().toIso8601String();
      final response = await http.post(
        Uri.parse('$baseUrl/equipment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addEquipment', e);
      return false;
    }
  }

  Future<List<dynamic>> fetchEquipmentLogs(String equipmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipment_log?equipmentId=$equipmentId'),
      );
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchEquipmentLogs', e);
      return [];
    }
  }

  Future<bool> deleteEquipment(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/equipment/$id'));
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteEquipment', e);
      return false;
    }
  }

  Future<bool> deleteEquipmentLog(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/equipment_log/$id'),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteEquipmentLog', e);
      return false;
    }
  }

  // --- Inventory ---
  Stream<List<dynamic>> streamInventory() =>
      _createPollingStream(fetchInventory).asBroadcastStream();

  Future<List<dynamic>> fetchInventory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/inventory'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchInventory', e);
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
      _logError('updateInventoryItem', e);
      return false;
    }
  }

  Future<bool> addInventoryLog(Map<String, dynamic> logData) async {
    try {
      if (logData['date'] != null)
        logData['date'] = logData['date'].toIso8601String();
      final response = await http.post(
        Uri.parse('$baseUrl/inventory_log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(logData),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addInventoryLog', e);
      return false;
    }
  }

  Future<bool> addInventoryItem(Map<String, dynamic> data) async {
    try {
      if (data['createdAt'] != null)
        data['createdAt'] = DateTime.now().toIso8601String();
      final response = await http.post(
        Uri.parse('$baseUrl/inventory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addInventoryItem', e);
      return false;
    }
  }

  Future<List<dynamic>> fetchInventoryLogs(String itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory_log?itemId=$itemId'),
      );
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchInventoryLogs', e);
      return [];
    }
  }

  Future<bool> deleteInventoryItem(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/inventory/$id'));
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteInventoryItem', e);
      return false;
    }
  }

  // --- Trainings ---
  Stream<List<dynamic>> streamTrainings() =>
      _createPollingStream(fetchTrainings).asBroadcastStream();

  Future<List<dynamic>> fetchTrainings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/trainings'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchTrainings', e);
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
      _logError('addTraining', e);
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
      _logError('updateTraining', e);
      return false;
    }
  }

  Future<bool> deleteTraining(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/trainings/$id'));
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteTraining', e);
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
      _logError('fetchSteps', e);
      return [];
    }
  }

  Stream<List<dynamic>> streamSteps(String trainingId) =>
      _createPollingStream(() => fetchSteps(trainingId)).asBroadcastStream();

  Future<bool> addTrainingStep(
    String trainingId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trainings/$trainingId/steps'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addTrainingStep', e);
      return false;
    }
  }

  Future<bool> updateTrainingStep(
    String trainingId,
    String stepId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trainings/$trainingId/steps/$stepId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('updateTrainingStep', e);
      return false;
    }
  }

  Future<bool> deleteTrainingStep(String trainingId, String stepId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trainings/$trainingId/steps/$stepId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteTrainingStep', e);
      return false;
    }
  }

  // --- Results ---
  Future<List<dynamic>> fetchResults({String? traineeUid}) async {
    try {
      String url = '$baseUrl/results';
      if (traineeUid != null) url += '?traineeUid=$traineeUid';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchResults', e);
      return [];
    }
  }

  Future<bool> addResult(Map<String, dynamic> resultData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/results'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(resultData),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addResult', e);
      return false;
    }
  }

  // --- Daily Notes ---
  Future<List<dynamic>> fetchDailyNotes({String? traineeUid}) async {
    try {
      String url = '$baseUrl/daily_notes';
      if (traineeUid != null) url += '?traineeUid=$traineeUid';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchDailyNotes', e);
      return [];
    }
  }

  Future<bool> addDailyNote(Map<String, dynamic> noteData) async {
    try {
      if (noteData['date'] != null && noteData['date'] is DateTime) {
        noteData['date'] = (noteData['date'] as DateTime).toIso8601String();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/daily_notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(noteData),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addDailyNote', e);
      return false;
    }
  }

  Future<bool> updateDailyNote(String id, Map<String, dynamic> updates) async {
    try {
      if (updates['date'] != null && updates['date'] is DateTime) {
        updates['date'] = (updates['date'] as DateTime).toIso8601String();
      }
      final response = await http.put(
        Uri.parse('$baseUrl/daily_notes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('updateDailyNote', e);
      return false;
    }
  }

  Future<bool> deleteDailyNote(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/daily_notes/$id'));
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteDailyNote', e);
      return false;
    }
  }

  // --- Competitions ---
  Stream<List<dynamic>> streamCompetitions() =>
      _createPollingStream(fetchCompetitions).asBroadcastStream();

  Future<List<dynamic>> fetchCompetitions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/competitions'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchCompetitions', e);
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
      return response.statusCode == 200;
    } catch (e) {
      _logError('addCompetition', e);
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
      return response.statusCode == 200;
    } catch (e) {
      _logError('updateCompetition', e);
      return false;
    }
  }

  Future<bool> deleteCompetition(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/competitions/$id'),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('deleteCompetition', e);
      return false;
    }
  }

  Stream<List<dynamic>> streamCompetitionEntries(String competitionId) =>
      _createPollingStream(
        () => fetchCompetitionEntries(competitionId),
      ).asBroadcastStream();

  Future<List<dynamic>> fetchCompetitionEntries(String competitionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/competition_entries?competitionId=$competitionId'),
      );
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchCompetitionEntries', e);
      return [];
    }
  }

  Future<bool> addCompetitionEntry(Map<String, dynamic> entryData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/competition_entries'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(entryData),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addCompetitionEntry', e);
      return false;
    }
  }

  // --- Schedule ---
  Stream<List<dynamic>> streamSchedule({required String traineeId}) =>
      _createPollingStream(() => fetchSchedule(traineeId)).asBroadcastStream();

  Future<List<dynamic>> fetchSchedule(String traineeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schedule?traineeId=$traineeId'),
      );
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
      _logError('fetchSchedule', e);
      return [];
    }
  }

  Future<bool> addScheduleEvent(Map<String, dynamic> eventData) async {
    try {
      if (eventData['startTime'] != null)
        eventData['startTime'] = eventData['startTime'].toIso8601String();
      if (eventData['endTime'] != null)
        eventData['endTime'] = eventData['endTime'].toIso8601String();
      final response = await http.post(
        Uri.parse('$baseUrl/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(eventData),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('addScheduleEvent', e);
      return false;
    }
  }

  // --- Favorites ---
  Stream<List<dynamic>> streamUserFavorites(String trainerId) =>
      _createPollingStream(
        () => fetchUserFavorites(trainerId),
      ).asBroadcastStream();

  Future<List<dynamic>> fetchUserFavorites(String trainerId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/user_favorites?trainerId=$trainerId'),
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
      if (isFavorite && docId != null) {
        await http.delete(Uri.parse('$baseUrl/user_favorites/$docId'));
      } else {
        await http.post(
          Uri.parse('$baseUrl/user_favorites'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'trainerId': trainerId, 'trainingId': trainingId}),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<List<dynamic>> streamUserFavoriteCompetitions(String trainerId) =>
      _createPollingStream(
        () => fetchUserFavoriteCompetitions(trainerId),
      ).asBroadcastStream();

  Future<List<dynamic>> fetchUserFavoriteCompetitions(String trainerId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/user_favorite_competitions?trainerId=$trainerId'),
      );
      if (res.statusCode == 200)
        return List<dynamic>.from(json.decode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- Progress ---
  Stream<List<dynamic>> streamStepProgress(String userId, String trainingId) =>
      _createPollingStream(
        () => fetchStepProgress(userId, trainingId),
      ).asBroadcastStream();

  Future<List<dynamic>> fetchStepProgress(
    String userId,
    String trainingId,
  ) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/step_progress?userId=$userId&trainingId=$trainingId',
        ),
      );
      if (res.statusCode == 200)
        return List<dynamic>.from(json.decode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> setStepProgress(
    String userId,
    String trainingId,
    String stepId,
    bool isCompleted,
  ) async {
    try {
      if (isCompleted) {
        await http.post(
          Uri.parse('$baseUrl/step_progress'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'trainingId': trainingId,
            'stepId': stepId,
            'completedAt': DateTime.now().toIso8601String(),
          }),
        );
      } else {
        await http.delete(
          Uri.parse('$baseUrl/step_progress'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'trainingId': trainingId,
            'stepId': stepId,
          }),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Misc ---
  Stream<Map<String, dynamic>> streamAppConfig() =>
      _createPollingStream(fetchAppConfig).asBroadcastStream();

  Future<Map<String, dynamic>> fetchAppConfig() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/app_config'));
      if (response.statusCode == 200) return json.decode(response.body);
      return {'isEnabled': true, 'forceUpdate': false};
    } catch (e) {
      return {'isEnabled': true, 'forceUpdate': false};
    }
  }

  Future<bool> updateAppConfig(Map<String, dynamic> config) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/app_config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(config),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchUser(String uid) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/$uid'));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> fetchOrgNodes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/org_nodes'));
      if (response.statusCode == 200)
        return List<dynamic>.from(json.decode(response.body));
      return [];
    } catch (e) {
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
      return response.statusCode == 200;
    } catch (e) {
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
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteOrgNode(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/org_nodes/$id'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
