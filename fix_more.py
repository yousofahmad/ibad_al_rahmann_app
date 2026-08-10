# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\more_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add state variables
state_vars = '''  String _unlockMode = 'none';
  double _unlockVolume = 1.0;
'''
content = content.replace('bool _isEnabled = false;', 'bool _isEnabled = false;\n' + state_vars)

# 2. Add to _loadSettings
load_settings = '''    final unlockMode = prefs.getString('flutter.salah_unlock_mode') ?? 'none';
    final unlockVolume = prefs.getDouble('flutter.salah_unlock_volume') ?? 1.0;'''
load_settings_setstate = '''      _unlockMode = unlockMode;
      _unlockVolume = unlockVolume;'''

if 'final unlockMode' not in content:
    content = content.replace("final enabled = prefs.getBool('salawat_reminder_enabled') ?? false;", "final enabled = prefs.getBool('salawat_reminder_enabled') ?? false;\n" + load_settings)
    content = content.replace('_isEnabled = enabled;', '_isEnabled = enabled;\n' + load_settings_setstate)

# 3. Add to _saveSettings
save_settings = '''
    await prefs.setString('flutter.salah_unlock_mode', _unlockMode);
    await prefs.setDouble('flutter.salah_unlock_volume', _unlockVolume);
'''
if 'flutter.salah_unlock_mode' not in content:
    content = content.replace("await prefs.setBool('salawat_reminder_enabled', _isEnabled);", "await prefs.setBool('salawat_reminder_enabled', _isEnabled);" + save_settings)

# 4. Add UI section
ui_section = '''              Divider(height: 30.h),
              const Text(
                "الصلاة على النبي عند فتح الشاشة",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              DropdownButton<String>(
                value: _unlockMode,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text("إيقاف", style: TextStyle(fontFamily: AppConsts.cairo))),
                  DropdownMenuItem(value: 'saly_3ala_mo7amad', child: Text("الصوت الأول", style: TextStyle(fontFamily: AppConsts.cairo))),
                  DropdownMenuItem(value: 'salah_2', child: Text("الصوت الثاني", style: TextStyle(fontFamily: AppConsts.cairo))),
                  DropdownMenuItem(value: 'both', child: Text("كلاهما (عشوائي)", style: TextStyle(fontFamily: AppConsts.cairo))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _unlockMode = val);
                },
              ),
              if (_unlockMode != 'none') ...[
                SizedBox(height: 10.h),
                Row(
                  children: [
                    const Icon(Icons.volume_down_rounded, color: Colors.grey),
                    Expanded(
                      child: Slider(
                        value: _unlockVolume,
                        activeColor: const Color(0xFFD0A871),
                        onChanged: (val) {
                          setState(() => _unlockVolume = val);
                        },
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded, color: Colors.grey),
                  ],
                ),
                Text(
                  "مستوى صوت مخصص لهذا التنبيه",
                  style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 11.sp, color: Colors.grey),
                ),
              ],
'''

# Find insertion point just before "ساعات الهدوء"
regex = r'(SizedBox\(height: 20\.h\),\s*const Text\(\s*"ساعات الهدوء:")'
if 'الصلاة على النبي عند فتح الشاشة' not in content:
    content = re.sub(regex, ui_section.replace('\\', '\\\\') + r'\1', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated more_screen.dart successfully")