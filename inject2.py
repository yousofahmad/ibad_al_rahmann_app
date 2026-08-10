import re
import sys

content = open(r'd:\flutter\ibad_al_rahmann\lib\screens\settings_screen.dart', 'r', encoding='utf-8').read()

toggle = '''
            _buildListTile(
              "تشغيل في مكبر الصوت",
              "سماع صوت الأذان من مكبر الهاتف الخارجي حتى عند توصيل سماعات الأذن",
              Icons.speaker_phone_rounded,
              trailing: Switch(
                value: _forceSpeaker,
                activeThumbColor: const Color(0xFFD0A871),
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('force_speaker', val);
                  setState(() => _forceSpeaker = val);
                },
              ),
            ),
'''

if '_forceSpeaker' not in content:
    # 1. Add variable
    content = content.replace("String _audioStream = 'alarm';", "String _audioStream = 'alarm';\n  bool _forceSpeaker = false;")
    
    # 2. Load variable
    content = content.replace("_audioStream = prefs.getString('audio_stream_channel') ?? 'alarm';", "_audioStream = prefs.getString('audio_stream_channel') ?? 'alarm';\n        _forceSpeaker = prefs.getBool('force_speaker') ?? false;")
    
    # 3. Add UI after audio stream dropdown
    idx = content.find('_buildSectionHeader("النسخ الاحتياطي والبيانات")')
    if idx != -1:
        new_content = content[:idx] + toggle + "          // 5. Backup & Data\n          " + content[idx:]
        open(r'd:\flutter\ibad_al_rahmann\lib\screens\settings_screen.dart', 'w', encoding='utf-8').write(new_content)
        print('Injected successfully')
    else:
        print('Section header not found')
else:
    print('Already injected')
