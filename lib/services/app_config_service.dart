import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfig {
  final bool isAppActive;
  final String forceUpdateVersion;
  final String updateUrl;

  const AppConfig({
    required this.isAppActive,
    required this.forceUpdateVersion,
    required this.updateUrl,
  });

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    return AppConfig(
      isAppActive: (data['isAppActive'] as bool?) ?? true,
      forceUpdateVersion: (data['forceUpdateVersion'] as String?) ?? '1.0.0',
      updateUrl: (data['updateUrl'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'isAppActive': isAppActive,
    'forceUpdateVersion': forceUpdateVersion,
    'updateUrl': updateUrl,
  };
}

class AppConfigService {
  static const String _collection = 'app_config';
  static const String _docId = 'config';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<AppConfig?> fetch() async {
    final doc = await _db.collection(_collection).doc(_docId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return AppConfig.fromMap(data);
  }

  Future<void> setIsAppActive(bool value) async {
    await _db.collection(_collection).doc(_docId).set({
      'isAppActive': value,
    }, SetOptions(merge: true));
  }

  Future<void> setForceUpdateVersion(String version) async {
    await _db.collection(_collection).doc(_docId).set({
      'forceUpdateVersion': version,
    }, SetOptions(merge: true));
  }

  Future<void> setUpdateUrl(String url) async {
    await _db.collection(_collection).doc(_docId).set({
      'updateUrl': url,
    }, SetOptions(merge: true));
  }
}
