import 'package:ibad_al_rahmann/core/networking/api_keys.dart';

import '../surah_list.dart';

class SurahAudioModel {
  final int surahNumber;
  final String url, name;

  SurahAudioModel({
    required this.url,
    required this.name,
    required this.surahNumber,
  });
  factory SurahAudioModel.fromJson(Map<String, dynamic> json) {
    return SurahAudioModel(
      url: json['audio_url'],
      name: quranSurahs[json[ApiKeys.chapterId] - 1],
      surahNumber: json['chapter_id'],
    );
  }
}
