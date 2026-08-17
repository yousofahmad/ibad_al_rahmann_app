import os
import glob

files = glob.glob(r'd:\flutter\ibad_al_rahmann\lib\features\quran\**\*.dart', recursive=True) + glob.glob(r'd:\flutter\ibad_al_rahmann\lib\features\wird\**\*.dart', recursive=True)

for file in files:
    if os.path.isfile(file):
        with open(file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        if 'PageView.builder(' in content and 'allowImplicitScrolling:' not in content:
            content = content.replace('PageView.builder(', 'PageView.builder(\n      allowImplicitScrolling: true,')
            with open(file, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Patched allowImplicitScrolling in {file}")

