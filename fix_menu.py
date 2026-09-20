import re

with open('lib/features/quran/ui/widgets/menus/single_tap_menu.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'quran_readers_screen.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/features/quran_reciters/ui/quran_readers_screen.dart';\nimport 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';\nimport 'package:font_awesome_flutter/font_awesome_flutter.dart';")

action_btn = '''
                      _ActionButton(
                        icon: FontAwesomeIcons.headphones,
                        label: 'المصحف الصوتي',
                        onTap: () {
                          widget.onDismiss();
                          context.push(const QuranReadersScreen());
                        },
                        isEnabled: !_isBusy,
                        color: onBar,
                        iconSize: 18,
                      ),
                      _divider(onBarSubtle),
'''

content = content.replace('''                      _ActionButton(
                        icon: Icons.color_lens_rounded,''', action_btn + '''                      _ActionButton(
                        icon: Icons.color_lens_rounded,''')

with open('lib/features/quran/ui/widgets/menus/single_tap_menu.dart', 'w', encoding='utf-8') as f:
    f.write(content)
