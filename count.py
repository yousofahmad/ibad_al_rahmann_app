import os
base_path = "scratch/audio_sources"
c = 0
for folder_name in os.listdir(base_path):
    folder_path = os.path.join(base_path, folder_name)
    if os.path.isdir(folder_path):
        surah_file = os.path.join(folder_path, "surah.json")
        if not os.path.exists(surah_file):
            print(f"Missing surah.json in {folder_name}")
        c += 1
print(f"Total dirs: {c}")
