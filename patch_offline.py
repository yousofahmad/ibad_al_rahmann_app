with open("lib/features/quran_reciters/data/models/reciter_model.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = "final reciterDir = Directory('${dir.path}/audio_reciters/$folderName');"
replacement = "final reciterDir = Directory('${dir.path}/quran_offline/$folderName');"

if target in content:
    content = content.replace(target, replacement)
    with open("lib/features/quran_reciters/data/models/reciter_model.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced audio_reciters with quran_offline")
else:
    print("Target not found")
