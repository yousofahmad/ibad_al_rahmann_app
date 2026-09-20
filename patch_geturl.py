with open("lib/features/quran_audio/logic/quran_player/quran_player_cubit.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = '''    if (isOffline) {
      return await ReciterAudioHelper.getOfflineSurahPath(reciter!.folderName, surahNum);
    }'''

replacement = '''    final downloadService = QuranAudioDownloadService();
    final offlinePath = await downloadService.getOfflineSurahPath(reciter!.folderName, surahNum);
    if (await java_io.File(offlinePath).exists()) {
      return offlinePath;
    }

    if (isOffline) {
      return await ReciterAudioHelper.getOfflineSurahPath(reciter!.folderName, surahNum);
    }'''

if target in content:
    content = content.replace(target, replacement)
    content = "import 'package:ibad_al_rahmann/features/quran_reciters/services/quran_audio_download_service.dart';\nimport 'dart:io' as java_io;\n" + content
    with open("lib/features/quran_audio/logic/quran_player/quran_player_cubit.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Modified getSurahUrl")
else:
    print("Target not found")
