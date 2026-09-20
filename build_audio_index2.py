import os
import json

base_path = "scratch/audio_sources"
reciters_data = {}

for folder_name in os.listdir(base_path):
    folder_path = os.path.join(base_path, folder_name)
    if os.path.isdir(folder_path):
        surah_file = os.path.join(folder_path, "surah.json")
        if os.path.exists(surah_file):
            with open(surah_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                sorted_data = {}
                for k in sorted(data.keys(), key=lambda x: int(x) if x.isdigit() else 0):
                    if k.isdigit():
                        sorted_data[k] = data[k]
                reciters_data[folder_name] = sorted_data

dart_code = "/// GENERATED FILE - DO NOT MODIFY BY HAND\n\n"
dart_code += "class QuranAudioIndex {\n"
dart_code += "  static const Map<String, Map<String, Map<String, dynamic>>> surahData = {\n"

for reciter, surahs in reciters_data.items():
    dart_code += f"    '{reciter}': {{\n"
    for surah_idx, surah_info in surahs.items():
        surah_number = surah_info['surah_number']
        audio_url = surah_info['audio_url']
        duration = surah_info['duration']
        dart_code += f"      '{surah_idx}': {{'surah_number': {surah_number}, 'audio_url': '{audio_url}', 'duration': {duration}}},\n"
    dart_code += "    },\n"
dart_code += "  };\n"
dart_code += "}\n"

import os
os.makedirs("lib/core/data", exist_ok=True)
with open("lib/core/data/quran_audio_index.dart", "w", encoding="utf-8") as f:
    f.write(dart_code)

print(f"Generated quran_audio_index.dart with {len(reciters_data)} reciters.")
