with open("lib/features/quran_reciters/data/models/reciter_model.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = '''    if (_surahsCache.containsKey(reciter.folderName) && _surahsCache[reciter.folderName]!.isNotEmpty) {
      return _surahsCache[reciter.folderName]!;
    }'''

replacement = '''    if (_surahsCache.containsKey(reciter.folderName) && _surahsCache[reciter.folderName]!.isNotEmpty) {
      return _surahsCache[reciter.folderName]!;
    }

    if (QuranAudioIndex.surahData.containsKey(reciter.folderName)) {
      final data = QuranAudioIndex.surahData[reciter.folderName]!;
      final result = <int, SurahAudioItem>{};
      data.forEach((k, v) {
        final item = SurahAudioItem.fromJson(Map<String, dynamic>.from(v));
        result[item.surahNumber] = item;
      });
      _surahsCache[reciter.folderName] = result;
      return result;
    }'''

if target in content:
    content = content.replace(target, replacement)
    content = "import 'package:ibad_al_rahmann/core/data/quran_audio_index.dart';\n" + content
    with open("lib/features/quran_reciters/data/models/reciter_model.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added QuranAudioIndex logic to getSurahs")
else:
    print("Target not found")
