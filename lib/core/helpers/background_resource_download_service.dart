import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'background_download_runtime.dart';

/// A safe, persistent download used for app resources and user-requested media.
/// Native transfers continue while the app is backgrounded and report progress
/// through the same service notification and callback path.
class BackgroundResourceDownloadService {
  BackgroundResourceDownloadService._();

  static final BackgroundResourceDownloadService instance =
      BackgroundResourceDownloadService._();

  static const String group = 'ibad_resource_downloads';

  final Map<String, _PendingDownload> _pendingByLogicalId = {};
  final Map<String, _PendingDownload> _pendingByTaskId = {};
  Future<void>? _prepareFuture;
  bool _callbacksRegistered = false;
  bool _groupTracked = false;
  int _taskSequence = 0;

  Future<void> prepare() {
    final current = _prepareFuture;
    if (current != null) return current;
    final future = _prepareInternal().catchError((
      Object error,
      StackTrace stack,
    ) {
      _prepareFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
    _prepareFuture = future;
    return future;
  }

  Future<void> _prepareInternal() async {
    final downloader = FileDownloader();
    if (!_callbacksRegistered) {
      downloader.registerCallbacks(
        group: group,
        taskStatusCallback: _onTaskStatus,
        taskProgressCallback: _onTaskProgress,
      );
      downloader.configureNotificationForGroup(
        group,
        running: const TaskNotification(
          'جارٍ تنزيل ملف',
          '{displayName} · {progress}',
        ),
        complete: const TaskNotification('اكتمل تنزيل الملف', '{displayName}'),
        error: const TaskNotification('تعذّر تنزيل الملف', '{displayName}'),
        canceled: const TaskNotification('أُلغي تنزيل الملف', '{displayName}'),
        progressBar: true,
      );
      _callbacksRegistered = true;
    }

    await BackgroundDownloadRuntime.ensureStarted();
    if (!_groupTracked) {
      await downloader.trackTasksInGroup(group, markDownloadedComplete: true);
      _groupTracked = true;
    }
  }

  /// Downloads to an absolute app-owned path. The destination is translated to
  /// a stable path_provider base directory so the native task can safely resume.
  Future<String> downloadToPath({
    required String id,
    required String url,
    required String destinationPath,
    required String displayName,
    Map<String, String>? headers,
    int retries = 2,
    void Function(double progress)? onProgress,
  }) async {
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id');
    final destination = await _resolveDestination(destinationPath);
    await prepare();

    final alreadyPending = _pendingByLogicalId[id];
    if (alreadyPending != null) {
      if (alreadyPending.destinationPath != destination.absolutePath) {
        throw StateError('A different download already uses this id.');
      }
      return alreadyPending.completer.future;
    }

    final downloader = FileDownloader();
    final previous = await _latestRecord(id, destination.absolutePath);
    if (previous != null && previous.status == TaskStatus.complete) {
      final previousPath = await previous.task.filePath();
      final previousFile = File(previousPath);
      if (await previousFile.exists() && await previousFile.length() > 0) {
        _notifyProgress(onProgress, 1);
        return previousPath;
      }
      await downloader.database.deleteRecordWithId(previous.taskId);
    }

    DownloadTask task;
    var needsEnqueue = true;
    if (previous != null &&
        previous.task is DownloadTask &&
        _isReusableActiveStatus(previous.status)) {
      task = previous.task as DownloadTask;
      needsEnqueue = false;
    } else {
      if (previous != null) {
        await downloader.database.deleteRecordWithId(previous.taskId);
        final oldPath = await previous.task.filePath();
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (_) {
            // A stale partial file must not block a fresh task.
          }
        }
      }
      task = buildTask(
        taskId: _nextTaskId(),
        id: id,
        url: url,
        filename: destination.filename,
        directory: destination.directory,
        baseDirectory: destination.baseDirectory,
        displayName: displayName,
        headers: headers,
        retries: retries,
      );
    }

    final pending = _PendingDownload(
      id: id,
      task: task,
      destinationPath: destination.absolutePath,
      onProgress: onProgress,
    );
    _pendingByLogicalId[id] = pending;
    _pendingByTaskId[task.taskId] = pending;
    _notifyProgress(onProgress, 0);

    try {
      if (needsEnqueue) {
        final enqueued = await downloader.enqueue(task);
        if (!enqueued) {
          throw const BackgroundResourceDownloadException(
            'تعذّر بدء تنزيل الملف.',
          );
        }
      } else {
        // Catch a completion that raced with restoring the existing task.
        final refreshed = await _latestRecord(id, destination.absolutePath);
        if (refreshed?.status == TaskStatus.complete) {
          await _finishPending(pending, refreshed!.task);
        } else if (refreshed?.status == TaskStatus.paused) {
          final resumed = await downloader.resume(task);
          if (!resumed) {
            throw const BackgroundResourceDownloadException(
              'تعذّر استئناف تنزيل الملف.',
            );
          }
        }
      }
    } catch (error, stackTrace) {
      _failPending(
        pending,
        error is BackgroundResourceDownloadException
            ? error
            : const BackgroundResourceDownloadException(
                'تعذّر بدء تنزيل الملف.',
              ),
        stackTrace,
      );
    }

    return pending.completer.future;
  }

  /// Returns a completed download path after process restoration, if present.
  Future<String?> completedPathFor(String id) async {
    await prepare();
    final record = await _latestRecord(id);
    if (record?.status != TaskStatus.complete) return null;
    final path = await record!.task.filePath();
    final file = File(path);
    return await file.exists() && await file.length() > 0 ? path : null;
  }

  Future<bool> cancel(String id) async {
    final downloader = FileDownloader();
    final pending = _pendingByLogicalId[id];
    if (pending != null) return downloader.cancel(pending.task);
    await prepare();
    final record = await _latestRecord(id);
    if (record == null || !_isReusableActiveStatus(record.status)) return false;
    return downloader.cancelTaskWithId(record.taskId);
  }

  @visibleForTesting
  static DownloadTask buildTask({
    required String taskId,
    required String id,
    required String url,
    required String filename,
    required String? directory,
    required BaseDirectory baseDirectory,
    required String displayName,
    Map<String, String>? headers,
    int retries = 2,
  }) {
    return DownloadTask(
      taskId: taskId,
      url: url,
      filename: filename,
      directory: directory ?? '',
      baseDirectory: baseDirectory,
      group: group,
      updates: Updates.statusAndProgress,
      retries: retries,
      allowPause: true,
      metaData: id,
      displayName: displayName,
      headers: headers,
    );
  }

  String _nextTaskId() {
    _taskSequence++;
    return 'resource_${DateTime.now().microsecondsSinceEpoch}_$_taskSequence';
  }

  Future<TaskRecord?> _latestRecord(
    String id, [
    String? destinationPath,
  ]) async {
    final records = await FileDownloader().database.allRecords(group: group);
    final matching =
        records.where((record) => record.task.metaData == id).toList()..sort(
          (left, right) =>
              right.task.creationTime.compareTo(left.task.creationTime),
        );
    for (final record in matching) {
      if (destinationPath == null) return record;
      final path = await record.task.filePath();
      if (p.normalize(p.absolute(path)) == destinationPath) return record;
    }
    return null;
  }

  bool _isReusableActiveStatus(TaskStatus status) =>
      status == TaskStatus.enqueued ||
      status == TaskStatus.running ||
      status == TaskStatus.waitingToRetry ||
      status == TaskStatus.paused;

  void _onTaskStatus(TaskStatusUpdate update) {
    final pending = _pendingByTaskId[update.task.taskId];
    if (pending == null) return;
    switch (update.status) {
      case TaskStatus.complete:
        unawaited(_finishPending(pending, update.task));
        break;
      case TaskStatus.failed:
      case TaskStatus.notFound:
        _failPending(
          pending,
          const BackgroundResourceDownloadException(
            'فشل تنزيل الملف. تحقق من الاتصال بالإنترنت ثم حاول مرة أخرى.',
          ),
        );
        break;
      case TaskStatus.canceled:
        _failPending(
          pending,
          const BackgroundResourceDownloadException(
            'تم إلغاء تنزيل الملف.',
            wasCancelled: true,
          ),
        );
        break;
      case TaskStatus.enqueued:
      case TaskStatus.running:
      case TaskStatus.waitingToRetry:
      case TaskStatus.paused:
        break;
    }
  }

  void _onTaskProgress(TaskProgressUpdate update) {
    final pending = _pendingByTaskId[update.task.taskId];
    if (pending == null || update.progress < 0) return;
    _notifyProgress(
      pending.onProgress,
      update.progress.clamp(0.0, 1.0).toDouble(),
    );
  }

  Future<void> _finishPending(_PendingDownload pending, Task task) async {
    if (pending.completer.isCompleted) return;
    try {
      final path = await task.filePath();
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw const BackgroundResourceDownloadException(
          'اكتمل التنزيل دون إنشاء ملف صالح.',
        );
      }
      _removePending(pending);
      _notifyProgress(pending.onProgress, 1);
      pending.completer.complete(path);
    } catch (error, stackTrace) {
      _failPending(
        pending,
        error is BackgroundResourceDownloadException
            ? error
            : const BackgroundResourceDownloadException(
                'تعذّر الوصول إلى الملف الذي تم تنزيله.',
              ),
        stackTrace,
      );
    }
  }

  void _failPending(
    _PendingDownload pending,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (pending.completer.isCompleted) return;
    _removePending(pending);
    pending.completer.completeError(error, stackTrace);
  }

  void _removePending(_PendingDownload pending) {
    if (identical(_pendingByLogicalId[pending.id], pending)) {
      _pendingByLogicalId.remove(pending.id);
    }
    if (identical(_pendingByTaskId[pending.task.taskId], pending)) {
      _pendingByTaskId.remove(pending.task.taskId);
    }
  }

  void _notifyProgress(
    void Function(double progress)? callback,
    double progress,
  ) {
    try {
      callback?.call(progress);
    } catch (_) {
      // A closed screen must not interrupt a native background transfer.
    }
  }

  Future<_DownloadDestination> _resolveDestination(String path) async {
    final absolutePath = p.normalize(p.absolute(path));
    final roots = <(BaseDirectory, Directory)>[
      (
        BaseDirectory.applicationDocuments,
        await getApplicationDocumentsDirectory(),
      ),
      (
        BaseDirectory.applicationSupport,
        await getApplicationSupportDirectory(),
      ),
      (BaseDirectory.temporary, await getTemporaryDirectory()),
    ];
    for (final (baseDirectory, root) in roots) {
      final absoluteRoot = p.normalize(p.absolute(root.path));
      if (!p.isWithin(absoluteRoot, absolutePath)) continue;
      final relative = p.relative(absolutePath, from: absoluteRoot);
      final filename = p.basename(relative);
      final relativeDirectory = p.dirname(relative);
      if (filename.isEmpty || relative == '..' || p.isAbsolute(relative)) {
        break;
      }
      return _DownloadDestination(
        absolutePath: absolutePath,
        baseDirectory: baseDirectory,
        directory: relativeDirectory == '.' ? null : relativeDirectory,
        filename: filename,
      );
    }
    throw ArgumentError.value(
      path,
      'destinationPath',
      'Must be inside the application documents, support, or temporary directory.',
    );
  }
}

class BackgroundResourceDownloadException implements Exception {
  const BackgroundResourceDownloadException(
    this.message, {
    this.wasCancelled = false,
  });

  final String message;
  final bool wasCancelled;

  @override
  String toString() => message;
}

class _PendingDownload {
  _PendingDownload({
    required this.id,
    required this.task,
    required this.destinationPath,
    this.onProgress,
  });

  final String id;
  final Task task;
  final String destinationPath;
  final void Function(double progress)? onProgress;
  final Completer<String> completer = Completer<String>();
}

class _DownloadDestination {
  const _DownloadDestination({
    required this.absolutePath,
    required this.baseDirectory,
    required this.filename,
    required this.directory,
  });

  final String absolutePath;
  final BaseDirectory baseDirectory;
  final String filename;
  final String? directory;
}
