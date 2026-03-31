import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../reporting/report_repository.dart';
import 'offline_queue_service.dart';

class OfflineSyncService {
  OfflineSyncService._();

  static final OfflineSyncService instance = OfflineSyncService._();

  final OfflineQueueService _queue = OfflineQueueService.instance;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _running = false;

  Future<void> start({required ReportRepository repository}) async {
    await syncPending(repository: repository);

    _subscription ??= Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (_isOnline(results)) {
        syncPending(repository: repository);
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> syncPending({required ReportRepository repository}) async {
    if (_running) {
      return;
    }
    _running = true;

    try {
      final List<ConnectivityResult> connectivity = await Connectivity()
          .checkConnectivity();
      if (!_isOnline(connectivity)) {
        return;
      }

      final pending = await _queue.pendingReports();
      for (final item in pending) {
        if (item.id == null) {
          continue;
        }
        try {
          final File image = File(item.imagePath);
          if (!await image.exists()) {
            await _queue.deleteById(item.id!);
            continue;
          }

          final String imageUrl = await repository.uploadReportImage(
            image,
            item.reporterId,
          );

          await repository.submitOrMergeReport(
            category: item.category,
            description: item.description,
            imageUrl: imageUrl,
            latitude: item.latitude,
            longitude: item.longitude,
            reporterId: item.reporterId,
          );

<<<<<<< HEAD
=======
          if (await image.exists()) {
            await image.delete();
          }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
          await _queue.deleteById(item.id!);
        } catch (_) {
          // Keep queued item for next sync attempt.
        }
      }
    } finally {
      _running = false;
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((ConnectivityResult result) {
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet;
    });
  }
}
