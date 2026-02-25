import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'quran_word.dart';

class QuranWbwDbHelper {
  static final QuranWbwDbHelper instance = QuranWbwDbHelper._init();
  static Database? _database;

  QuranWbwDbHelper._init();

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
      } catch (_) {}

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

    final db = await openDatabase(mainDbPath, readOnly: true);

    // Attach the layout database
    await db.execute("ATTACH DATABASE '$mapDbPath' AS map_db");

    return db;
  }

  /// Query all words and headers for a specific page.
  /// Merges `words` from main DB and `pages` from map_db dynamically.
  Future<List<QuranWord>> getPageWords(int pageNumber) async {
    final db = await instance.database;

    final query = '''
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

    return maps.map((map) {
      return QuranWord(
        suraNumber: map['surah'],
        ayahNumber: map['ayah'],
        pageNumber: pageNumber,
        lineNumber: map['line_number'],
        text: map['text'] ?? '',
        wordId: map['word_id'],
        lineType: map['line_type'],
        isCentered: map['is_centered'] == 1,
        headerSurah: map['header_surah'],
        position: null, // No longer tracked internally like this
      );
    }).toList();
  }
}
