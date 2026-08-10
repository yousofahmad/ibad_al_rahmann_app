# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\more_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure audioplayers is imported
if "import 'package:audioplayers/audioplayers.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:audioplayers/audioplayers.dart';")

start = content.find('class SalawatReminderDialog')
end = content.find('// end SalawatReminderDialog')
if end == -1:
    end = content.find('class _MoreScreenState', start) # wait, SalawatReminderDialog is AT THE END of more_screen.dart
    if end == -1:
        end = len(content)

new_dialog = '''class SalawatReminderDialog extends StatefulWidget {
  const SalawatReminderDialog({super.key});

  @override
  State<SalawatReminderDialog> createState() => _SalawatReminderDialogState();
}

class _SalawatReminderDialogState extends State<SalawatReminderDialog> {
  bool _isEnabled = false;
  String _unlockMode = 'none';
  double _unlockVolume = 1.0;
  String _periodicSound = 'saly_3ala_mo7amad';
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingSound;

  final TextEditingController _controller = TextEditingController();
  List<int> _selectedDays = [DateTime.friday];
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);

  final Map<int, String> _daysMap = {
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingSound = null);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('salawat_reminder_enabled') ?? false;
    final unlockMode = prefs.getString('flutter.salah_unlock_mode') ?? 'none';
    final unlockVolume = prefs.getDouble('flutter.salah_unlock_volume') ?? 1.0;
    final periodicSound = prefs.getString('flutter.salawat_periodic_sound') ?? 'saly_3ala_mo7amad';
    final minutes = prefs.getInt('salawat_reminder_minutes') ?? 60;
    final daysList = prefs.getStringList('salawat_reminder_days') ?? [DateTime.friday.toString()];

    final qhStartHour = prefs.getInt('quiet_hours_start_hour') ?? 23;
    final qhStartMin = prefs.getInt('quiet_hours_start_minute') ?? 0;
    final qhEndHour = prefs.getInt('quiet_hours_end_hour') ?? 7;
    final qhEndMin = prefs.getInt('quiet_hours_end_minute') ?? 0;

    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _unlockMode = unlockMode;
        _unlockVolume = unlockVolume;
        _periodicSound = periodicSound;
        _controller.text = minutes.toString();
        _selectedDays = daysList.map((e) => int.parse(e)).toList();
        _quietHoursStart = TimeOfDay(hour: qhStartHour, minute: qhStartMin);
        _quietHoursEnd = TimeOfDay(hour: qhEndHour, minute: qhEndMin);
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = int.tryParse(_controller.text) ?? 60;

    await prefs.setBool('salawat_reminder_enabled', _isEnabled);
    await prefs.setInt('salawat_reminder_minutes', minutes);
    await prefs.setString('flutter.salah_unlock_mode', _unlockMode);
    await prefs.setDouble('flutter.salah_unlock_volume', _unlockVolume);
    await prefs.setString('flutter.salawat_periodic_sound', _periodicSound);
    await prefs.setStringList('salawat_reminder_days', _selectedDays.map((e) => e.toString()).toList());
    await prefs.setInt('quiet_hours_start_hour', _quietHoursStart.hour);
    await prefs.setInt('quiet_hours_start_minute', _quietHoursStart.minute);
    await prefs.setInt('quiet_hours_end_hour', _quietHoursEnd.hour);
    await prefs.setInt('quiet_hours_end_minute', _quietHoursEnd.minute);

    // Call MethodChannel to start/stop the ScreenUnlockForegroundService natively
    // We will do this later natively. 
    const platform = MethodChannel('app.ibad_al_rahmann/background');
    try {
      if (_unlockMode != 'none') {
        await platform.invokeMethod('startScreenUnlockService');
      } else {
        await platform.invokeMethod('stopScreenUnlockService');
      }
    } catch (e) {
      debugPrint("Failed to toggle service: ");
    }

    if (mounted) {
      Navigator.pop(context);
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('تم حفظ الإعدادات بنجاح', style: TextStyle(fontFamily: AppConsts.expoArabic)),
          backgroundColor: const Color(0xFFD0A871),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
    }

    if (_isEnabled && minutes > 0 && _selectedDays.isNotEmpty) {
      NotificationService.scheduleSalawatReminders(minutes, _selectedDays);
    } else {
      NotificationService.scheduleSalawatReminders(0, []);
    }
  }

  Future<void> _playSound(String soundName) async {
    if (_playingSound == soundName) {
      await _audioPlayer.stop();
      setState(() => _playingSound = null);
    } else {
      await _audioPlayer.stop();
      setState(() => _playingSound = soundName);
      // Determine file extension
      String path = 'audio/.mp3';
      await _audioPlayer.play(AssetSource(path));
    }
  }

  Widget _buildSoundSelector({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
    bool showNone = false,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFD0A871).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD0A871)),
                    dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                    items: [
                      if (showNone)
                        const DropdownMenuItem(value: 'none', child: Text("إيقاف", style: TextStyle(fontFamily: AppConsts.cairo))),
                      const DropdownMenuItem(value: 'saly_3ala_mo7amad', child: Text("الصوت الأول", style: TextStyle(fontFamily: AppConsts.cairo))),
                      const DropdownMenuItem(value: 'salah_2', child: Text("الصوت الثاني", style: TextStyle(fontFamily: AppConsts.cairo))),
                      if (showNone)
                        const DropdownMenuItem(value: 'both', child: Text("كلاهما (عشوائي)", style: TextStyle(fontFamily: AppConsts.cairo))),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ),
              if (value != 'none' && value != 'both') ...[
                SizedBox(width: 8.w),
                IconButton(
                  icon: Icon(
                    _playingSound == value ? Icons.stop_circle : Icons.play_circle_fill,
                    color: _playingSound == value ? Colors.red : const Color(0xFFD0A871),
                  ),
                  onPressed: () => _playSound(value),
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietHoursStart : _quietHoursEnd,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFD0A871), onPrimary: Colors.white, onSurface: Colors.black,
          ),
        ),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _quietHoursStart = picked;
        else _quietHoursEnd = picked;
      });
    }
  }

  Widget _quietTimePicker(String label, TimeOfDay time, VoidCallback onTap) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontFamily: AppConsts.cairo, color: Colors.grey)),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              time.format(context),
              style: const TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFFD0A871).withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: const Center(
                child: Text("تنبيهات الصلاة على النبي ﷺ", 
                  style: TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFD0A871))
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Periodic Reminders
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("تنبيهات دورية", style: TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold, fontSize: 16)),
                        Switch(
                          value: _isEnabled,
                          activeColor: const Color(0xFFD0A871),
                          onChanged: (val) => setState(() => _isEnabled = val),
                        ),
                      ],
                    ),
                    if (_isEnabled) ...[
                      SizedBox(height: 16.h),
                      _buildSoundSelector(
                        title: "صوت التذكير الدوري:",
                        value: _periodicSound,
                        onChanged: (val) { if (val != null) setState(() => _periodicSound = val); },
                      ),
                      SizedBox(height: 16.h),
                      const Text("الأيام:", style: TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w, runSpacing: 8.h,
                        children: _daysMap.entries.map((e) => FilterChip(
                          label: Text(e.value, style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 12.sp, color: _selectedDays.contains(e.key) ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
                          selected: _selectedDays.contains(e.key),
                          onSelected: (val) => setState(() { val ? _selectedDays.add(e.key) : _selectedDays.remove(e.key); }),
                          selectedColor: const Color(0xFFD0A871),
                          checkmarkColor: Colors.white,
                        )).toList(),
                      ),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "تكرار كل (دقيقة)",
                          labelStyle: const TextStyle(fontFamily: AppConsts.cairo, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFD0A871)), borderRadius: BorderRadius.circular(12.r)),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      const Text("ساعات الهدوء (لن يتم التنبيه خلالها):", style: TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _quietTimePicker("من", _quietHoursStart, () => _pickTime(true)),
                          _quietTimePicker("إلى", _quietHoursEnd, () => _pickTime(false)),
                        ],
                      ),
                    ],
                    Divider(height: 40.h, color: Colors.grey.withOpacity(0.2)),
                    // Section 2: Lock Screen
                    const Text("عند فتح قفل الشاشة", style: TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 12.h),
                    _buildSoundSelector(
                      title: "اختر الصوت:",
                      value: _unlockMode,
                      showNone: true,
                      onChanged: (val) { if (val != null) setState(() => _unlockMode = val); },
                    ),
                    if (_unlockMode != 'none') ...[
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          const Icon(Icons.volume_down, color: Colors.grey, size: 20),
                          Expanded(
                            child: Slider(
                              value: _unlockVolume,
                              activeColor: const Color(0xFFD0A871),
                              inactiveColor: const Color(0xFFD0A871).withOpacity(0.2),
                              onChanged: (val) => setState(() => _unlockVolume = val),
                            ),
                          ),
                          const Icon(Icons.volume_up, color: Colors.grey, size: 20),
                        ],
                      ),
                      Text("مستوى صوت مستقل لفتح الشاشة", style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 11.sp, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء", style: TextStyle(fontFamily: AppConsts.expoArabic, color: Colors.grey)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD0A871),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: _saveSettings,
                      child: const Text("حفظ وتفعيل", style: TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
'''

content = content[:start] + new_dialog

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")