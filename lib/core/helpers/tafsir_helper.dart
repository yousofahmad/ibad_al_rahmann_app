import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class TafsirBook {
  final String id;
  final String name;
  final String author;
  final bool isBuiltIn;
  final String? url;
  final String? size;

  const TafsirBook({
    required this.id,
    required this.name,
    required this.author,
    this.isBuiltIn = false,
    this.url,
    this.size,
  });

  factory TafsirBook.fromJson(Map<String, dynamic> json) {
    return TafsirBook(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      isBuiltIn: json['is_builtin'] == true,
      url: json['url']?.toString(),
      size: json['size']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'author': author,
    'is_builtin': isBuiltIn,
    if (url != null) 'url': url,
    if (size != null) 'size': size,
  };
}

class TafsirHelper {
  static const String _repoBaseUrl =
      "https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/";

  static const List<TafsirBook> defaultBooks = [
    TafsirBook(
      id: 'muyassar',
      name: 'التفسير الميسر',
      author: 'نخبة من العلماء (مجمع الملك فهد)',
      isBuiltIn: true,
      size: '2.8 MB',
    ),
    TafsirBook(
      id: 'ibn_katheer',
      name: 'تفسير ابن كثير',
      author: 'الإمام ابن كثير (تفسير القرآن العظيم)',
      isBuiltIn: false,
      url: 'tafseer/ar-tafsir-ibn-kathir.zip',
      size: '5.3 MB',
    ),
    TafsirBook(
      id: 'tabari',
      name: 'تفسير الطبري',
      author: 'الإمام الطبري (جامع البيان عن تأويل آي القرآن)',
      isBuiltIn: false,
      url: 'tafseer/ar-tafsir-al-tabari.zip',
      size: '8.2 MB',
    ),
  ];

  static final List<TafsirBook> _availableBooks = List.from(defaultBooks);
  // Cache format: _cache['${bookId}_$surahNumber'] = { verseNumber: tafsirText }
  static final Map<String, Map<int, String>> _cache = {};
  static final Map<String, String> _muyassarCache = {};

  static List<TafsirBook> get availableBooks => _availableBooks;

  static String getSelectedBookId() {
    return CacheHelper.prefs.getString('selected_tafsir_book_id') ?? 'muyassar';
  }

  static Future<void> setSelectedBookId(String id) async {
    await CacheHelper.prefs.setString('selected_tafsir_book_id', id);
  }

  static Future<Directory> _getBookDirectory(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${dir.path}/tafseer/$bookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    return bookDir;
  }

  static String normalizeDownloadUrl(String url) {
    // 1. Google Drive Links
    if (url.contains('drive.google.com')) {
      final match =
          RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(url) ??
          RegExp(r'id=([a-zA-Z0-9_-]+)').firstMatch(url);
      if (match != null) {
        final fileId = match.group(1);
        return 'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';
      }
    }

    // 2. GitHub web blob links -> convert to raw.githubusercontent.com
    if (url.contains('github.com') && url.contains('/blob/')) {
      return url
          .replaceFirst('github.com', 'raw.githubusercontent.com')
          .replaceFirst('/blob/', '/');
    }

    // 3. Direct full URLs
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // 4. Relative paths from repo (e.g. tafseer/ar-tafsir-ibn-kathir.zip)
    if (url.startsWith('tafseer/')) {
      if (url.endsWith('.zip') || url.endsWith('.json')) {
        return '$_repoBaseUrl$url';
      }
      return '$_repoBaseUrl$url.zip';
    }

    // 5. Short slug (e.g. ar-tafsir-ibn-kathir)
    return '${_repoBaseUrl}tafseer/$url.zip';
  }

  static Future<void> fetchRemoteBooks() async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

      // 1. Try master app_config.json first
      try {
        const configUrl = '${_repoBaseUrl}app_config.json';
        final response = await dio.get(configUrl);
        if (response.statusCode == 200) {
          final data = response.data is String
              ? json.decode(response.data)
              : response.data;
          if (data is Map && data['tafseer_books'] is List) {
            _mergeBooks(data['tafseer_books'] as List);
            return;
          }
        }
      } catch (_) {}

      // 2. Fallback to tafseer/tafseer_index.json
      const indexUrl = '${_repoBaseUrl}tafseer/tafseer_index.json';
      final response = await dio.get(indexUrl);
      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;
        if (data is List) {
          _mergeBooks(data);
        }
      }
    } catch (_) {
      // Offline or file not present, keep default books safely
    }
  }

  static void _mergeBooks(List items) {
    for (var item in items) {
      if (item is Map<String, dynamic> || item is Map) {
        final map = Map<String, dynamic>.from(item as Map);
        final book = TafsirBook.fromJson(map);
        if (book.id.isEmpty) continue;
        final existingIdx = _availableBooks.indexWhere((b) => b.id == book.id);
        if (existingIdx >= 0) {
          if (!_availableBooks[existingIdx].isBuiltIn) {
            _availableBooks[existingIdx] = book;
          }
        } else {
          _availableBooks.add(book);
        }
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

    try {
      final bookDir = await _getBookDirectory(bookId);
      final file = File('${bookDir.path}/$surahNumber.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final dynamic jsonResponse = json.decode(content);
        if (jsonResponse is Map && jsonResponse.containsKey('ayahs')) {
          final list = jsonResponse['ayahs'] as List;
          final surahMap = <int, String>{};
          for (var item in list) {
            if (item is Map) {
              final aNum = int.tryParse(item['ayah']?.toString() ?? '') ?? 0;
              final text = item['text']?.toString() ?? '';
              if (aNum > 0) {
                surahMap[aNum] = text;
              }
            }
          }

          // Dynamic pointer resolution: only resolve same-surah pointers
          // (e.g. "2:9" → "2:8" within surah 2). Cross-surah pointers are left as-is.
          final pointerRegex = RegExp(r'^\d+:\d+$');
          for (var entry in surahMap.entries.toList()) {
            final t = entry.value.trim();
            if (pointerRegex.hasMatch(t)) {
              final pParts = t.split(':');
              final pSurah = int.tryParse(pParts[0]) ?? 0;
              final targetAyahNum = int.tryParse(pParts[1]) ?? 0;
              // Only resolve if same surah
              if (pSurah == surahNumber &&
                  surahMap.containsKey(targetAyahNum) &&
                  !pointerRegex.hasMatch(surahMap[targetAyahNum]!.trim())) {
                surahMap[entry.key] = surahMap[targetAyahNum]!;
              } else if (pSurah != surahNumber) {
                // Cross-surah pointer: clear the text
                surahMap[entry.key] = '';
              }
            }
          }

          _cache[cacheKey] = surahMap;
        }
      }
    } catch (e) {
      debugPrint('Error loading surah tafsir $bookId - Surah $surahNumber: $e');
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
      var text = surahMap[verseNumber] ?? '';
      if (RegExp(r'^\d+:\d+$').hasMatch(text.trim())) {
        final targetAyahNum = int.tryParse(text.trim().split(':')[1]) ?? 0;
        if (surahMap.containsKey(targetAyahNum) &&
            !RegExp(r'^\d+:\d+$').hasMatch(surahMap[targetAyahNum]!.trim())) {
          text = surahMap[targetAyahNum]!;
        }
      }
      return TafsirExtractor.extractAyah(text, verseNumber);
    }

    return '';
  }

  /// Downloads the complete book ZIP from user's GitHub repo and splits it into surahs.
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

    try {
      final bookDir = await _getBookDirectory(book.id);
      // Clean previous failed attempts or leftover temp files
      final tempZipFile = File('${bookDir.path}/download_temp.zip');
      if (await tempZipFile.exists()) {
        try {
          await tempZipFile.delete();
        } catch (_) {}
      }
      final completeFile = File('${bookDir.path}/.complete');
      if (await completeFile.exists()) {
        try {
          await completeFile.delete();
        } catch (_) {}
      }

      final zipUrl = normalizeDownloadUrl(book.url ?? book.id);
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      onProgress(0.05);

      try {
        await dio.download(
          zipUrl,
          tempZipFile.path,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onProgress(0.05 + (received / total) * 0.75);
            }
          },
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
          await dio.download(
            altUrl,
            tempZipFile.path,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                onProgress(0.05 + (received / total) * 0.75);
              }
            },
          );
        } else {
          rethrow;
        }
      }

      onProgress(0.82);

      final downloadedBytes = await tempZipFile.readAsBytes();
      dynamic rawMap;

      // Check if it is a ZIP file (Magic bytes: 0x50, 0x4B)
      if (downloadedBytes.length >= 4 &&
          downloadedBytes[0] == 0x50 &&
          downloadedBytes[1] == 0x4B) {
        final archive = ZipDecoder().decodeBytes(downloadedBytes);
        ArchiveFile? jsonFile;
        for (final file in archive) {
          if (file.isFile && file.name.endsWith('.json')) {
            jsonFile = file;
            break;
          }
        }
        if (jsonFile == null) {
          if (await tempZipFile.exists()) await tempZipFile.delete();
          onComplete(
            false,
            'الملف المضغوط لا يحتوي على بيانات التفسير المطلوبة.',
          );
          return;
        }
        final jsonContent = utf8.decode(jsonFile.content as List<int>);
        rawMap = json.decode(jsonContent);
      } else {
        // Direct JSON file
        final jsonContent = utf8.decode(downloadedBytes);
        rawMap = json.decode(jsonContent);
      }

      if (rawMap is! Map) {
        if (await tempZipFile.exists()) await tempZipFile.delete();
        onComplete(false, 'تنسيق ملف التفسير غير متوافق.');
        return;
      }

      onProgress(0.92);

      final Map<int, List<Map<String, dynamic>>> surahsAyahs = {};
      for (int s = 1; s <= 114; s++) {
        surahsAyahs[s] = [];
      }

      rawMap.forEach((key, val) {
        final parts = key.toString().split(':');
        if (parts.length == 2) {
          final sNum = int.tryParse(parts[0]) ?? 0;
          final aNum = int.tryParse(parts[1]) ?? 0;
          String text = '';
          dynamic targetVal = val;
          // Resolve same-surah pointer references only (e.g. "2:9": "2:8").
          // Cross-surah pointers are intentionally ignored to prevent showing
          // another surah's tafsir for a verse that has no dedicated entry.
          if (targetVal is String) {
            final pParts = targetVal.split(':');
            if (pParts.length == 2) {
              final pSurah = int.tryParse(pParts[0]) ?? 0;
              // Only resolve if pointer targets same surah
              if (pSurah == sNum && rawMap.containsKey(targetVal)) {
                targetVal = rawMap[targetVal];
              } else {
                // Cross-surah pointer — store empty so verse shows no tafsir
                targetVal = null;
              }
            }
          }
          if (targetVal is Map) {
            text = targetVal['text']?.toString() ?? '';
          } else if (targetVal is String) {
            text = targetVal;
          }
          if (sNum >= 1 && sNum <= 114 && aNum > 0) {
            // Extract the specific ayah text if it is grouped using brackets
            final regex = RegExp(
              r'[\{\(\[﴿]' +
                  aNum.toString() +
                  r'[\}\)\]﴾](.*?)(?=\s*[\{\(\[﴿]\d+[\}\)\]﴾]|$)',
              dotAll: true,
            );
            final match = regex.firstMatch(text);
            if (match != null) {
              text = match.group(0)!.trim();
            }

            final cleaned = cleanTafsirText(text);
            surahsAyahs[sNum]?.add({'ayah': aNum, 'text': cleaned});
          }
        }
      });

      for (int s = 1; s <= 114; s++) {
        final ayahsList = surahsAyahs[s] ?? [];
        ayahsList.sort(
          (a, b) => (a['ayah'] as int).compareTo(b['ayah'] as int),
        );
        final surahJson = json.encode({'ayahs': ayahsList});
        final surahFile = File('${bookDir.path}/$s.json');
        await surahFile.writeAsString(surahJson);
      }

      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }

      await completeFile.writeAsString('done');

      onProgress(1.0);
      onComplete(true, null);
    } catch (e) {
      debugPrint('downloadBook error: $e');
      onComplete(false, 'حدث خطأ أثناء تحميل التفسير: $e');
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
