import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/services/offline_outbox_service.dart';

class OfflineSyncService {
  OfflineSyncService._();

  static final OfflineSyncService instance = OfflineSyncService._();

  final ApiService _apiService = ApiService();
  bool _isSyncing = false;

  Future<void> syncPendingMutations() async {
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      final connectivity = await _apiService.testServerConnectivity();
      if (connectivity['success'] != true) {
        return;
      }

      final pending = await OfflineOutboxService.instance.getPendingMutations();
      for (final mutation in pending) {
        final synced = await _syncMutation(mutation);
        if (synced) {
          await OfflineOutboxService.instance.remove(mutation.id);
          continue;
        }

        await OfflineOutboxService.instance.replace(
          mutation.copyWith(
            attemptCount: mutation.attemptCount + 1,
            lastError: 'SYNC_FAILED',
          ),
        );
        break;
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncMutation(PendingOfflineMutation mutation) {
    switch (mutation.type) {
      case OfflineMutationType.addResult:
        return _apiService.addResult(mutation.payload);
      case OfflineMutationType.addDailyNote:
        return _apiService.addDailyNote(mutation.payload);
      case OfflineMutationType.addCompetitionEntry:
        return _apiService.addCompetitionEntry(mutation.payload);
    }
  }
}
