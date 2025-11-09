import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String minVersionKey = 'forceUpdateVersion';

  Future<bool> isUpdateRequired() async {
    try {
      print('🔍 Starting update check...');
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values in case fetch fails
      await remoteConfig.setDefaults({minVersionKey: '1.0.0'});
      print('✅ Default values set');

      // Set config settings
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero, // For testing, fetch immediately
        ),
      );
      print('✅ Config settings applied');

      // Fetch and activate with timeout
      print('📡 Fetching from Remote Config...');
      final activated = await remoteConfig.fetchAndActivate().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Fetch timeout, using cached/default values');
          return false;
        },
      );
      print('✅ Fetch and activate completed: $activated');

      final minVersion = remoteConfig.getString(minVersionKey);
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      print('📱 Current version: $currentVersion');
      print('🔒 Min required: $minVersion');

      final needsUpdate = _compareVersions(currentVersion, minVersion) < 0;
      print('⚠️ Update required: $needsUpdate');

      return needsUpdate;
    } catch (e) {
      print('❌ Error checking update: $e');
      // If there's an error, don't force update
      return false;
    }
  }

  int _compareVersions(String v1, String v2) {
    try {
      final a = v1.split('.').map(int.parse).toList();
      final b = v2.split('.').map(int.parse).toList();
      for (int i = 0; i < a.length && i < b.length; i++) {
        if (a[i] != b[i]) return a[i].compareTo(b[i]);
      }
      return a.length.compareTo(b.length);
    } catch (e) {
      print('Error comparing versions: $e');
      return 0;
    }
  }
}
