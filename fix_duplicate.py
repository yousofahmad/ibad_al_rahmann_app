# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\share_setup_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove duplicate onCopy declaration
content = content.replace('final VoidCallback? onToggleColor;\n  final VoidCallback? onCopy;\n  final VoidCallback? onCopy;', 'final VoidCallback? onToggleColor;\n  final VoidCallback? onCopy;')

# Remove duplicate this.onCopy,
content = content.replace('this.onToggleColor,\n    this.onCopy,\n    this.onCopy,\n  });', 'this.onToggleColor,\n    this.onCopy,\n  });')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")