import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum OfflineMutationType { addResult, addDailyNote, addCompetitionEntry }

class PendingOfflineMutation {
  PendingOfflineMutation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastError,
  });

  final String id;
  final OfflineMutationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attemptCount;
  final String? lastError;

  PendingOfflineMutation copyWith({int? attemptCount, String? lastError}) {
    return PendingOfflineMutation(
      id: id,
      type: type,
      payload: Map<String, dynamic>.from(payload),
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'attemptCount': attemptCount,
      'lastError': lastError,
    };
  }

  factory PendingOfflineMutation.fromJson(Map<String, dynamic> json) {
    return PendingOfflineMutation(
      id: json['id'] as String,
      type: OfflineMutationType.values.firstWhere(
        (value) => value.name == json['type'],
      ),
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? <String, dynamic>{},
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      attemptCount: json['attemptCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

class OfflineOutboxService {
  OfflineOutboxService._();

  static final OfflineOutboxService instance = OfflineOutboxService._();
  static const String _storageKey = 'offline_outbox_v1';
  static final Random _random = Random();

  Future<List<PendingOfflineMutation>> getPendingMutations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => PendingOfflineMutation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<PendingOfflineMutation> enqueue({
    required OfflineMutationType type,
    required Map<String, dynamic> payload,
  }) async {
    final entry = PendingOfflineMutation(
      id: _generateId(),
      type: type,
      payload: Map<String, dynamic>.from(payload),
      createdAt: DateTime.now(),
    );

    final items = await getPendingMutations();
    items.add(entry);
    await _save(items);
    return entry;
  }

  Future<void> remove(String id) async {
    final items = await getPendingMutations();
    items.removeWhere((item) => item.id == id);
    await _save(items);
  }

  Future<void> replace(PendingOfflineMutation mutation) async {
    final items = await getPendingMutations();
    final index = items.indexWhere((item) => item.id == mutation.id);
    if (index == -1) {
      items.add(mutation);
    } else {
      items[index] = mutation;
    }
    await _save(items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _save(List<PendingOfflineMutation> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1 << 32).toRadixString(16);
    return 'offline_$timestamp\_$randomPart';
  }
}
