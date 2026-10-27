import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_logger.dart';
import 'background_download_runtime.dart';
import 'feature_resource_repository.dart';
import 'mushaf_pagination.dart';

const _githubResourceRoot =
    'https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/source/import-qul-resources/';
const _releasePackageUrls = <String, String>{
  'qpc_v2_1421':
      'https://github.com/yousofahmad/ibad-alrahman-features/releases/download/qpc-layouts-v1/qpc_v2_1421.zip',
  'qpc_v4_tajweed_1441':
      'https://github.com/yousofahmad/ibad-alrahman-features/releases/download/qpc-layouts-v1/qpc_v4_tajweed_1441.zip',
};

class MushafFormat {
  final String id;
  final String name;
  final String description;
  final int pageCount;
  final int lineCount;
  final bool hasTajweed;
  final bool isBuiltin;
  final bool paginationMatchesBuiltin;
  final bool wordAlignmentMatchesBuiltin;
  final String? packageUrl;
  final String? sha256;
  final int? sizeBytes;
  final bool compatible;
  final String? navigationIndexFile;
  final String? navigationIndexSha256;
  final String fontMode;
  final String? licenseSha256;

  const MushafFormat({
    required this.id,
    required this.name,
    required this.description,
    required this.pageCount,
    required this.lineCount,
    required this.hasTajweed,
    required this.isBuiltin,
    this.paginationMatchesBuiltin = false,
    this.wordAlignmentMatchesBuiltin = false,
    required this.packageUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.compatible,
    required this.navigationIndexFile,
    required this.navigationIndexSha256,
    this.fontMode = 'page_glyph',
    this.licenseSha256,
  });

  static const _arabicDisplayNames = <String, String>{
    'qpc_v1_builtin': 'مصحف المدينة المنورة (1405هـ)',
    'qpc_v2_1421': 'مصحف المدينة المنورة (1421هـ)',
    'qpc_v4_tajweed_1441': 'مصحف التجويد الملوّن (1441هـ)',
    'digital_khatt_v2': 'الخط الرقمي — الإصدار الثاني',
  };

  String get displayName => _arabicDisplayNames[id] ?? name;

  bool get isUnicodeFont => fontMode == 'unicode_single';

  static const builtin = MushafFormat(
    id: 'qpc_v1_builtin',
    name: 'المصحف الحالي',
    description: 'المصحف الأصلي المضمّن في التطبيق — إصدار 1405هـ',
    pageCount: 604,
    lineCount: 15,
    hasTajweed: false,
    isBuiltin: true,
    paginationMatchesBuiltin: true,
    wordAlignmentMatchesBuiltin: true,
    packageUrl: null,
    sha256: null,
    sizeBytes: null,
    compatible: true,
    navigationIndexFile: null,
    navigationIndexSha256: null,
    fontMode: 'page_glyph',
    licenseSha256: null,
  );

  factory MushafFormat.fromJson(Map<String, dynamic> json) {
    final pageCount = _int(json['page_count']);
    final lineCount = _int(json['line_count']);
    final hash = json['sha256']?.toString();
    final id = json['id']?.toString() ?? '';
    final url = json['package_url']?.toString();
    final validId = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(id);
    final validUrl = _isAllowedPackageUrl(id, url);
    final validHash =
        hash != null && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash);
    final indexFile = json['navigation_index_file']?.toString();
    final indexHash = json['navigation_index_sha256']?.toString();
    final fontMode = json['font_mode']?.toString() ?? 'page_glyph';
    final licenseSha256 = json['license_sha256']?.toString();
    final pageSplitMatches = json['pagination_matches_builtin'] == true;
    final wordAlignmentMatches = json['word_alignment_matches_builtin'] == true;
    final validIndexHash =
        indexFile == 'pagination.json' &&
        indexHash != null &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(indexHash);
    final validNavigation = indexFile == null
        ? pageSplitMatches && wordAlignmentMatches && indexHash == null
        : validIndexHash && wordAlignmentMatches;
    final validMode = fontMode == 'page_glyph' || fontMode == 'unicode_single';
    final validLicense =
        licenseSha256 != null &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(licenseSha256);
    return MushafFormat(
      id: id,
      name: json['name']?.toString() ?? id,
      description: json['description']?.toString() ?? '',
      pageCount: pageCount,
      lineCount: lineCount,
      hasTajweed: json['has_tajweed'] == true,
      isBuiltin: false,
      paginationMatchesBuiltin: pageSplitMatches,
      wordAlignmentMatchesBuiltin: wordAlignmentMatches,
      packageUrl: url,
      sha256: hash,
      sizeBytes: _nullableInt(json['size_bytes']),
      compatible:
          validNavigation &&
          pageCount == 604 &&
          lineCount == 15 &&
          id.isNotEmpty &&
          id != builtin.id &&
          validId &&
          validUrl &&
          validHash &&
          validMode &&
          (fontMode == 'page_glyph' || validLicense) &&
          (fontMode != 'unicode_single' || wordAlignmentMatches),
      navigationIndexFile: indexFile,
      navigationIndexSha256: indexHash,
      fontMode: fontMode,
      licenseSha256: licenseSha256,
    );
  }

  static int _int(dynamic value) => int.tryParse('$value') ?? 0;
  static int? _nullableInt(dynamic value) => value == null ? null : _int(value);
}

enum MushafDownloadPhase { queued, downloading, verifying }

class MushafDownloadDetails {
  final double? progress;
  final int downloadedBytes;
  final int? totalBytes;
  final double? speedBytesPerSecond;
  final Duration? timeRemaining;
  final MushafDownloadPhase phase;

  const MushafDownloadDetails({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSecond,
    required this.timeRemaining,
    required this.phase,
  });
}

class MushafDownloadCancelledException implements Exception {
  const MushafDownloadCancelledException();
}

class MushafFormatRepository extends ChangeNotifier {
  static final MushafFormatRepository instance = MushafFormatRepository();
  static const _selectedKey = 'mushaf_selected_format';
  static const _catalogKey = 'mushaf_catalog_json';
  static const _remoteRoot = _githubResourceRoot;
  // Older clients keep their two page-glyph formats at catalog.json; they
  // must not be offered a single-font package they cannot install.
  static const _remoteCatalog = '${_remoteRoot}mushaf/catalog-v2.json';
  static const _maxZipBytes = 200 * 1024 * 1024;
  static const _backgroundDownloadGroup = 'mushaf_format_downloads';

  final SharedPreferences? _providedPreferences;
  final Directory? _providedDocumentsDirectory;
  final Dio _dio;
  final FeatureResourceRepository _resources;
  SharedPreferences? _preferences;
  Directory? _documentsDirectory;
  bool _initialized = false;
  Future<void>? _initializeFuture;
  MushafFormat _current = MushafFormat.builtin;
  List<MushafFormat> _formats = const [MushafFormat.builtin];
  final ValueNotifier<int> selectionRevision = ValueNotifier<int>(0);
  final Set<String> _downloading = <String>{};
  final Map<String, double> _progress = <String, double>{};
  final Map<String, MushafDownloadPhase> _downloadPhases =
      <String, MushafDownloadPhase>{};
  final Map<String, int> _downloadedBytes = <String, int>{};
  final Map<String, int> _downloadTotalBytes = <String, int>{};
  final Map<String, double> _downloadSpeedBytesPerSecond = <String, double>{};
  final Map<String, Duration> _downloadTimeRemaining = <String, Duration>{};
  final Map<String, DownloadTask> _backgroundTasks = <String, DownloadTask>{};
  final Map<String, Completer<String>> _downloadCompletions =
      <String, Completer<String>>{};
  final Set<String> _recoveredInstallsInFlight = <String>{};
  Future<void>? _backgroundDownloaderFuture;
  final Map<String, Future<void>> _inflight = <String, Future<void>>{};
  final Set<String> _validatedInstalled = <String>{};

  MushafFormatRepository({
    SharedPreferences? preferences,
    Directory? documentsDirectory,
    Dio? dio,
    FeatureResourceRepository? resourceRepository,
  }) : _providedPreferences = preferences,
       _providedDocumentsDirectory = documentsDirectory,
       _dio = dio ?? Dio(),
       _resources = resourceRepository ?? FeatureResourceRepository.configured;

  MushafFormat get current => _current;
  MushafFormat get getcurrent => current;
  MushafFormat get currentFormat => current;
  List<MushafFormat> get formats => List.unmodifiable(_formats);
  List<MushafFormat> get getformats => formats;
  bool get initialized => _initialized;
  // Full file validation is asynchronous at initialize/install/select time;
  // drawing a progress update must not synchronously stat all 604 fonts.
  bool isInstalled(String id) =>
      id == MushafFormat.builtin.id || _validatedInstalled.contains(id);

  bool isDownloading(String id) => _downloading.contains(id);
  double? downloadProgress(String id) => _progress[id];
  MushafDownloadDetails? downloadDetails(String id) {
    final phase = _downloadPhases[id];
    if (phase == null) return null;
    return MushafDownloadDetails(
      progress: _progress[id],
      downloadedBytes: _downloadedBytes[id] ?? 0,
      totalBytes: _downloadTotalBytes[id],
      speedBytesPerSecond: _downloadSpeedBytesPerSecond[id],
      timeRemaining: _downloadTimeRemaining[id],
      phase: phase,
    );
  }

  String? get getActiveWordsDatabasePath => _databasePath('words.sqlite');
  String? get getActiveLayoutDatabasePath => _databasePath('layout.sqlite');
  String? get getactiveWordsDatabasePath => getActiveWordsDatabasePath;
  String? get getactiveLayoutDatabasePath => getActiveLayoutDatabasePath;
  String? get activeWordsDatabasePath => getActiveWordsDatabasePath;
  String? get activeLayoutDatabasePath => getActiveLayoutDatabasePath;

  String? pageFontPath(int page) {
    if (_current.isBuiltin ||
        page < 1 ||
        page > _current.pageCount ||
        !_validatedInstalled.contains(_current.id)) {
      return null;
    }
    final dir = _directory(_current.id);
    final path = p.join(
      dir.path,
      'fonts',
      _current.fontMode == 'unicode_single' ? 'quran.otf' : 'p$page.ttf',
    );
    return File(path).existsSync() ? path : null;
  }

  String fontFamily(int page) => _current.isBuiltin
      ? 'QCF_V1_P$page'
      : _current.fontMode == 'unicode_single'
      ? '${_fontPrefix(_current)}1'
      : '${_fontPrefix(_current)}$page';

  Future<MushafPaginationIndex?> _readPaginationIndex(
    MushafFormat format,
  ) async {
    if (format.navigationIndexFile == null) return null;
    try {
      final file = File(
        p.join(_directory(format.id).path, format.navigationIndexFile),
      );
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (format.navigationIndexSha256 == null ||
          sha256.convert(bytes).toString().toLowerCase() !=
              format.navigationIndexSha256!.toLowerCase()) {
        return null;
      }
      final index = MushafPaginationIndex.fromString(utf8.decode(bytes));
      if (index.formatId != format.id ||
          index.pageCount != format.pageCount ||
          index.lineCount != format.lineCount) {
        return null;
      }
      return index;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    final started = DateTime.now();
    _log('initialize_start', {'source': 'local_cache'});
    try {
      _preferences =
          _providedPreferences ?? await SharedPreferences.getInstance();
      _documentsDirectory =
          _providedDocumentsDirectory ??
          await getApplicationDocumentsDirectory();
      _formats = _readCatalog(_preferences!.getString(_catalogKey));
      for (final format in _formats.where(
        (f) => !f.isBuiltin && f.compatible,
      )) {
        if (await _validateInstalled(format)) {
          _validatedInstalled.add(format.id);
        }
      }
      final selected = _preferences!.getString(_selectedKey);
      if (selected != null && selected != MushafFormat.builtin.id) {
        final candidate = _formats
            .where((f) => f.id == selected && f.compatible)
            .firstOrNull;
        if (candidate != null && _validatedInstalled.contains(candidate.id)) {
          _current = candidate;
          final index = await _readPaginationIndex(candidate);
          if (candidate.navigationIndexFile != null && index == null) {
            _current = MushafFormat.builtin;
          } else {
            MushafPagination.activate(index);
          }
        }
      }
      _initialized = true;
      _log('initialize_finish', {
        'outcome': 'success',
        'elapsed_ms': _elapsed(started),
      });
    } catch (error) {
      _log('initialize_finish', {
        'outcome': 'failed',
        'reason': error.runtimeType.toString(),
        'elapsed_ms': _elapsed(started),
      });
      rethrow;
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> refreshCatalog() async {
    await initialize();
    final started = DateTime.now();
    _log('catalog_start', {'source': 'local_or_github'});
    try {
      Map<String, dynamic>? value = await _resources.readJson(
        'mushaf/catalog-v2.json',
      );
      value ??= await _resources.readJson('mushaf/catalog.json');
      if (value == null) {
        final response = await _dio.get<String>(
          _remoteCatalog,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          value = jsonDecode(response.data!);
        }
      }
      final parsed = _readCatalogMap(value);
      if (parsed.length > 1) {
        _formats = parsed;
        await _preferences!.setString(
          _catalogKey,
          jsonEncode({
            'schema_version': 1,
            'formats': parsed
                .where((f) => !f.isBuiltin)
                .map(_formatJson)
                .toList(),
          }),
        );
      }
      _log('catalog_finish', {
        'outcome': parsed.length > 1 ? 'success' : 'rejected',
        'elapsed_ms': _elapsed(started),
      });
      notifyListeners();
      if (_backgroundDownloaderFuture != null) {
        unawaited(_restoreBackgroundDownloads());
      }
    } catch (error) {
      _log('catalog_finish', {
        'outcome': 'offline_cache',
        'reason': error.runtimeType.toString(),
        'elapsed_ms': _elapsed(started),
      });
    }
  }

  Future<void> install(String id) {
    final existing = _inflight[id];
    if (existing != null) return existing;
    final future = _install(id);
    _inflight[id] = future;
    return future.whenComplete(() => _inflight.remove(id));
  }

  Future<void> prepareBackgroundDownloads() async {
    try {
      await initialize();
      await _ensureBackgroundDownloader();
      await _restoreBackgroundDownloads();
    } catch (error) {
      _log('background_restore_finish', {
        'outcome': 'failed',
        'reason': error.runtimeType.toString(),
      });
    }
  }

  Future<void> _ensureBackgroundDownloader() async {
    try {
      await (_backgroundDownloaderFuture ??= _startBackgroundDownloader());
    } catch (_) {
      _backgroundDownloaderFuture = null;
      rethrow;
    }
  }

  Future<void> _startBackgroundDownloader() async {
    final downloader = FileDownloader();
    downloader.registerCallbacks(
      group: _backgroundDownloadGroup,
      taskStatusCallback: _onBackgroundTaskStatus,
      taskProgressCallback: _onBackgroundTaskProgress,
    );
    downloader.configureNotification(
      running: const TaskNotification(
        'تنزيل تنسيق المصحف',
        '{displayName} · {progress}',
      ),
      complete: const TaskNotification(
        'اكتمل تنزيل تنسيق المصحف',
        '{displayName}',
      ),
      error: const TaskNotification(
        'تعذّر تنزيل تنسيق المصحف',
        '{displayName}',
      ),
      canceled: const TaskNotification(
        'أُلغي تنزيل تنسيق المصحف',
        '{displayName}',
      ),
      progressBar: true,
    );
    await BackgroundDownloadRuntime.ensureStarted();
    await downloader.trackTasksInGroup(
      _backgroundDownloadGroup,
      markDownloadedComplete: true,
    );
  }

  Future<void> _restoreBackgroundDownloads() async {
    final records = await FileDownloader().database.allRecords(
      group: _backgroundDownloadGroup,
    );
    final latestRecords = <String, TaskRecord>{};
    for (final record in records) {
      final formatId = record.task.metaData;
      final previous = latestRecords[formatId];
      if (previous == null ||
          record.task.creationTime.isAfter(previous.task.creationTime)) {
        latestRecords[formatId] = record;
      }
    }
    for (final entry in latestRecords.entries) {
      final formatId = entry.key;
      final format = _formats.where((item) => item.id == formatId).firstOrNull;
      final record = entry.value;
      if (format == null || !format.compatible || isInstalled(formatId)) {
        await FileDownloader().database.deleteRecordWithId(record.taskId);
        continue;
      }
      if (record.task is! DownloadTask) continue;
      final task = record.task as DownloadTask;
      _backgroundTasks[formatId] = task;
      switch (record.status) {
        case TaskStatus.enqueued:
        case TaskStatus.running:
        case TaskStatus.waitingToRetry:
        case TaskStatus.paused:
          _downloading.add(formatId);
          _progress[formatId] = record.progress.clamp(0.0, 1.0).toDouble();
          _downloadPhases[formatId] =
              record.status == TaskStatus.enqueued ||
                  record.status == TaskStatus.waitingToRetry ||
                  record.status == TaskStatus.paused
              ? MushafDownloadPhase.queued
              : MushafDownloadPhase.downloading;
          final total = record.expectedFileSize > 0
              ? record.expectedFileSize
              : format.sizeBytes;
          if (total != null && total > 0) {
            _downloadTotalBytes[formatId] = total;
            _downloadedBytes[formatId] = (_progress[formatId]! * total).round();
          }
          break;
        case TaskStatus.complete:
          _downloading.add(formatId);
          _progress[formatId] = 1;
          _downloadPhases[formatId] = MushafDownloadPhase.verifying;
          if (!_inflight.containsKey(formatId)) {
            unawaited(_installRecoveredDownload(format, task));
          }
          break;
        case TaskStatus.failed:
        case TaskStatus.notFound:
        case TaskStatus.canceled:
          await _discardBackgroundTask(task);
          break;
      }
    }
    notifyListeners();
  }

  void _onBackgroundTaskProgress(TaskProgressUpdate update) {
    final formatId = update.task.metaData;
    final format = _formats.where((item) => item.id == formatId).firstOrNull;
    if (format == null || !format.compatible || update.progress < 0) return;
    final progress = update.progress.clamp(0.0, 1.0).toDouble();
    _downloading.add(formatId);
    _progress[formatId] = progress;
    _downloadPhases[formatId] = MushafDownloadPhase.downloading;
    final total = update.hasExpectedFileSize
        ? update.expectedFileSize
        : format.sizeBytes;
    if (total != null && total > 0) {
      _downloadTotalBytes[formatId] = total;
      _downloadedBytes[formatId] = (progress * total).round();
    }
    if (update.hasNetworkSpeed) {
      _downloadSpeedBytesPerSecond[formatId] =
          update.networkSpeed * 1024 * 1024;
    }
    if (update.hasTimeRemaining) {
      _downloadTimeRemaining[formatId] = update.timeRemaining;
    }
    notifyListeners();
    if (update.hasExpectedFileSize && update.expectedFileSize > _maxZipBytes) {
      final completion = _downloadCompletions[formatId];
      if (completion != null && !completion.isCompleted) {
        completion.completeError(StateError('Package too large'));
      }
      final task = _backgroundTasks[formatId];
      if (task != null) unawaited(FileDownloader().cancel(task));
    }
  }

  void _onBackgroundTaskStatus(TaskStatusUpdate update) {
    final formatId = update.task.metaData;
    final format = _formats.where((item) => item.id == formatId).firstOrNull;
    if (format == null || !format.compatible) return;
    _log('download_status', {
      'id': formatId,
      'status': update.status.name,
      'trigger': 'background_callback',
    });
    switch (update.status) {
      case TaskStatus.enqueued:
      case TaskStatus.waitingToRetry:
      case TaskStatus.paused:
        _downloading.add(formatId);
        _downloadPhases[formatId] = MushafDownloadPhase.queued;
        break;
      case TaskStatus.running:
        _downloading.add(formatId);
        _downloadPhases[formatId] = MushafDownloadPhase.downloading;
        break;
      case TaskStatus.complete:
        _downloading.add(formatId);
        _progress[formatId] = 1;
        _downloadPhases[formatId] = MushafDownloadPhase.verifying;
        if (update.task is DownloadTask) {
          final task = update.task as DownloadTask;
          final completion = _downloadCompletions[formatId];
          if (completion != null) {
            unawaited(_completeDownloadWaiter(task, completion));
          } else if (!_inflight.containsKey(formatId)) {
            unawaited(_installRecoveredDownload(format, task));
          }
        }
        break;
      case TaskStatus.failed:
      case TaskStatus.notFound:
        final completion = _downloadCompletions[formatId];
        if (completion != null && !completion.isCompleted) {
          completion.completeError(StateError('Background download failed'));
        } else {
          _clearDownloadState(formatId);
          if (update.task is DownloadTask) {
            unawaited(_discardBackgroundTask(update.task as DownloadTask));
          }
        }
        break;
      case TaskStatus.canceled:
        final completion = _downloadCompletions[formatId];
        if (completion != null && !completion.isCompleted) {
          completion.completeError(const MushafDownloadCancelledException());
        } else {
          _clearDownloadState(formatId);
          if (update.task is DownloadTask) {
            unawaited(_discardBackgroundTask(update.task as DownloadTask));
          }
        }
        break;
    }
    notifyListeners();
  }

  Future<void> _completeDownloadWaiter(
    DownloadTask task,
    Completer<String> completion,
  ) async {
    try {
      completion.complete(await task.filePath());
    } catch (error) {
      if (!completion.isCompleted) completion.completeError(error);
    }
  }

  Future<bool> cancelDownload(String id) async {
    final task = _backgroundTasks[id];
    if (task == null) return false;
    final cancelled = await FileDownloader().cancel(task);
    if (cancelled) {
      final completion = _downloadCompletions[id];
      if (completion != null && !completion.isCompleted) {
        completion.completeError(const MushafDownloadCancelledException());
      } else {
        _clearDownloadState(id);
        unawaited(_discardBackgroundTask(task));
      }
      _log('download_cancel', {'id': id, 'outcome': 'requested'});
      notifyListeners();
    }
    return cancelled;
  }

  Future<void> _discardBackgroundTask(DownloadTask task) async {
    try {
      final file = File(await task.filePath());
      if (await file.exists()) await file.delete();
    } catch (_) {}
    try {
      await FileDownloader().database.deleteRecordWithId(task.taskId);
    } catch (_) {}
  }

  void _clearDownloadState(String id) {
    _downloading.remove(id);
    _progress.remove(id);
    _downloadPhases.remove(id);
    _downloadedBytes.remove(id);
    _downloadTotalBytes.remove(id);
    _downloadSpeedBytesPerSecond.remove(id);
    _downloadTimeRemaining.remove(id);
    _backgroundTasks.remove(id);
  }

  Future<void> _install(String id) async {
    await initialize();
    final format = _formats.where((f) => f.id == id).firstOrNull;
    if (format == null || !format.compatible || format.packageUrl == null) {
      throw StateError('Unsupported mushaf format');
    }
    final started = DateTime.now();
    _log('install_start', {
      'id': id,
      'source': format.packageUrl!.startsWith('http') ? 'github' : 'local',
    });
    _downloading.add(id);
    _progress[id] = 0;
    _downloadPhases[id] = MushafDownloadPhase.queued;
    if (format.sizeBytes != null && format.sizeBytes! > 0) {
      _downloadTotalBytes[id] = format.sizeBytes!;
    }
    notifyListeners();
    try {
      final bytes = await _download(format);
      _downloadPhases[id] = MushafDownloadPhase.verifying;
      notifyListeners();
      await _installArchive(format, bytes);
      _log('install_finish', {
        'id': id,
        'outcome': 'success',
        'elapsed_ms': _elapsed(started),
        'retry': 0,
      });
    } catch (error) {
      _log('install_finish', {
        'id': id,
        'outcome': error is MushafDownloadCancelledException
            ? 'canceled'
            : 'failed',
        'reason': error.runtimeType.toString(),
        'elapsed_ms': _elapsed(started),
        'retry': 0,
      });
      rethrow;
    } finally {
      _clearDownloadState(id);
      notifyListeners();
    }
  }

  Future<Uint8List> _download(MushafFormat format) async {
    final local = await _resources.readBytes(format.packageUrl!);
    if (local != null) {
      if (local.length > _maxZipBytes) throw StateError('Package too large');
      _progress[format.id] = 1;
      _downloadedBytes[format.id] = local.length;
      _downloadTotalBytes[format.id] = local.length;
      _downloadPhases[format.id] = MushafDownloadPhase.verifying;
      notifyListeners();
      return local;
    }
    if (format.sizeBytes != null && format.sizeBytes! > _maxZipBytes) {
      throw StateError('Package too large');
    }
    final url = format.packageUrl!.startsWith('http')
        ? format.packageUrl!
        : '$_remoteRoot${format.packageUrl}';
    await _ensureBackgroundDownloader();
    final task = DownloadTask(
      taskId: 'mushaf_${format.id}_${DateTime.now().microsecondsSinceEpoch}',
      url: url,
      filename: '${format.id}.zip',
      directory: 'mushaf_format_downloads',
      baseDirectory: BaseDirectory.applicationDocuments,
      group: _backgroundDownloadGroup,
      updates: Updates.statusAndProgress,
      retries: 2,
      allowPause: true,
      priority: 0,
      metaData: format.id,
      displayName: format.displayName,
    );
    final completion = Completer<String>();
    _backgroundTasks[format.id] = task;
    _downloadCompletions[format.id] = completion;
    _downloadPhases[format.id] = MushafDownloadPhase.queued;
    _log('download_start', {
      'id': format.id,
      'source': 'background_downloader',
      'trigger': 'user',
      'expected_bytes': format.sizeBytes,
    });
    notifyListeners();
    File? archiveFile;
    try {
      final enqueued = await FileDownloader().enqueue(task);
      if (!enqueued) throw StateError('Background download was not enqueued');
      final path = await completion.future;
      archiveFile = File(path);
      if (!await archiveFile.exists()) {
        throw StateError('Background download file is missing');
      }
      final length = await archiveFile.length();
      if (length > _maxZipBytes) throw StateError('Package too large');
      _downloadedBytes[format.id] = length;
      _downloadTotalBytes[format.id] = length;
      return await archiveFile.readAsBytes();
    } finally {
      if (archiveFile != null && await archiveFile.exists()) {
        await archiveFile.delete();
      } else {
        try {
          final path = await task.filePath();
          final partial = File(path);
          if (await partial.exists()) await partial.delete();
        } catch (_) {}
      }
      _downloadCompletions.remove(format.id);
      _backgroundTasks.remove(format.id);
      try {
        await FileDownloader().database.deleteRecordWithId(task.taskId);
      } catch (_) {}
    }
  }

  Future<void> _installArchive(MushafFormat format, Uint8List bytes) async {
    final id = format.id;
    final base = Directory(p.join(_documentsDirectory!.path, 'mushaf_formats'));
    final staging = Directory(
      p.join(
        base.path,
        '.$id.staging.${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    try {
      await compute(_extractAndValidate, {
        'bytes': bytes,
        'directory': staging.path,
        'format': _formatJson(format),
      });
      await File(
        p.join(staging.path, '.complete'),
      ).writeAsString('1', flush: true);
      final target = Directory(p.join(base.path, id));
      final backup = Directory(
        p.join(
          base.path,
          '.$id.previous.${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await base.create(recursive: true);
      if (await target.exists()) await target.rename(backup.path);
      try {
        await staging.rename(target.path);
        if (!await _validateInstalled(format)) {
          throw StateError('Installed package failed validation');
        }
      } catch (_) {
        if (await target.exists()) await target.delete(recursive: true);
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      if (await backup.exists()) await backup.delete(recursive: true);
      _validatedInstalled.add(id);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> _installRecoveredDownload(
    MushafFormat format,
    DownloadTask task,
  ) async {
    if (!_recoveredInstallsInFlight.add(task.taskId)) return;
    final started = task.creationTime;
    _downloading.add(format.id);
    _downloadPhases[format.id] = MushafDownloadPhase.verifying;
    _progress[format.id] = 1;
    notifyListeners();
    try {
      final file = File(await task.filePath());
      if (!await file.exists()) throw StateError('Downloaded package missing');
      final length = await file.length();
      if (length > _maxZipBytes) throw StateError('Package too large');
      final bytes = await file.readAsBytes();
      await _installArchive(format, bytes);
      _log('install_recovery_finish', {
        'id': format.id,
        'outcome': 'success',
        'source': 'background_download',
        'elapsed_ms': _elapsed(started),
      });
    } catch (error) {
      _log('install_recovery_finish', {
        'id': format.id,
        'outcome': 'failed',
        'reason': error.runtimeType.toString(),
        'elapsed_ms': _elapsed(started),
      });
    } finally {
      try {
        final path = await task.filePath();
        final file = File(path);
        if (await file.exists()) await file.delete();
        await FileDownloader().database.deleteRecordWithId(task.taskId);
      } catch (_) {}
      _recoveredInstallsInFlight.remove(task.taskId);
      _clearDownloadState(format.id);
      notifyListeners();
    }
  }

  Future<void> select(String id) async {
    await initialize();
    final started = DateTime.now();
    _log('select_start', {'id': id, 'source': 'user'});
    try {
      final next = id == MushafFormat.builtin.id
          ? MushafFormat.builtin
          : _formats.where((f) => f.id == id && f.compatible).firstOrNull;
      if (next == null ||
          (next.isBuiltin ? false : !await _validateInstalled(next))) {
        _validatedInstalled.remove(id);
        notifyListeners();
        throw StateError('Mushaf format is not installed');
      }
      if (!next.isBuiltin) _validatedInstalled.add(next.id);
      if (_current.id != next.id) {
        MushafPaginationIndex? index;
        if (!next.isBuiltin && next.navigationIndexFile != null) {
          index = await _readPaginationIndex(next);
          if (index == null) {
            throw StateError('Missing validated pagination index');
          }
        }
        MushafPagination.activate(index);
        _current = next;
        await _preferences!.setString(_selectedKey, id);
        selectionRevision.value++;
        notifyListeners();
      }
      _log('select_finish', {
        'id': id,
        'outcome': 'success',
        'elapsed_ms': _elapsed(started),
      });
    } catch (error) {
      _log('select_finish', {
        'id': id,
        'outcome': 'failed',
        'reason': error.runtimeType.toString(),
        'elapsed_ms': _elapsed(started),
      });
      rethrow;
    }
  }

  String? _databasePath(String name) {
    if (_current.isBuiltin || !_validatedInstalled.contains(_current.id)) {
      return null;
    }
    final path = p.join(_directory(_current.id).path, name);
    return File(path).existsSync() ? path : null;
  }

  Directory _directory(String id) =>
      Directory(p.join(_documentsDirectory!.path, 'mushaf_formats', id));

  Future<bool> _validateInstalled(MushafFormat format) async {
    if (_documentsDirectory == null) return false;
    final dir = _directory(format.id);
    if (!await dir.exists() ||
        !await File(p.join(dir.path, '.complete')).exists()) {
      return false;
    }
    try {
      final root = await dir.resolveSymbolicLinks();
      final manifestFile = File(p.join(root, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString());
      if (manifest is! Map ||
          manifest['id'] != format.id ||
          manifest['page_count'] != 604 ||
          manifest['line_count'] != 15 ||
          manifest['pagination_matches_builtin'] !=
              format.paginationMatchesBuiltin ||
          manifest['word_alignment_matches_builtin'] !=
              format.wordAlignmentMatchesBuiltin ||
          manifest['navigation_index_file'] != format.navigationIndexFile ||
          manifest['navigation_index_sha256'] != format.navigationIndexSha256) {
        return false;
      }
      if ((manifest['font_mode']?.toString() ?? 'page_glyph') !=
              format.fontMode ||
          (format.fontMode == 'unicode_single' &&
              (manifest['license_sha256'] != format.licenseSha256 ||
                  format.licenseSha256 == null))) {
        return false;
      }
      final files = <String>[
        'manifest.json',
        'words.sqlite',
        'layout.sqlite',
        if (format.fontMode == 'unicode_single')
          'fonts/quran.otf'
        else
          ...List<String>.generate(604, (i) => 'fonts/p${i + 1}.ttf'),
      ];
      if (format.fontMode == 'unicode_single') files.add('LICENSE.txt');
      if (format.navigationIndexFile != null) {
        files.add(format.navigationIndexFile!);
      }
      final rootPrefix = root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';
      for (final relative in files) {
        final file = File(p.join(root, relative));
        final resolved = await file.resolveSymbolicLinks();
        if (!resolved.startsWith(rootPrefix) ||
            !await file.exists() ||
            await file.length() == 0) {
          return false;
        }
      }
      if (format.isUnicodeFont &&
          sha256
                  .convert(
                    await File(p.join(root, 'LICENSE.txt')).readAsBytes(),
                  )
                  .toString()
                  .toLowerCase() !=
              format.licenseSha256!.toLowerCase()) {
        return false;
      }
      final expectedRelative = <String>{...files, '.complete'};
      final actualRelative = Directory(root)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map(
            (entity) =>
                p.relative(entity.path, from: root).replaceAll('\\', '/'),
          )
          .toSet();
      if (actualRelative.length != expectedRelative.length ||
          !actualRelative.containsAll(expectedRelative)) {
        return false;
      }
      final indexValid =
          format.navigationIndexFile == null ||
          (await _readPaginationIndex(format)) != null;
      return indexValid &&
          _sameBytes(
            Uint8List.fromList(
              await File(p.join(root, 'words.sqlite')).readAsBytes(),
            ),
            _sqliteMagic,
          ) &&
          _sameBytes(
            Uint8List.fromList(
              await File(p.join(root, 'layout.sqlite')).readAsBytes(),
            ),
            _sqliteMagic,
          );
    } catch (_) {
      return false;
    }
  }

  List<MushafFormat> _readCatalog(String? encoded) {
    if (encoded == null) return const [MushafFormat.builtin];
    try {
      return _readCatalogMap(jsonDecode(encoded));
    } catch (_) {
      return const [MushafFormat.builtin];
    }
  }

  List<MushafFormat> _readCatalogMap(dynamic value) {
    if (value is! Map ||
        value['schema_version'] != 1 ||
        value['formats'] is! List) {
      return const [MushafFormat.builtin];
    }
    final result = <MushafFormat>[MushafFormat.builtin];
    final ids = <String>{};
    for (final item in value['formats']) {
      if (item is! Map) return const [MushafFormat.builtin];
      final raw = Map<String, dynamic>.from(item);
      final format = MushafFormat.fromJson(raw);
      final validId = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(format.id);
      final validHash =
          format.sha256 != null &&
          RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(format.sha256!);
      if (!validId ||
          format.id == MushafFormat.builtin.id ||
          !_isAllowedPackageUrl(format.id, format.packageUrl) ||
          !validHash ||
          (format.fontMode != 'page_glyph' &&
              format.fontMode != 'unicode_single') ||
          (format.fontMode == 'unicode_single' &&
              (format.licenseSha256 == null ||
                  !RegExp(
                    r'^[a-fA-F0-9]{64}$',
                  ).hasMatch(format.licenseSha256!))) ||
          !ids.add(format.id)) {
        return const [MushafFormat.builtin];
      }
      result.add(format);
    }
    return result;
  }

  Map<String, dynamic> _formatJson(MushafFormat f) => {
    'id': f.id,
    'name': f.name,
    'description': f.description,
    'page_count': f.pageCount,
    'line_count': f.lineCount,
    'has_tajweed': f.hasTajweed,
    'package_url': f.packageUrl,
    'sha256': f.sha256,
    'size_bytes': f.sizeBytes,
    'pagination_matches_builtin': f.paginationMatchesBuiltin,
    'word_alignment_matches_builtin': f.wordAlignmentMatchesBuiltin,
    'font_mode': f.fontMode,
    if (f.licenseSha256 != null) 'license_sha256': f.licenseSha256,
    if (f.navigationIndexFile != null)
      'navigation_index_file': f.navigationIndexFile,
    if (f.navigationIndexSha256 != null)
      'navigation_index_sha256': f.navigationIndexSha256,
  };
  String _fontPrefix(MushafFormat f) => 'IBAD_${f.id.toUpperCase()}_P';
  void _log(String event, Map<String, Object?> fields) =>
      AppLogger.logEvent('MushafFormat', event, fields);
  int _elapsed(DateTime started) =>
      DateTime.now().difference(started).inMilliseconds;
}

const _sqliteMagic = <int>[
  83,
  81,
  76,
  105,
  116,
  101,
  32,
  102,
  111,
  114,
  109,
  97,
  116,
  32,
  51,
  0,
];

Future<void> _extractAndValidate(Map<String, dynamic> args) async {
  final bytes = Uint8List.fromList(args['bytes'] as List<int>);
  final format = Map<String, dynamic>.from(args['format'] as Map);
  if (bytes.length > 200 * 1024 * 1024 ||
      sha256.convert(bytes).toString().toLowerCase() !=
          (format['sha256'] as String).toLowerCase()) {
    throw StateError('Package hash mismatch or too large');
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  if (archive.length > 700) throw StateError('Too many package members');
  var total = 0;
  final files = <String, Uint8List>{};
  for (final entry in archive) {
    final name = entry.name.replaceAll('\\', '/');
    final declared = entry.size;
    if (declared < 0 ||
        declared > 16 * 1024 * 1024 ||
        total > 400 * 1024 * 1024 - declared ||
        entry.isSymbolicLink ||
        name.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(name) ||
        name.split('/').contains('..') ||
        name.isEmpty ||
        files.containsKey(name)) {
      throw StateError('Unsafe or oversized package member');
    }
    if (!entry.isFile) throw StateError('Unexpected package member');
    final data = Uint8List.fromList(entry.content as List<int>);
    if (data.length > 16 * 1024 * 1024) {
      throw StateError('Package member too large');
    }
    total += data.length;
    files[name] = data;
  }
  final expectedNames = <String>{
    'manifest.json',
    'words.sqlite',
    'layout.sqlite',
    if (format['font_mode'] == 'unicode_single')
      'fonts/quran.otf'
    else
      ...List<String>.generate(604, (i) => 'fonts/p${i + 1}.ttf'),
  };
  if (format['font_mode'] == 'unicode_single') {
    expectedNames.add('LICENSE.txt');
  }
  final declaredIndex = format['navigation_index_file'];
  if (declaredIndex != null) {
    if (declaredIndex != 'pagination.json') {
      throw StateError('Invalid navigation index file');
    }
    expectedNames.add('pagination.json');
  }
  if (files.length != expectedNames.length ||
      files.keys.any((name) => !expectedNames.contains(name))) {
    throw StateError('Missing or unexpected package files');
  }
  final manifest = jsonDecode(utf8.decode(files['manifest.json']!));
  if (manifest is! Map ||
      manifest['schema_version'] != 1 ||
      manifest['id'] != format['id'] ||
      manifest['page_count'] != 604 ||
      manifest['line_count'] != 15 ||
      manifest['pagination_matches_builtin'] !=
          (format['pagination_matches_builtin'] == true) ||
      manifest['word_alignment_matches_builtin'] !=
          (format['word_alignment_matches_builtin'] == true) ||
      (manifest['font_mode']?.toString() ?? 'page_glyph') !=
          (format['font_mode']?.toString() ?? 'page_glyph') ||
      (format['font_mode'] == 'unicode_single' &&
          (format['license_sha256'] is! String ||
              manifest['license_sha256'] != format['license_sha256'] ||
              sha256.convert(files['LICENSE.txt']!).toString().toLowerCase() !=
                  (format['license_sha256'] as String).toLowerCase())) ||
      format['word_alignment_matches_builtin'] != true ||
      (format['pagination_matches_builtin'] != true && declaredIndex == null) ||
      (manifest['navigation_index_file'] != null &&
          manifest['navigation_index_file'] != 'pagination.json') ||
      (manifest['navigation_index_file'] == 'pagination.json' &&
          (!files.containsKey('pagination.json') ||
              manifest['navigation_index_sha256'] is! String ||
              manifest['navigation_index_sha256'] !=
                  format['navigation_index_sha256'] ||
              sha256
                      .convert(files['pagination.json']!)
                      .toString()
                      .toLowerCase() !=
                  (manifest['navigation_index_sha256'] as String)
                      .toLowerCase())) ||
      manifest['navigation_index_file'] != declaredIndex ||
      manifest['navigation_index_sha256'] !=
          format['navigation_index_sha256']) {
    throw StateError('Invalid package manifest');
  }
  for (final name in ['words.sqlite', 'layout.sqlite']) {
    if (!_sameBytes(files[name]!, _sqliteMagic)) {
      throw StateError('Invalid SQLite database');
    }
  }
  final fontNames = format['font_mode'] == 'unicode_single'
      ? <String>['fonts/quran.otf']
      : List<String>.generate(604, (i) => 'fonts/p${i + 1}.ttf');
  for (final fontName in fontNames) {
    final font = files[fontName]!;
    if (font.length < 4 ||
        !((font[0] == 0 && font[1] == 1 && font[2] == 0 && font[3] == 0) ||
            (font[0] == 79 &&
                font[1] == 84 &&
                font[2] == 84 &&
                font[3] == 79))) {
      throw StateError('Invalid page font');
    }
  }
  final output = Directory(args['directory'] as String);
  await output.create(recursive: true);
  for (final item in files.entries) {
    final file = File(p.join(output.path, item.key));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(item.value, flush: true);
  }
}

bool _sameBytes(Uint8List data, List<int> expected) {
  if (data.length < expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (data[i] != expected[i]) return false;
  }
  return true;
}

bool _isAllowedPackageUrl(String id, String? value) {
  if (value == null) return false;
  final relative = 'mushaf/formats/$id.zip';
  if (value == relative) return true;
  return value == '$_githubResourceRoot$relative' ||
      value == _releasePackageUrls[id];
}
