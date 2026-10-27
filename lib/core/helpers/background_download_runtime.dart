import 'package:background_downloader/background_downloader.dart';

/// Coordinates the package-wide downloader startup so independently-owned
/// download groups do not start competing native schedulers.
class BackgroundDownloadRuntime {
  BackgroundDownloadRuntime._();

  static Future<void>? _startFuture;

  static Future<void> ensureStarted() {
    final current = _startFuture;
    if (current != null) return current;

    final future = FileDownloader()
        .start(
          doTrackTasks: true,
          markDownloadedComplete: true,
          doRescheduleKilledTasks: true,
          autoCleanDatabase: false,
        )
        .catchError((Object error, StackTrace stackTrace) {
          _startFuture = null;
          Error.throwWithStackTrace(error, stackTrace);
        });
    _startFuture = future;
    return future;
  }
}
