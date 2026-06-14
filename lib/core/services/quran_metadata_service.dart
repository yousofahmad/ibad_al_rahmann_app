import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';

class QuranMetadataService {
  static final QuranMetadataService instance = QuranMetadataService._();
  QuranMetadataService._();

  List<dynamic> _surahs = [];
  final Map<int, Map<String, dynamic>> _juzData = {};
  final Map<int, Map<String, dynamic>> _hizbData = {};
  final Map<int, Map<String, dynamic>> _rubData = {};

  bool _isInitialized = false;

  List<dynamic> get surahs => _surahs;
  List<Map<String, dynamic>> get juzList => _juzData.values.toList();
  List<Map<String, dynamic>> get hizbList => _hizbData.values.toList();
  List<Map<String, dynamic>> get rubList => _rubData.values.toList();

  Future<void> init() async {
    if (_isInitialized) return;

    await Future.wait([
      _loadSurahs(),
      _loadMetadata('assets/data/quran-metadata-juz.json', 30, _juzData),
      _loadMetadata('assets/data/quran-metadata-hizb.json', 60, _hizbData),
      _loadMetadata('assets/data/quran-metadata-rub.json', 240, _rubData),
    ]);

    _isInitialized = true;
  }

  Future<void> _loadSurahs() async {
    final String quranJson = await rootBundle.loadString(AppConsts.surahsJson);
    _surahs = jsonDecode(quranJson);
  }

  Future<void> _loadMetadata(
    String path,
    int count,
    Map<int, Map<String, dynamic>> target,
  ) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      for (int i = 1; i <= count; i++) {
        final entry = decoded['$i'];
        if (entry != null) {
          target[i] = Map<String, dynamic>.from(entry as Map);
        }
      }
    } catch (e) {
      // Handle or log error
    }
  }
}
