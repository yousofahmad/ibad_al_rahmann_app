import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/background_resource_download_service.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'feature_resource_repository.dart';
import 'tafsir_catalog.dart';
import 'tafsir_content_parser.dart';

export 'tafsir_catalog.dart';

/// Decodes an archive without Flutter state or filesystem access.
///
/// The returned map contains JSON strings for all 114 cache files and scalar
/// parser statistics, making it safe to send through [compute].
Map<String, dynamic> prepareDownloadedArchive(List<int> bytes) {
  dynamic root;
  if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? jsonFile;
    for (final file in archive) {
      if (file.isFile && file.name.toLowerCase().endsWith('.json')) {
        jsonFile = file;
        break;
      }
    }
    if (jsonFile == null) {
      throw const FormatException('archive_missing_json');
    }
    root = json.decode(utf8.decode(jsonFile.content as List<int>));
  } else {
    root = json.decode(utf8.decode(bytes));
  }
  if (root is! Map) throw const FormatException('invalid_json_root');

  final parsed = TafsirContentParser.parseWithStats(root);
  final data = parsed['data'] as Map<int, List<Map<String, dynamic>>>;
  final stats = Map<String, int>.from(parsed['stats'] as Map);
  if ((stats['nonEmptyAyahs'] ?? 0) == 0) {
    throw const FormatException('empty_tafsir_content');
  }

  final files = <String, String>{};
  for (var surah = 1; surah <= 114; surah++) {
    final ayahs = data[surah] ?? const <Map<String, dynamic>>[];
    files['$surah'] = json.encode({
      'ayahs': [
        for (final item in ayahs)
          <String, dynamic>{
            'ayah': item['ayah'],
            'text': TafsirHelper.cleanTafsirText(item['text'] as String),
          },
      ],
    });
  }
  stats['readableAyahs'] = stats['nonEmptyAyahs'] ?? 0;
  return <String, dynamic>{'files': files, 'stats': stats};
}

Map<String, dynamic> decodeCachedSurah(String content) {
  final decoded = json.decode(content);
  if (decoded is! Map || decoded['ayahs'] is! List) {
    throw const FormatException('invalid_surah_cache');
  }
  final result = <String, dynamic>{};
  for (final item in decoded['ayahs'] as List) {
    if (item is Map) {
      final ayah = int.tryParse(item['ayah']?.toString() ?? '');
      if (ayah != null && ayah > 0) {
        result['$ayah'] = item['text']?.toString() ?? '';
      }
    }
  }
  return result;
}

class TafsirHelper {
  static const String _repoBaseUrl =
      "https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/source/import-qul-resources/";

  static const List<TafsirBook> defaultBooks = [
    TafsirBook(
      id: 'muyassar',
      name: 'التفسير الميسر',
      author: 'نخبة من العلماء (مجمع الملك فهد)',
      isBuiltIn: true,
      languageCode: 'ar',
      edition: 'نسخة التطبيق',
      size: '2.8 MB',
    ),
    TafsirBook(
      id: 'ibn_katheer',
      name: 'تفسير ابن كثير',
      author: 'الإمام ابن كثير (تفسير القرآن العظيم)',
      isBuiltIn: false,
      groupId: 'ibn_katheer',
      groupName: 'تفسير ابن كثير',
      languageCode: 'ar',
      sourceId: 22,
      url: 'tafseer/ar-tafsir-ibn-kathir.zip',
      size: '5.3 MB',
    ),
    TafsirBook(
      id: 'tabari',
      name: 'تفسير الطبري',
      author: 'الإمام الطبري (جامع البيان عن تأويل آي القرآن)',
      isBuiltIn: false,
      groupId: 'tabari',
      groupName: 'تفسير الطبري',
      languageCode: 'ar',
      sourceId: 37,
      url: 'tafseer/ar-tafsir-al-tabari.zip',
      size: '8.2 MB',
    ),
  ];

  static final List<TafsirBook> _availableBooks = List.from(defaultBooks);
  // Cache format: _cache['${bookId}_$surahNumber'] = { verseNumber: tafsirText }
  static final Map<String, Map<int, String>> _cache = {};
  static final Map<String, String> _muyassarCache = {};
  static const _catalogCacheKey = 'tafsir_catalog_cache_v1';
  static Future<void>? _catalogRequest;
  static final Set<String> _activeDownloads = {};

  static List<TafsirBook> get availableBooks => _availableBooks;
  static List<TafsirBookGroup> get availableBookGroups =>
      TafsirCatalog.groupBooks(_availableBooks);

  static TafsirBook preferredBookForGroup(TafsirBookGroup group) {
    var saved = CacheHelper.prefs.getString(
      'selected_tafsir_variant_${group.id}',
    );
    if (saved == null) {
      for (final alias in TafsirCatalog.canonicalGroupIds.entries) {
        if (alias.value != group.id) continue;
        saved = CacheHelper.prefs.getString(
          'selected_tafsir_variant_${alias.key}',
        );
        if (saved != null) break;
      }
    }
    return group.variants.firstWhere(
      (book) => book.id == saved,
      orElse: () => group.variants.firstWhere(
        (book) => book.languageCode == 'ar',
        orElse: () => group.variants.first,
      ),
    );
  }

  static String getSelectedBookId() {
    return CacheHelper.prefs.getString('selected_tafsir_book_id') ?? 'muyassar';
  }

  static Future<void> setSelectedBookId(String id) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) return;
    await CacheHelper.prefs.setString('selected_tafsir_book_id', id);
    for (final book in _availableBooks) {
      if (book.id == id) {
        await CacheHelper.prefs.setString(
          'selected_tafsir_variant_${book.familyId}',
          id,
        );
        break;
      }
    }
  }

  static Future<Directory> _getBookDirectory(String bookId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(bookId)) {
      throw ArgumentError.value(bookId, 'bookId', 'Invalid tafsir book ID');
    }
    final dir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${dir.path}/tafseer/$bookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    return bookDir;
  }

  static String normalizeDownloadUrl(String url) {
    final value = url.trim();
    if (value.isEmpty) {
      throw const FormatException('Empty tafsir download URL');
    }

    // Relative paths and slugs are resolved only inside the trusted feature repo.
    if (RegExp(r'^tafseer/[A-Za-z0-9_./-]+$').hasMatch(value) &&
        !value.contains('..') &&
        !value.contains('//')) {
      final filePath = value.endsWith('.zip') || value.endsWith('.json')
          ? value
          : '$value.zip';
      return '$_repoBaseUrl$filePath';
    }
    if (RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value)) {
      return '${_repoBaseUrl}tafseer/$value.zip';
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasFragment) {
      throw const FormatException('Unsupported tafsir download URL');
    }
    final segments = uri.pathSegments;
    if (segments.any((segment) => segment == '.' || segment == '..')) {
      throw const FormatException('Invalid tafsir download path');
    }

    // Preserve Google Drive links, but only when the exact HTTPS host is used.
    if (uri.host.toLowerCase() == 'drive.google.com') {
      final pathMatch = RegExp(r'/d/([A-Za-z0-9_-]+)').firstMatch(uri.path);
      final fileId = pathMatch?.group(1) ?? uri.queryParameters['id'];
      if (fileId != null && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(fileId)) {
        return Uri.https('drive.google.com', '/uc', {
          'export': 'download',
          'id': fileId,
          'confirm': 't',
        }).toString();
      }
      throw const FormatException('Invalid Google Drive file URL');
    }

    // Only accept repository files under the app's trusted feature repository.
    final isTrustedRepoBase =
        segments.length >= 4 &&
        segments[0] == 'yousofahmad' &&
        segments[1] == 'ibad-alrahman-features';
    final isMainRepoPath =
        isTrustedRepoBase && segments[2] == 'main' && segments[3] == 'tafseer';
    final isImportBranchRepoPath =
        segments.length >= 5 &&
        isTrustedRepoBase &&
        segments[2] == 'source' &&
        segments[3] == 'import-qul-resources' &&
        segments[4] == 'tafseer';
    final isTrustedRepo = isMainRepoPath || isImportBranchRepoPath;
    if (uri.host.toLowerCase() == 'raw.githubusercontent.com' &&
        isTrustedRepo &&
        !uri.hasQuery) {
      return uri.toString();
    }

    // Convert only canonical blob URLs from the same trusted repository.
    final isTrustedBlobBase =
        segments.length >= 5 &&
        segments[0] == 'yousofahmad' &&
        segments[1] == 'ibad-alrahman-features' &&
        segments[2] == 'blob';
    final isMainBlobPath =
        isTrustedBlobBase && segments[3] == 'main' && segments[4] == 'tafseer';
    final isImportBranchBlobPath =
        segments.length >= 6 &&
        isTrustedBlobBase &&
        segments[3] == 'source' &&
        segments[4] == 'import-qul-resources' &&
        segments[5] == 'tafseer';
    final isTrustedBlob = isMainBlobPath || isImportBranchBlobPath;
    if (uri.host.toLowerCase() == 'github.com' &&
        isTrustedBlob &&
        !uri.hasQuery) {
      final rawPath =
          '/yousofahmad/ibad-alrahman-features/${segments.skip(3).join('/')}';
      return Uri.https('raw.githubusercontent.com', rawPath).toString();
    }

    throw const FormatException('Untrusted tafsir download host or path');
  }

  static Future<void> fetchRemoteBooks({Dio? client}) =>
      _catalogRequest ??= _fetchRemoteBooks(client).whenComplete(() {
        _catalogRequest = null;
      });

  static Future<void> _fetchRemoteBooks(Dio? client) async {
    final started = DateTime.now().toUtc();
    final watch = Stopwatch()..start();
    var outcome = 'offline_fallback';
    AppLogger.logEvent('Tafsir', 'catalog_started', {
      'source': 'features_repository',
      'trigger': 'verse_details',
      'actual_start': started.toIso8601String(),
    });
    try {
      try {
        final cached = CacheHelper.prefs.getString(_catalogCacheKey);
        if (cached != null) {
          final items = json.decode(cached);
          if (items is List) _mergeBooks(items);
        }
      } catch (error) {
        AppLogger.logEvent('Tafsir', 'catalog_cache_failed', {
          'reason': error.runtimeType.toString(),
        });
      }
      final local = FeatureResourceRepository.configured;
      if (local.enabled) {
        final preferred = await local.readJson(
          'qul_local/app_config.local.json',
        );
        final manifest = preferred ?? await local.readJson('app_config.json');
        final localItems = manifest == null
            ? null
            : manifest['tafseer_books'] is List
            ? manifest['tafseer_books'] as List
            : manifest['tafsir_books'] is List
            ? manifest['tafsir_books'] as List
            : manifest['books'] is List
            ? manifest['books'] as List
            : null;
        final localTafsirCatalog = await local.readJson(
          'tafseer/tafseer_index.json',
        );
        final localCatalogItems = localTafsirCatalog?['tafseer_books'];
        var loadedLocalCatalog = false;
        if (localItems != null && localItems.isNotEmpty) {
          _mergeBooks(localItems);
          loadedLocalCatalog = true;
        }
        if (localCatalogItems is List && localCatalogItems.isNotEmpty) {
          _mergeBooks(localCatalogItems);
          loadedLocalCatalog = true;
        }
        if (loadedLocalCatalog) {
          await CacheHelper.prefs.setString(
            _catalogCacheKey,
            json.encode(_availableBooks.map((book) => book.toJson()).toList()),
          );
          outcome = 'local_success';
          return;
        }
        if (manifest != null && !loadedLocalCatalog) {
          AppLogger.logEvent('Tafsir', 'local_catalog_invalid', {
            'source': 'local_manifest',
            'reason': 'missing_books',
          });
        }
      }
      final dio =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
      const catalogs = ['app_config.json', 'tafseer/tafseer_index.json'];
      var loadedRemoteCatalog = false;
      for (var attempt = 0; attempt < catalogs.length; attempt++) {
        final attemptWatch = Stopwatch()..start();
        final source = attempt == 0 ? 'app_config' : 'tafsir_index';
        try {
          final response = await dio.get('$_repoBaseUrl${catalogs[attempt]}');
          final data = response.data is String
              ? json.decode(response.data)
              : response.data;
          final items = data is List
              ? data
              : data is Map && data['tafseer_books'] is List
              ? data['tafseer_books'] as List
              : null;
          AppLogger.logEvent('Tafsir', 'catalog_attempt_finished', {
            'source': source,
            'attempt': attempt + 1,
            'http_status': response.statusCode,
            'duration_ms': attemptWatch.elapsedMilliseconds,
            'outcome': items == null ? 'invalid_format' : 'success',
          });
          if (response.statusCode == 200 && items != null) {
            if (items.isNotEmpty) {
              _mergeBooks(items);
              loadedRemoteCatalog = true;
            }
            outcome = loadedRemoteCatalog ? 'success' : 'invalid_format';
          }
        } catch (error) {
          AppLogger.logEvent('Tafsir', 'catalog_attempt_failed', {
            'source': source,
            'attempt': attempt + 1,
            'duration_ms': attemptWatch.elapsedMilliseconds,
            'http_status': error is DioException
                ? error.response?.statusCode
                : null,
            'reason': error.runtimeType.toString(),
            'retry': attempt + 1 < catalogs.length ? 'fallback_index' : 'none',
          });
        }
      }
      if (loadedRemoteCatalog) {
        await CacheHelper.prefs.setString(
          _catalogCacheKey,
          json.encode(_availableBooks.map((book) => book.toJson()).toList()),
        );
        outcome = 'success';
        return;
      }
    } catch (error) {
      AppLogger.logEvent('Tafsir', 'catalog_failed', {
        'reason': error.runtimeType.toString(),
      });
    } finally {
      AppLogger.logEvent('Tafsir', 'catalog_finished', {
        'source': 'features_repository',
        'actual_start': started.toIso8601String(),
        'actual_finish': DateTime.now().toUtc().toIso8601String(),
        'duration_ms': watch.elapsedMilliseconds,
        'outcome': outcome,
        'variants': _availableBooks.length,
        'groups': availableBookGroups.length,
      });
    }
  }

  static void _mergeBooks(List items) {
    for (final sourceMap in TafsirCatalog.flattenItems(items)) {
      if (!TafsirCatalog.isUsableCatalogItem(sourceMap)) continue;
      final map = TafsirCatalog.normalizeCatalogItem(sourceMap);
      final id = map['id']?.toString();
      final existingIdx = _availableBooks.indexWhere((book) => book.id == id);
      final book = TafsirBook.fromJson({
        if (existingIdx >= 0) ..._availableBooks[existingIdx].toJson(),
        ...map,
      });
      if (existingIdx >= 0) {
        final existing = _availableBooks[existingIdx];
        if (!existing.isBuiltIn) {
          final merged = <String, dynamic>{...book.toJson()};
          if (existing.name.trim().isNotEmpty) {
            merged['name'] = existing.name;
          }
          if (existing.author.trim().isNotEmpty) {
            merged['author'] = existing.author;
          }
          if (existing.size != null) merged['size'] = existing.size;
          _availableBooks[existingIdx] = TafsirBook.fromJson(merged);
        }
      } else if (!TafsirCatalog.hasDuplicateSource(book, _availableBooks)) {
        _availableBooks.add(book);
      }
    }
  }

  static Future<bool> isBookDownloaded(String bookId) async {
    if (bookId == 'muyassar') return true;
    try {
      final bookDir = await _getBookDirectory(bookId);
      final completeFile = File('${bookDir.path}/.complete');
      return await completeFile.exists();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isSurahDownloaded(String bookId, int surahNumber) async {
    if (bookId == 'muyassar') return true;
    try {
      final bookDir = await _getBookDirectory(bookId);
      final completeFile = File('${bookDir.path}/.complete');
      final isComplete = await completeFile.exists();
      if (!isComplete) return false;
      final file = File('${bookDir.path}/$surahNumber.json');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> initTafsir() async {
    try {
      await _loadBuiltInMuyassar();
    } catch (e) {
      debugPrint('Error initializing TafsirHelper: $e');
    }
  }

  static Future<void> _loadBuiltInMuyassar() async {
    if (_muyassarCache.isNotEmpty) return;
    try {
      final jsonString = await rootBundle.loadString(AppConsts.tafsirJson);
      final jsonResponse = json.decode(jsonString);
      if (jsonResponse is List) {
        for (var item in jsonResponse) {
          if (item is Map) {
            final surah =
                item['number'] ??
                item['surah'] ??
                item['sura'] ??
                item['surah_number'] ??
                0;
            final ayah =
                item['aya'] ??
                item['ayah'] ??
                item['verse'] ??
                item['verse_number'] ??
                0;
            final text =
                item['text'] ?? item['tafsir'] ?? item['tafseer'] ?? '';
            final sNum = int.tryParse(surah.toString()) ?? 0;
            final aNum = int.tryParse(ayah.toString()) ?? 0;
            if (sNum > 0 && aNum > 0) {
              _muyassarCache['${sNum}_$aNum'] = text.toString();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading built-in muyassar: $e');
    }
  }

  /// Strips HTML tags and formats footnotes cleanly for reading
  static String cleanTafsirText(String raw) {
    if (raw.isEmpty) return '';
    var text = raw;
    // Format paragraph breaks
    text = text.replaceAll(
      RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false),
      '\n\n',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</?p[^>]*>', caseSensitive: false), '');
    // Replace Quranic text span tags with text
    text = text.replaceAllMapped(
      RegExp(r'<span[^>]*>(.*?)</span>', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // Strip remaining HTML tags like <div>, etc.
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Clean footnotes [[...]] into (..)
    text = text.replaceAllMapped(RegExp(r'\[\[(.*?)\]\]', dotAll: true), (
      match,
    ) {
      final inside = match.group(1)?.trim() ?? '';
      return inside.isNotEmpty ? ' ($inside)' : '';
    });
    // Clean redundant whitespace
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  /// Loads Tafsir for a specific [surahNumber] and [bookId] into memory.
  static Future<void> loadSurahTafsir(String bookId, int surahNumber) async {
    if (bookId == 'muyassar') {
      await _loadBuiltInMuyassar();
      return;
    }

    final cacheKey = '${bookId}_$surahNumber';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) return;

    final started = DateTime.now().toUtc();
    final watch = Stopwatch()..start();
    var outcome = 'not_installed';
    AppLogger.logEvent('Tafsir', 'cache_load_started', {
      'source': 'tafsir_cache',
      'trigger': 'verse_details',
      'book': bookId,
      'surah': surahNumber,
      'actual_start': started.toIso8601String(),
    });
    try {
      final bookDir = await _getBookDirectory(bookId);
      if (!await File('${bookDir.path}/.complete').exists()) return;
      final loaded = <int>{};
      final raw = <String, dynamic>{};

      Future<void> loadReferenced(int surah) async {
        if (surah < 1 || surah > 114 || !loaded.add(surah)) return;
        final file = File('${bookDir.path}/$surah.json');
        if (!await file.exists()) return;
        try {
          final decoded = await compute(
            decodeCachedSurah,
            await file.readAsString(),
          );
          for (final entry in decoded.entries) {
            raw['$surah:${entry.key}'] = entry.value;
          }
          for (final text in decoded.values.cast<String>()) {
            final match = RegExp(
              r'^([0-9]+):([0-9]+)$',
            ).firstMatch(text.trim());
            if (match != null) {
              await loadReferenced(int.tryParse(match.group(1)!) ?? 0);
            }
          }
        } catch (_) {
          // A missing or damaged referenced file must not discard valid text
          // already read from another surah in this book.
        }
      }

      await loadReferenced(surahNumber);
      if (raw.isEmpty) {
        outcome = 'no_data';
        return;
      }
      final normalized = await compute(parseTafsirContent, raw);
      for (final entry in normalized.entries) {
        _cache['${bookId}_${entry.key}'] = <int, String>{
          for (final ayah in entry.value)
            ayah['ayah'] as int: ayah['text'] as String,
        };
      }
      outcome = 'loaded';
    } catch (e) {
      outcome = 'failed';
      AppLogger.logEvent('Tafsir', 'cache_load_failed', {
        'source': 'tafsir_cache',
        'trigger': 'verse_details',
        'book': bookId,
        'surah': surahNumber,
        'reason': e.runtimeType.toString(),
      });
    } finally {
      AppLogger.logEvent('Tafsir', 'cache_load_finished', {
        'source': 'tafsir_cache',
        'trigger': 'verse_details',
        'book': bookId,
        'surah': surahNumber,
        'actual_start': started.toIso8601String(),
        'actual_finish': DateTime.now().toUtc().toIso8601String(),
        'duration_ms': watch.elapsedMilliseconds,
        'outcome': outcome,
      });
    }
  }

  /// Synchronously or cached retrieval of verse Tafsir.
  static String getVerseTafsir(
    int surahNumber,
    int verseNumber, {
    String? bookId,
  }) {
    final targetId = bookId ?? getSelectedBookId();
    if (targetId == 'muyassar') {
      return _muyassarCache['${surahNumber}_$verseNumber'] ?? '';
    }

    final cacheKey = '${targetId}_$surahNumber';
    final surahMap = _cache[cacheKey];
    if (surahMap != null && surahMap.containsKey(verseNumber)) {
      final text = surahMap[verseNumber] ?? '';
      return RegExp(r'^\d+:\d+$').hasMatch(text.trim()) ? '' : text;
    }

    return '';
  }

  /// Imports all per-surah files before marking a downloaded book complete.
  static Future<void> downloadBook(
    TafsirBook book, {
    required void Function(double progress) onProgress,
    required void Function(bool success, String? error) onComplete,
  }) async {
    if (book.isBuiltIn || book.id == 'muyassar') {
      onProgress(1.0);
      onComplete(true, null);
      return;
    }

    if (!_activeDownloads.add(book.id)) {
      AppLogger.logEvent('Tafsir', 'download_skipped', {
        'book': book.id,
        'reason': 'already_running',
      });
      onComplete(false, 'تحميل هذه النسخة جارٍ بالفعل.');
      return;
    }
    final started = DateTime.now().toUtc();
    final watch = Stopwatch()..start();
    var attempts = 1;
    var downloadedByteCount = 0;
    var completed = false;
    void finish(bool success, String? message, {String? reason}) {
      if (completed) return;
      completed = true;
      AppLogger.logEvent('Tafsir', 'download_finished', {
        'source': 'configured_tafsir_archive',
        'book': book.id,
        'language': book.languageCode,
        'actual_start': started.toIso8601String(),
        'actual_finish': DateTime.now().toUtc().toIso8601String(),
        'duration_ms': watch.elapsedMilliseconds,
        'outcome': success ? 'success' : 'failed',
        'bytes': downloadedByteCount,
        'attempts': attempts,
        'reason': reason,
      });
      onComplete(success, message);
    }

    AppLogger.logEvent('Tafsir', 'download_started', {
      'source': 'configured_tafsir_archive',
      'trigger': 'selected_language',
      'book': book.id,
      'language': book.languageCode,
      'actual_start': started.toIso8601String(),
    });
    try {
      final bookDir = await _getBookDirectory(book.id);
      final completeFile = File('${bookDir.path}/.complete');
      if (await completeFile.exists()) {
        onProgress(1.0);
        finish(true, null, reason: 'already_installed');
        return;
      }

      final tempZipFile = File('${bookDir.path}/download_temp.zip');
      if (await tempZipFile.exists()) {
        try {
          await tempZipFile.delete();
        } catch (_) {}
      }

      onProgress(0.05);
      final localPath = book.url;
      final localBytes = localPath == null
          ? null
          : await FeatureResourceRepository.configured.readBytes(localPath);
      if (localPath != null &&
          localPath.startsWith('qul_local/') &&
          localBytes == null) {
        throw const FileSystemException('local_resource_missing');
      }
      if (localBytes != null) {
        await tempZipFile.writeAsBytes(localBytes, flush: true);
        downloadedByteCount = localBytes.length;
        onProgress(0.80);
      } else {
        final zipUrl = normalizeDownloadUrl(book.url ?? book.id);
        try {
          await BackgroundResourceDownloadService.instance.downloadToPath(
            id: 'tafsir:${book.id}',
            url: zipUrl,
            destinationPath: tempZipFile.path,
            displayName: book.name,
            onProgress: (progress) => onProgress(0.05 + progress * 0.75),
          );
        } catch (downloadErr) {
          // Fallback: If URL ended with .json try .zip, and vice-versa
          String altUrl = '';
          if (zipUrl.endsWith('.json')) {
            altUrl = '${zipUrl.substring(0, zipUrl.length - 5)}.zip';
          } else if (zipUrl.endsWith('.zip')) {
            altUrl = '${zipUrl.substring(0, zipUrl.length - 4)}.json';
          }
          if (altUrl.isNotEmpty) {
            attempts++;
            AppLogger.logEvent('Tafsir', 'download_retry', {
              'book': book.id,
              'attempt': attempts,
              'reason': downloadErr.runtimeType.toString(),
              'strategy': 'alternate_extension',
              'backoff_ms': 0,
            });
            await BackgroundResourceDownloadService.instance.downloadToPath(
              id: 'tafsir:${book.id}',
              url: altUrl,
              destinationPath: tempZipFile.path,
              displayName: book.name,
              onProgress: (progress) => onProgress(0.05 + progress * 0.75),
            );
          } else {
            rethrow;
          }
        }
      }

      onProgress(0.82);

      final downloadedBytes = await tempZipFile.readAsBytes();
      downloadedByteCount = downloadedBytes.length;
      onProgress(0.92);
      final prepared = await compute(prepareDownloadedArchive, downloadedBytes);
      final files = Map<String, String>.from(prepared['files'] as Map);
      final stats = Map<String, int>.from(prepared['stats'] as Map);
      if ((stats['readableAyahs'] ?? 0) == 0) {
        throw const FormatException('empty_tafsir_content');
      }
      for (var s = 1; s <= 114; s++) {
        await File('${bookDir.path}/$s.json').writeAsString(files['$s']!);
      }

      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }

      await completeFile.writeAsString('done');
      _cache.removeWhere((key, _) => key.startsWith('${book.id}_'));

      onProgress(1.0);
      AppLogger.logEvent('Tafsir', 'download_imported', {
        'source': 'configured_tafsir_archive',
        'trigger': 'selected_language',
        'book': book.id,
        'surahs': 114,
        'readable_ayahs': stats['readableAyahs'] ?? 0,
        'resolved_pointers': stats['resolvedPointers'] ?? 0,
        'invalid_references': stats['invalidReferences'] ?? 0,
      });
      finish(true, null, reason: 'imported');
    } catch (e) {
      finish(
        false,
        'حدث خطأ أثناء تحميل التفسير. يرجى المحاولة مرة أخرى.',
        reason: e.runtimeType.toString(),
      );
    } finally {
      _activeDownloads.remove(book.id);
    }
  }

  static Future<void> deleteBook(String bookId) async {
    if (bookId == 'muyassar') return;
    try {
      final bookDir = await _getBookDirectory(bookId);
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      _cache.removeWhere((k, _) => k.startsWith('${bookId}_'));
    } catch (e) {
      debugPrint('Error deleting tafsir $bookId: $e');
    }
  }
}

class TafsirExtractor {
  static String extractAyah(String text, int verseNumber) {
    if (text.isEmpty) return text;

    final markerRegex = RegExp(
      r'[\{\(\[﴿<]' + verseNumber.toString() + r'[\}\)\]﴾>]',
    );
    final prevMarkerRegex = RegExp(
      r'[\{\(\[﴿<]' + (verseNumber - 1).toString() + r'[\}\)\]﴾>]',
    );

    final currentMatch = markerRegex.firstMatch(text);
    final prevMatch = prevMarkerRegex.firstMatch(text);

    bool hasAnyMarkers = RegExp(r'[\{\(\[﴿<]\d+[\}\)\]﴾>]').hasMatch(text);
    if (!hasAnyMarkers) return text;

    int startIndex = 0;
    int endIndex = text.length;

    if (currentMatch != null) {
      if (prevMatch != null) {
        startIndex = prevMatch.end;
      } else {
        final matches = RegExp(
          r'[\{\(\[﴿<](\d+)[\}\)\]﴾>]',
        ).allMatches(text.substring(0, currentMatch.start));
        if (matches.isNotEmpty) {
          startIndex = matches.last.end;
        } else {
          startIndex = 0;
        }
      }
      endIndex = currentMatch.end;
    } else if (prevMatch != null) {
      startIndex = prevMatch.end;
      final matches = RegExp(
        r'[\{\(\[﴿<](\d+)[\}\)\]﴾>]',
      ).allMatches(text.substring(startIndex));
      if (matches.isNotEmpty) {
        endIndex = startIndex + matches.first.start;
      } else {
        endIndex = text.length;
      }
    }

    return text.substring(startIndex, endIndex).trim();
  }
}
