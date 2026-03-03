import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';

class TafsirHelper {
  static late List _tafsir;

  static Future<void> initTafsir() async {
    _tafsir = await _getTafsirData(AppConsts.tafsirJson);
  }

  static Future _getTafsirData(String jsonFile) async {
    String jsonString = await rootBundle.loadString(jsonFile);
    final jsonResponse = json.decode(jsonString);

    return jsonResponse.map((e) => TafsirModel.fromJson(e)).toList();
  }

  static String getVerseTafsir(int surahNumber, int verseNumber) {
    return _tafsir
        .firstWhere(
          (e) => e.surahNumber == surahNumber && e.verseNumber == verseNumber,
        )
        .text;
  }
}

class TafsirModel {
  final int surahNumber, verseNumber;
  final String text;

  TafsirModel({
    required this.surahNumber,
    required this.verseNumber,
    required this.text,
  });

  factory TafsirModel.fromJson(Map<String, dynamic> json) {
    return TafsirModel(
      surahNumber: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      verseNumber: int.tryParse(json['aya']?.toString() ?? '') ?? 0,
      text: json['text']?.toString() ?? '',
    );
  }
}
