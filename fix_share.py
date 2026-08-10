# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\share_setup_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix TabController initialIndex
old_init = r'_tabController = TabController\(length: 2, vsync: this\);'
new_init = r'''final initialMode = context.read<ShareProvider>().shareMode;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialMode == ShareMode.text ? 1 : 0);'''
content = re.sub(old_init, new_init, content)

# 2. Add onCopy property to _Toolbar class
content = content.replace('final VoidCallback? onToggleColor;', 'final VoidCallback? onToggleColor;\n  final VoidCallback? onCopy;')
content = content.replace('this.onToggleColor,\n  });', 'this.onToggleColor,\n    this.onCopy,\n  });')

# 3. Add copy button UI to _Toolbar
button_ui = '''              _ToolbarButton(
                icon: Icons.color_lens_rounded,
                label: 'لون الورقة',
                primary: primary,
                onTap: isCapturing ? null : onToggleColor,
              ),
              SizedBox(width: 8.w),
            ],
            if (onCopy != null) ...[
              _ToolbarButton(
                icon: Icons.copy_rounded,
                label: 'نسخ',
                primary: primary,
                onTap: isCapturing ? null : onCopy,
              ),
              SizedBox(width: 8.w),
            ],'''
# I'll just use regex to insert the copy button after the onToggleColor block
regex_toggle = r'if \(onToggleColor \!\= null\) \.\.\.\[([\s\S]*?)SizedBox\(width: 8\.w\),\n\s*\]\,'
replacement = r'''if (onToggleColor != null) ...[\1SizedBox(width: 8.w),
            ],
            if (onCopy != null) ...[
              _ToolbarButton(
                icon: Icons.copy_rounded,
                label: 'نسخ',
                primary: primary,
                onTap: isCapturing ? null : onCopy,
              ),
              SizedBox(width: 8.w),
            ],'''
content = re.sub(regex_toggle, replacement, content)

# 4. Pass onCopy to _Toolbar instantiation
old_toolbar = r'''              _Toolbar\(
                primary: primary,
                isCapturing: _isCapturing \|\| provider\.isLoading,
                sheetBg: sheetBg,
                onShare: provider\.shareMode == ShareMode\.image
                    \? _shareImage
                    : \(\) \=\> _shareText\(provider\),
                onSave: provider\.shareMode == ShareMode\.image \? _saveImage : null,
                onToggleColor: provider\.shareMode == ShareMode\.image \? _cyclePaperColor : null,
              \),'''
new_toolbar = '''              _Toolbar(
                primary: primary,
                isCapturing: _isCapturing || provider.isLoading,
                sheetBg: sheetBg,
                onShare: provider.shareMode == ShareMode.image
                    ? _shareImage
                    : () => _shareText(provider),
                onSave: provider.shareMode == ShareMode.image ? _saveImage : null,
                onToggleColor: provider.shareMode == ShareMode.image ? _cyclePaperColor : null,
                onCopy: provider.shareMode == ShareMode.text
                    ? () {
                        final text = provider.buildShareText(withLogo: provider.showLogo);
                        Clipboard.setData(ClipboardData(text: text));
                        ShareHelper.showTopNotification(context, 'تم نسخ النص ✓');
                      }
                    : null,
              ),'''
content = re.sub(old_toolbar, new_toolbar, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")