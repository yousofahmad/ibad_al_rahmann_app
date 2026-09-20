with open("lib/features/quran_reciters/services/quran_audio_download_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("''${dir.path}", "'${dir.path}")
content = content.replace("id}''", "id}'")
content = content.replace("''${offlineDir.path}", "'${offlineDir.path}")
content = content.replace(".mp3''", ".mp3'")

with open("lib/features/quran_reciters/services/quran_audio_download_service.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed string quotes")
