import re
import glob
import os

for filepath in glob.glob('lib/features/quran/**/*.dart', recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    changed = False
    
    if 'EasyPageScrollPhysics' in content:
        content = content.replace('const EasyPageScrollPhysics()', 'const BouncingScrollPhysics(parent: PageScrollPhysics())')
        content = content.replace('EasyPageScrollPhysics()', 'BouncingScrollPhysics(parent: PageScrollPhysics())')
        content = re.sub(r"import '[^']*easy_page_scroll_physics\.dart';", "", content)
        changed = True
        
    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
