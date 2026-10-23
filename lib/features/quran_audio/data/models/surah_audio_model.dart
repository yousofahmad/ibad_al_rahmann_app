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
    final rawSurahNumber = json['surah_number'] ?? json['chapter_id'];
    final sNum = rawSurahNumber is num
        ? rawSurahNumber.toInt()
        : int.tryParse(rawSurahNumber?.toString() ?? '') ?? 1;
    final rawDuration = json['duration'];
    final durationSec = rawDuration is num
        ? rawDuration.toInt()
        : int.tryParse(rawDuration?.toString() ?? '') ?? 0;
    return SurahAudioModel(
      url: json['audio_url']?.toString() ?? '',
      name: sNum >= 1 && sNum <= quranSurahs.length
          ? quranSurahs[sNum - 1]
          : 'سورة',
      surahNumber: sNum,
      durationSec: durationSec,
    );
  }
}
