import os
import re

dir_path = "lib/features/quran"

import_statement = "import 'package:ibad_al_rahmann/features/quran/ui/widgets/scroll/easy_page_scroll_physics.dart';"

for root, _, files in os.walk(dir_path):
    for file in files:
        if file.endswith(".dart"):
            file_path = os.path.join(root, file)
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()

            modified = False
            
            # Replace physics: const BouncingScrollPhysics(parent: PageScrollPhysics())
            if "PageScrollPhysics()" in content:
                content = re.sub(r'PageScrollPhysics\(\)', r'EasyPageScrollPhysics()', content)
                modified = True

            # If PageView is used without physics, we should add it?
            # It's better to explicitly add physics to PageView.builder if missing.
            def replacer(match):
                block = match.group(0)
                if 'physics:' not in block:
                    return block.replace('PageView.builder(', 'PageView.builder(\n      physics: const EasyPageScrollPhysics(),')
                return block
            
            new_content = re.sub(r'PageView\.builder\([^)]+\)', replacer, content, flags=re.DOTALL)
            if new_content != content:
                content = new_content
                modified = True

            if modified:
                if "EasyPageScrollPhysics" in content and import_statement not in content:
                    content = import_statement + "\n" + content
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Modified {file_path}")
