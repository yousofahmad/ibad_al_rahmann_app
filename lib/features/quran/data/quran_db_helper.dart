import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class QuranDbHelper {
  static final QuranDbHelper instance = QuranDbHelper._init();
  static Database? _database;

  QuranDbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('qpc-v1-15-lines.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    final exists = await databaseExists(path);

    if (!exists) {
      // Make sure the parent directory exists
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

      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
    } // else: database already exists

    // Open the database
    return await openDatabase(path, readOnly: true);
  }

  /// Queries the database to return the 15 lines of a specific page.
  /// Uses the standardized KFGQPC schema linking `pages` and `words` tables.
  Future<List<Map<String, dynamic>>> getPageLines(int pageNumber) async {
    final db = await instance.database;

    // Join the `pages` table with the `words` table using IDs
    // GROUP_CONCAT automatically concatenates all words in a line into a single string.
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT 
        p.line_number, 
        GROUP_CONCAT(w.text, ' ') as line_text, 
        p.is_centered,
        p.line_type
      FROM pages p
      JOIN words w ON w.id BETWEEN p.first_word_id AND p.last_word_id
      WHERE p.page_number = ?
      GROUP BY p.line_number
      ORDER BY p.line_number ASC
    ''',
      [pageNumber],
    );

    return result;
  }
}
