import re

with open('lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _isPersistentSwitchLoading to _SettingsScreenState
if '_isPersistentSwitchLoading' not in content:
    content = content.replace('bool _autoSyncDrive = false;', 'bool _autoSyncDrive = false;\n  bool _isPersistentSwitchLoading = false;')

# Find the persistent notification switch
switch_match = '''            _buildListTile(
              "الإشعار الثابت",
              "عرض أوقات الصلاة دائمًا في شريط الإشعارات",
              FontAwesomeIcons.mobileScreen,
              trailing: Switch(
                value: _persistentNotification,
                activeThumbColor: const Color(0xFFD0A871),
                onChanged: (val) async {
                  final prefs = CacheHelper.prefs;
                  await prefs.setBool('persistent_notification_enabled', val);
                  await prefs.setBool('flutter.persistent_notification_enabled', val);
                  setState(() => _persistentNotification = val);
                  _prayerService.scheduleNotifications();
                },
              ),
            ),'''

replacement = '''            _buildListTile(
              "الإشعار الثابت",
              "عرض أوقات الصلاة دائمًا في شريط الإشعارات",
              FontAwesomeIcons.mobileScreen,
              trailing: _isPersistentSwitchLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD0A871)),
                    )
                  : Switch(
                      value: _persistentNotification,
                      activeThumbColor: const Color(0xFFD0A871),
                      onChanged: (val) async {
                        setState(() => _isPersistentSwitchLoading = true);
                        
                        // Yield to let the UI draw the loading indicator
                        await Future.delayed(const Duration(milliseconds: 50));
                        
                        final prefs = CacheHelper.prefs;
                        await prefs.setBool('persistent_notification_enabled', val);
                        await prefs.setBool('flutter.persistent_notification_enabled', val);
                        setState(() => _persistentNotification = val);
                        
                        await _prayerService.scheduleNotifications();
                        
                        if (mounted) {
                          setState(() => _isPersistentSwitchLoading = false);
                        }
                      },
                    ),
            ),'''

content = content.replace(switch_match, replacement)

# What if the exact whitespace doesn't match? Let's use regex.
pattern = r'_buildListTile\(\s*"الإشعار الثابت",\s*"عرض أوقات الصلاة دائمًا في شريط الإشعارات",\s*FontAwesomeIcons.mobileScreen,\s*trailing:\s*Switch\([\s\S]*?_prayerService\.scheduleNotifications\(\);\s*},\s*\),\s*\),'
content = re.sub(pattern, replacement.strip() + ',', content)

with open('lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
