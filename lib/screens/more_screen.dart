import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/screens/alarms_screen.dart'; // As Alarms
import 'package:ibad_al_rahmann/screens/settings_screen.dart';
import 'occasions_screen.dart';
import 'fasting_days_screen.dart';
import 'package:ibad_al_rahmann/features/share_cards/ui/share_cards_screen.dart';
import 'time_for_allah_screen.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ibad_al_rahmann/main.dart'; // To access scaffoldMessengerKey
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adaptive BG
      appBar: AppBar(
        title: const Text(
          "المزيد",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871), // Keep Gold Title
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildMenuButton(
            context: context,
            title: "أيام الصيام",
            imagePath: "assets/images/fasting_days_icon.png",
            imageSize: 45.w,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FastingDaysScreen()),
            ),
          ),
          _buildMenuButton(
            context: context,
            title: "وقت لله",
            imagePath: "assets/images/time_for_allah_card.png",
            imageSize: 45.w,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TimeForAllahScreen()),
            ),
          ),
          _buildMenuButton(
            context: context,
            title: "المناسبات",
            imagePath: "assets/images/occasions_icon.png",
            imageSize: 45.w,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OccasionsScreen()),
            ),
          ),
          _buildMenuButton(
            context: context,
            title: "المنبه",
            icon: Icons.alarm,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlarmsScreen()),
            ),
          ),

          _buildMenuButton(
            context: context,
            title: "تنبيهات الصلاة على النبي",
            iconWidget: Text(
              'ﷺ',
              style: TextStyle(
                fontSize: 30.sp,
                color: const Color(0xFFD0A871),
                height: 1.0,
              ),
            ),
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => const SalawatReminderDialog(),
            ),
          ),

          _buildMenuButton(
            context: context,
            title: "بطاقات المشاركة",
            icon: Icons.grid_view_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareCardsScreen()),
            ),
          ),

          _buildMenuButton(
            context: context,
            title: "الإعدادات",
            icon: Icons.settings,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    IconData? icon,
    Widget? iconWidget,
    required VoidCallback onTap,
    String? imagePath,
    double? imageSize,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.withAlpha(50);
    final textColor = isDark ? Colors.white : Colors.black;
    final double size = imageSize ?? 30.w;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      height: 80.h,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                if (imagePath != null)
                  imagePath.endsWith('.svg')
                      ? SvgPicture.asset(
                          imagePath,
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          imagePath,
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                        )
                else if (icon != null)
                  Icon(icon, color: const Color(0xFFD0A871), size: 30.w)
                else if (iconWidget != null)
                  iconWidget,
                SizedBox(width: 20.w),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: textColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 20.w,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SalawatReminderDialog extends StatefulWidget {
  const SalawatReminderDialog({super.key});

  @override
  State<SalawatReminderDialog> createState() => _SalawatReminderDialogState();
}

class _SalawatReminderDialogState extends State<SalawatReminderDialog> {
  bool _isEnabled = false;
  String _unlockMode = 'none';
  bool _unlockEnabled = false; // explicit toggle for the unlock sound feature
  bool _useCustomVolume = false;
  double _unlockVolume = 1.0;
  String? _customSoundPath;
  String? _customSoundName;
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
    final prefs = CacheHelper.prefs;
    final enabled = prefs.getBool('salawat_reminder_enabled') ?? false;
    final unlockMode = prefs.getString('salah_unlock_mode') ?? 'none';
    final useCustomVolume = prefs.getBool('salah_unlock_use_custom_volume') ?? false;
    final unlockVolume = prefs.getDouble('salah_unlock_volume') ?? 1.0;
    final customPath = prefs.getString('salah_unlock_custom_path');
    final customName = prefs.getString('salah_unlock_custom_name');
    final periodicSound = prefs.getString('salawat_periodic_sound') ?? 'saly_3ala_mo7amad';
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
        _unlockEnabled = unlockMode != 'none';
        _useCustomVolume = useCustomVolume;
        _unlockVolume = unlockVolume;
        _customSoundPath = customPath;
        _customSoundName = customName;
        _periodicSound = periodicSound;
        _controller.text = minutes.toString();
        _selectedDays = daysList.map((e) => int.parse(e)).toList();
        _quietHoursStart = TimeOfDay(hour: qhStartHour, minute: qhStartMin);
        _quietHoursEnd = TimeOfDay(hour: qhEndHour, minute: qhEndMin);
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = CacheHelper.prefs;
    final minutes = int.tryParse(_controller.text) ?? 60;

    await prefs.setBool('salawat_reminder_enabled', _isEnabled);
    await prefs.setInt('salawat_reminder_minutes', minutes);
    await prefs.setString('salah_unlock_mode', _unlockEnabled ? _unlockMode : 'none');
    await prefs.setBool('salah_unlock_use_custom_volume', _useCustomVolume);
    await prefs.setDouble('salah_unlock_volume', _unlockVolume);
    if (_customSoundPath != null) {
      await prefs.setString('salah_unlock_custom_path', _customSoundPath!);
    }
    if (_customSoundName != null) {
      await prefs.setString('salah_unlock_custom_name', _customSoundName!);
    }
    await prefs.setString('salawat_periodic_sound', _periodicSound);
    await prefs.setStringList('salawat_reminder_days', _selectedDays.map((e) => e.toString()).toList());
    await prefs.setInt('quiet_hours_start_hour', _quietHoursStart.hour);
    await prefs.setInt('quiet_hours_start_minute', _quietHoursStart.minute);
    await prefs.setInt('quiet_hours_end_hour', _quietHoursEnd.hour);
    await prefs.setInt('quiet_hours_end_minute', _quietHoursEnd.minute);

    // Start or stop the ScreenUnlockService natively
    const platform = MethodChannel('app.ibad_al_rahmann/native_notifications');
    try {
      if (_unlockEnabled && _unlockMode != 'none') {
        await platform.invokeMethod('startScreenUnlockService', {
          'mode':   _unlockMode,
          'volume': _unlockVolume,
        });
      } else {
        await platform.invokeMethod('stopScreenUnlockService');
      }
    } catch (e) {
      debugPrint('Failed to toggle ScreenUnlockService: $e');
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

  Future<void> _pickCustomAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        setState(() {
          _customSoundPath = path;
          _customSoundName = name;
          _unlockMode = 'custom';
        });
      }
    } catch (e) {
      debugPrint("Error picking audio: $e");
    }
  }

  Future<void> _playSound(String soundName, {double volume = 1.0}) async {
    if (_playingSound == soundName) {
      await _audioPlayer.stop();
      setState(() => _playingSound = null);
    } else {
      await _audioPlayer.stop();
      setState(() => _playingSound = soundName);
      try {
        await _audioPlayer.setVolume(volume);
        if (soundName == 'custom' && _customSoundPath != null) {
          await _audioPlayer.play(DeviceFileSource(_customSoundPath!));
        } else {
          await _audioPlayer.play(AssetSource('audio/$soundName.mp3'));
        }
      } catch (e) {
        debugPrint('_playSound error: $e');
        setState(() => _playingSound = null);
      }
    }
  }

  Widget _buildSoundSelector({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
    bool showNone = false,
    bool showBoth = false,
    bool showCustom = false,
    double previewVolume = 1.0,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final soundLabel = {
      'saly_3ala_mo7amad': 'صلي على محمد',
      'salah_2': 'اللهم صلي وسلم على نبينا محمد',
      'both': 'كلاهما (عشوائي)',
      'custom': _customSoundName != null ? 'صوت مخصص: $_customSoundName' : 'صوت مخصص من الهاتف',
      'none': 'إيقاف',
    };
    final previewKey = value == 'both' ? 'saly_3ala_mo7amad' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFD0A871).withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (showCustom && value == 'custom') || soundLabel.containsKey(value) ? value : 'saly_3ala_mo7amad',
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD0A871)),
              dropdownColor: isDark ? Colors.grey[900] : Colors.white,
              items: [
                if (showNone)
                  DropdownMenuItem(value: 'none', child: Text(soundLabel['none']!, style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp))),
                DropdownMenuItem(value: 'saly_3ala_mo7amad', child: Text(soundLabel['saly_3ala_mo7amad']!, style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp))),
                DropdownMenuItem(value: 'salah_2', child: Text(soundLabel['salah_2']!, style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp))),
                if (showBoth)
                  DropdownMenuItem(value: 'both', child: Text(soundLabel['both']!, style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp))),
                if (showCustom)
                  DropdownMenuItem(value: 'custom', child: Text(soundLabel['custom']!, style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
        if (showCustom && value == 'custom') ...[
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD0A871)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                padding: EdgeInsets.symmetric(vertical: 8.h),
              ),
              icon: const Icon(Icons.file_upload_outlined, color: Color(0xFFD0A871), size: 18),
              label: Text(
                _customSoundName != null ? 'تغيير الملف: $_customSoundName' : 'اختيار ملف صوتي من الجهاز',
                style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 12.sp, color: const Color(0xFFD0A871)),
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: _pickCustomAudio,
            ),
          ),
        ],
        if (value != 'none') ...[
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _playingSound == previewKey ? Colors.red : const Color(0xFFD0A871),
                    side: BorderSide(color: _playingSound == previewKey ? Colors.red : const Color(0xFFD0A871)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  icon: Icon(_playingSound == previewKey ? Icons.stop : Icons.play_arrow, size: 20),
                  label: Text(
                    _playingSound == previewKey
                      ? 'إيقاف الصوت'
                      : (value == 'both' ? 'معاينة (الأول)' : 'معاينة الصوت'),
                    style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp),
                  ),
                  onPressed: () => _playSound(previewKey, volume: previewVolume),
                ),
              ),
            ],
          ),
        ],
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
        if (isStart) {
          _quietHoursStart = picked;
        } else {
          _quietHoursEnd = picked;
        }
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
                color: const Color(0xFFD0A871).withValues(alpha: 0.1),
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
                          activeThumbColor: const Color(0xFFD0A871),
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
                    Divider(height: 40.h, color: Colors.grey.withValues(alpha: 0.2)),
                    // Section 2: Lock Screen
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("عند فتح قفل الشاشة", style: TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold, fontSize: 16)),
                        Switch(
                          value: _unlockEnabled,
                          activeThumbColor: const Color(0xFFD0A871),
                          onChanged: (val) => setState(() {
                            _unlockEnabled = val;
                            if (val && _unlockMode == 'none') _unlockMode = 'saly_3ala_mo7amad';
                          }),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    if (_unlockEnabled) ...[
                      SizedBox(height: 4.h),
                      _buildSoundSelector(
                        title: "اختر الصوت:",
                        value: _unlockMode == 'none' ? 'saly_3ala_mo7amad' : _unlockMode,
                        showNone: false,
                        showBoth: true,
                        showCustom: true,
                        previewVolume: _unlockVolume,
                        onChanged: (val) { if (val != null) setState(() => _unlockMode = val); },
                      ),
                      SizedBox(height: 14.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "تخصيص مستوى الصوت (تعلية مؤقتة)",
                            style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Switch(
                            value: _useCustomVolume,
                            activeThumbColor: const Color(0xFFD0A871),
                            onChanged: (val) => setState(() => _useCustomVolume = val),
                          ),
                        ],
                      ),
                      if (_useCustomVolume) ...[
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            const Icon(Icons.volume_mute, color: Colors.grey, size: 20),
                            Expanded(
                              child: Slider(
                                value: _unlockVolume,
                                min: 0.1,
                                max: 1.0,
                                divisions: 9,
                                activeColor: const Color(0xFFD0A871),
                                inactiveColor: const Color(0xFFD0A871).withValues(alpha: 0.2),
                                onChanged: (val) => setState(() => _unlockVolume = val),
                              ),
                            ),
                            const Icon(Icons.volume_up, color: Color(0xFFD0A871), size: 20),
                            SizedBox(width: 6.w),
                            SizedBox(
                              width: 36.w,
                              child: Text(
                                '${(_unlockVolume * 100).round()}%',
                                style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 12.sp,
                                  color: const Color(0xFFD0A871), fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "يتم تعلية الصوت مؤقتاً أثناء التنبيه ثم استعادة مستوى صوت النظام تلقائياً",
                          style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 11.sp, color: Colors.grey),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
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
