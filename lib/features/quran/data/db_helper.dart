import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'quran_word.dart';
import 'models/page_line.dart';

class QuranWbwDbHelper {
  static final QuranWbwDbHelper instance = QuranWbwDbHelper._init();
  static Database? _database;

  QuranWbwDbHelper._init();

  bool _isPreloading = false;
  final Map<int, List<PageLine>> _pageLinesCache = {};
  final Map<int, List<QuranWord>> _pageWordsCache = {};
  final Map<String, String> _verseGlyphsCache =
      {}; // key: 'surah_ayah', value: joined glyphs

  List<PageLine>? getPageLinesSync(int pageNumber) =>
      _pageLinesCache[pageNumber];
  List<QuranWord>? getPageWordsSync(int pageNumber) =>
      _pageWordsCache[pageNumber];

  /// Get cached glyphs for a verse synchronously
  String? getVerseGlyphsSync(int surah, int ayah) =>
      _verseGlyphsCache['${surah}_$ayah'];

  void preloadAllPagesInBackground() async {
    if (_isPreloading) return;
    _isPreloading = true;

    // Small initial delay to let UI finish its first frame
    await Future.delayed(const Duration(seconds: 1));

    // Phase 1: Cache all verses glyphs in memory (very fast, one query)
    await cacheAllVersesGlyphs();

    // Phase 2: Silently fetch and cache all pages from 1 to 604
    for (int i = 1; i <= 604; i++) {
      if (!_pageLinesCache.containsKey(i)) {
        await getPageLines(i);
        // CRITICAL: Yield to the main event loop frequently
        // 50ms is safer for older devices like SM-T585 to keep the UI smooth
        // and avoid database locking warnings.
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// Single-pass caching of all verses in the Quran to memory.
  /// This makes the share list and previews instant.
  /// Optimized to prevent CursorWindow overflow by processing surahs one by one.
  /// TODO(H2): Monitor memory consumption of _verseGlyphsCache on low-RAM (<=1GB) devices; consider offloading to background isolate or LRU cache if RAM pressure occurs.
  Future<void> cacheAllVersesGlyphs() async {
    try {
      final db = await instance.database;
      for (int s = 1; s <= 114; s++) {
        final List<Map<String, dynamic>> surahWords = await db.rawQuery(
          'SELECT text, ayah FROM words WHERE surah = ? ORDER BY id ASC',
          [s],
        );

        final Map<int, List<String>> ayahGrouping = {};
        for (var row in surahWords) {
          final ayah = row['ayah'] as int;
          ayahGrouping.putIfAbsent(ayah, () => []).add(row['text'].toString());
        }

        ayahGrouping.forEach((ayah, words) {
          _verseGlyphsCache['${s}_$ayah'] = words.join(' ');
        });

        // Yield to main thread every surah to keep UI perfectly smooth
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      // debugPrint('🔴 Error in cacheAllVersesGlyphs: $e');
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<void> _copyDbAssetIfMissing(String dbPath, String fileName) async {
    final path = join(dbPath, fileName);
    final exists = await databaseExists(path);

    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (e) {
        debugPrint('Error creating DB directory: $e');
      }

      // Copy from asset
      ByteData data = await rootBundle.load(
        join('assets', 'databases', fileName),
      );
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(bytes, flush: true);
    }
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();

    // Ensure both databases exist
    await _copyDbAssetIfMissing(dbPath, 'qpc-v1-glyph-codes-wbw.db');
    await _copyDbAssetIfMissing(dbPath, 'qpc-v1-15-lines.db');

    final mainDbPath = join(dbPath, 'qpc-v1-glyph-codes-wbw.db');
    final mapDbPath = join(dbPath, 'qpc-v1-15-lines.db');

    // debugPrint('Initializing DB. paths: $mainDbPath, $mapDbPath');
    final db = await openDatabase(
      mainDbPath,
      readOnly: true,
      onOpen: (db) async {
        try {
          // Some PRAGMAs might return values and be treated as queries by the lower level driver
          await db.rawQuery('PRAGMA busy_timeout = 5000');
        } catch (e) {
          // debugPrint('Error setting busy_timeout: $e');
        }
      },
    );

    // Attach the layout database only if not already attached
    try {
      final List<Map<String, dynamic>> attachedDbs = await db.rawQuery(
        'PRAGMA database_list',
      );
      bool isAttached = attachedDbs.any(
        (d) =>
            d['name'] == 'map_db' ||
            d['file']?.contains('qpc-v1-15-lines.db') == true,
      );

      if (!isAttached) {
        // debugPrint('Attaching map_db...');
        await db.execute("ATTACH DATABASE '$mapDbPath' AS map_db");
        // debugPrint('map_db attached.');
      }
    } catch (e) {
      if (e.toString().contains('already in use') ||
          e.toString().contains('already attached')) {
        // debugPrint('map_db already attached (ignored error).');
      } else {
        // debugPrint('Error checking/attaching map_db: $e');
      }
    }

    return db;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    try {
      return int.tryParse(value.toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Query all words and headers for a specific page.
  /// Merges `words` from main DB and `pages` from map_db dynamically.
  Future<List<QuranWord>> getPageWords(int pageNumber) async {
    if (_pageWordsCache.containsKey(pageNumber)) {
      return _pageWordsCache[pageNumber]!;
    }
    try {
      final db = await instance.database;

      const query = '''
        SELECT 
          m.line_number, 
          m.line_type, 
          m.is_centered, 
          m.surah_number as header_surah, 
          w.id as word_id, 
          w.text, 
          w.surah, 
          w.ayah
        FROM map_db.pages m
        LEFT JOIN words w ON w.id BETWEEN m.first_word_id AND m.last_word_id
        WHERE m.page_number = ?
        ORDER BY m.line_number, w.id
      ''';

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, [
        pageNumber,
      ]);

      final result = maps.map((map) {
        return QuranWord(
          suraNumber: _toInt(map['surah']),
          ayahNumber: _toInt(map['ayah']),
          pageNumber: pageNumber,
          lineNumber: _toInt(map['line_number']),
          text: map['text']?.toString() ?? '',
          wordId: _toInt(map['word_id']),
          lineType: map['line_type']?.toString(),
          isCentered: _toInt(map['is_centered']) == 1,
          headerSurah: _toInt(map['header_surah']),
          position: null, // No longer tracked internally like this
        );
      }).toList();
      _pageWordsCache[pageNumber] = result;
      return result;
    } catch (e) {
      // debugPrint('🔴 Error in getPageWords($pageNumber): $e');
      return [];
    }
  }

  Future<List<PageLine>> getPageLines(int pageNumber) async {
    if (_pageLinesCache.containsKey(pageNumber)) {
      return _pageLinesCache[pageNumber]!;
    }
    try {
      final db = await instance.database;
      const query = '''
        SELECT 
          page_number, 
          line_number, 
          line_type, 
          is_centered, 
          first_word_id, 
          last_word_id, 
          surah_number
        FROM map_db.pages
        WHERE page_number = ?
        ORDER BY line_number ASC
      ''';
      final List<Map<String, dynamic>> maps = await db.rawQuery(query, [
        pageNumber,
      ]);
      final result = maps.map((map) => PageLine.fromJson(map)).toList();
      _pageLinesCache[pageNumber] = result;
      return result;
    } catch (e) {
      // debugPrint('🔴 Error in getPageLines($pageNumber): $e');
      return [];
    }
  }

  /// New Method: Fetches exact words belonging to a specific surah and ayah.
  Future<List<QuranWord>> getWordsForVerse(
    int surahNumber,
    int verseNumber,
  ) async {
    try {
      final db = await instance.database;
      const query = '''
        SELECT 
          id as word_id, 
          text, 
          surah, 
          ayah
        FROM words
        WHERE surah = ? AND ayah = ?
        ORDER BY id ASC
      ''';

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, [
        surahNumber,
        verseNumber,
      ]);

      return maps.map((map) {
        return QuranWord(
          suraNumber: _toInt(map['surah']),
          ayahNumber: _toInt(map['ayah']),
          pageNumber: null, // Column doesn't exist in words table
          text: map['text']?.toString() ?? '',
          wordId: _toInt(map['word_id']),
        );
      }).toList();
    } catch (e) {
      // debugPrint('🔴 Error in getWordsForVerse($surahNumber, $verseNumber): $e');
      return [];
    }
  }

  /// New Method: Fetches exact words belonging to a specific line.
  Future<List<QuranWord>> getWordsForLine(
    int firstWordId,
    int lastWordId,
  ) async {
    try {
      final db = await instance.database;
      const query = '''
        SELECT 
          id as word_id, 
          text, 
          surah, 
          ayah
        FROM words
        WHERE id BETWEEN ? AND ?
        ORDER BY id ASC
      ''';

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, [
        firstWordId,
        lastWordId,
      ]);

      return maps.map((map) {
        return QuranWord(
          suraNumber: _toInt(map['surah']),
          ayahNumber: _toInt(map['ayah']),
          text: map['text']?.toString() ?? '',
          wordId: _toInt(map['word_id']),
        );
      }).toList();
    } catch (e) {
      // debugPrint('🔴 Error in getWordsForLine($firstWordId, $lastWordId): $e');
      return [];
    }
  }
}
