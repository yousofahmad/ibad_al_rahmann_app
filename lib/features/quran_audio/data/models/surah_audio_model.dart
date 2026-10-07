import '../surah_list.dart';

class SurahAudioModel {
  final int surahNumber;
  final String url, name;
  final int durationSec;

  SurahAudioModel({
    required this.url,
    required this.name,
    required this.surahNumber,
    this.durationSec = 0,
  });

  factory SurahAudioModel.fromJson(Map<String, dynamic> json) {
    final sNum = (json['surah_number'] ?? json['chapter_id'] ?? 1) as int;
    return SurahAudioModel(
      url: json['audio_url']?.toString() ?? '',
      name: sNum >= 1 && sNum <= quranSurahs.length
          ? quranSurahs[sNum - 1]
          : 'سورة',
      surahNumber: sNum,
      durationSec: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }
}
