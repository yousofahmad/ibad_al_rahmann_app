with open("lib/core/data/quran_audio_index.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(" 'duration': None}", " 'duration': null}")

with open("lib/core/data/quran_audio_index.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Replaced None with null")
