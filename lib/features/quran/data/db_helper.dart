import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:collection';
import 'quran_word.dart';
import 'models/page_line.dart';
import '../../../core/helpers/mushaf_format_repository.dart';
import 'mushaf_format_database_cache.dart';

class QuranWbwDbHelper {
  static final QuranWbwDbHelper instance = QuranWbwDbHelper._init();
  static Database? _database;
  final MushafFormatDatabaseCache<Database> _formatDatabases =
      MushafFormatDatabaseCache<Database>();
  String get _formatKey => MushafFormatRepository.instance.current.id;

  QuranWbwDbHelper._init();

  bool _isPreloading = false;
  final int _maxCachePages = 100;

  final LinkedHashMap<String, List<PageLine>> _pageLinesCache =
      LinkedHashMap<String, List<PageLine>>();
  final LinkedHashMap<String, List<QuranWord>> _pageWordsCache =
      LinkedHashMap<String, List<QuranWord>>();
  final Map<String, String> _verseGlyphsCache =
      {}; // key: 'format_surah_ayah', value: joined glyphs

  void _updateLru<K, V>(LinkedHashMap<K, V> cache, K key, V value, int max) {
    if (cache.containsKey(key)) {
      cache.remove(key);
    } else if (cache.length >= max) {
      cache.remove(cache.keys.first);
    }
    cache[key] = value;
  }

  List<PageLine>? getPageLinesSync(int pageNumber) {
    final key = '$_formatKey:$pageNumber';
    if (_pageLinesCache.containsKey(key)) {
      final val = _pageLinesCache.remove(key)!;
      _pageLinesCache[key] = val;
      return val;
    }
    return null;
  }

  List<QuranWord>? getPageWordsSync(int pageNumber) {
    final key = '$_formatKey:$pageNumber';
    if (_pageWordsCache.containsKey(key)) {
      final val = _pageWordsCache.remove(key)!;
      _pageWordsCache[key] = val;
      return val;
    }
    return null;
  }

  /// Get cached glyphs for a verse synchronously
  String? getVerseGlyphsSync(int surah, int ayah) =>
      _verseGlyphsCache['${_formatKey}_${surah}_$ayah'];

  void preloadAllPagesInBackground() async {
    if (_isPreloading) return;
    _isPreloading = true;

    // Small initial delay to let UI finish its first frame
    await Future.delayed(const Duration(seconds: 1));

    // Phase 1: Cache all verses glyphs in memory (very fast, one query)
    await cacheAllVersesGlyphs();
  }

  /// Single-pass caching of all verses in the Quran to memory.
  /// This makes the share list and previews instant.
  /// Optimized to prevent CursorWindow overflow by processing surahs one by one.
  /// TODO(H2): Monitor memory consumption of _verseGlyphsCache on low-RAM (<=1GB) devices; consider offloading to background isolate or LRU cache if RAM pressure occurs.
  Future<void> cacheAllVersesGlyphs() async {
    try {
      final db = await database;
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
          _verseGlyphsCache['${_formatKey}_${s}_$ayah'] = words.join(' ');
        });

        // Yield to main thread every surah to keep UI perfectly smooth
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      // debugPrint('🔴 Error in cacheAllVersesGlyphs: $e');
    }
  }

  Future<Database> get database async {
    final manager = MushafFormatRepository.instance;
    // Preserve the original built-in path exactly: it must not initialize the
    // optional format repository or touch its documents/cache files.
    if (manager.current.isBuiltin) {
      if (_database != null) return _database!;
      _database = await _initDB();
      return _database!;
    }
    await manager.initialize();
    final wordsPath = manager.getActiveWordsDatabasePath;
    final layoutPath = manager.getActiveLayoutDatabasePath;
    if (wordsPath == null || layoutPath == null) {
      if (_database != null) return _database!;
      _database = await _initDB();
      return _database!;
    }
    final key = manager.current.id;
    return _formatDatabases.getOrOpen(key, () async {
      final db = await openDatabase(wordsPath, readOnly: true);
      final attachedDbs = await db.rawQuery('PRAGMA database_list');
      final isAttached = attachedDbs.any(
        (database) =>
            database['name'] == 'map_db' ||
            database['file']?.toString() == layoutPath,
      );
      if (!isAttached) {
        await db.execute(
          "ATTACH DATABASE '${layoutPath.replaceAll("'", "''")}' AS map_db",
        );
      }
      return db;
    });
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
    final formatKey = _formatKey;
    final cached = getPageWordsSync(pageNumber);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final db = await database;

      const query = '''
        SELECT 
          m.line_number, 
          m.line_type, 
          m.is_centered, 
          m.surah_number as header_surah, 
          w.id as word_id, 
          w.text, 
          w.surah, 
          w.ayah,
          w.word AS word_position
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
          position: _toInt(map['word_position']),
        );
      }).toList();
      if (_formatKey == formatKey && result.isNotEmpty) {
        _updateLru(
          _pageWordsCache,
          '$formatKey:$pageNumber',
          result,
          _maxCachePages,
        );
      }
      return result;
    } catch (e) {
      // debugPrint('🔴 Error in getPageWords($pageNumber): $e');
      return [];
    }
  }

  Future<List<PageLine>> getPageLines(int pageNumber) async {
    final formatKey = _formatKey;
    final cached = getPageLinesSync(pageNumber);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final db = await database;
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
      if (_formatKey == formatKey && result.isNotEmpty) {
        _updateLru(
          _pageLinesCache,
          '$formatKey:$pageNumber',
          result,
          _maxCachePages,
        );
      }
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
      final db = await database;
      const query = '''
        SELECT 
          id as word_id, 
          text, 
          surah, 
          ayah,
          word AS word_position
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
          position: _toInt(map['word_position']),
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
      final db = await database;
      const query = '''
        SELECT 
          id as word_id, 
          text, 
          surah, 
          ayah,
          word AS word_position
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
          position: _toInt(map['word_position']),
        );
      }).toList();
    } catch (e) {
      // debugPrint('🔴 Error in getWordsForLine($firstWordId, $lastWordId): $e');
      return [];
    }
  }
}
