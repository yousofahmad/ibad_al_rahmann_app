import os

files_to_patch = [
    r'd:\flutter\ibad_al_rahmann\lib\features\quran\ui\quran_screen.dart',
    r'd:\flutter\ibad_al_rahmann\lib\features\quran\ui\mushaf_screen.dart',
    r'd:\flutter\ibad_al_rahmann\lib\features\wird\ui\quran_wird_screen.dart',
    r'd:\flutter\ibad_al_rahmann\lib\screens\kahf_screen.dart'
]

for file_path in files_to_patch:
    if not os.path.exists(file_path):
        print(f"Skipping {file_path} (not found)")
        continue
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    if 'wakelock_plus.dart' not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:wakelock_plus/wakelock_plus.dart';")
        
        # Patch initState
        if 'void initState() {' in content:
            content = content.replace('void initState() {', 'void initState() {\n    super.initState();\n    WakelockPlus.enable();')
        
        # Patch dispose
        if 'void dispose() {' in content:
            content = content.replace('void dispose() {', 'void dispose() {\n    WakelockPlus.disable();\n    super.dispose();')
            
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Patched Wakelock in {file_path}")

# Now for the Dark mode index colors
# The user said the text is dark blue on black.
fehres_file = r'd:\flutter\ibad_al_rahmann\lib\features\quran\ui\widgets\fehres\quran_fehres_dialog.dart'
if os.path.exists(fehres_file):
    with open(fehres_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We replace any literal Color(0xFF1E3A8A) with dynamic color
    old_color_1 = "Color(0xFF1E3A8A)"
    new_color_1 = "(Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF1E3A8A))"
    
    if old_color_1 in content:
        content = content.replace(old_color_1, new_color_1)
        # We need to make sure we don't end up with `const (Theme.of...)`
        content = content.replace("const (Theme", "(Theme")
        
        with open(fehres_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Patched Quran index dark mode colors in quran_fehres_dialog.dart")
