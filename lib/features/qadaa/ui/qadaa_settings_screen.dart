import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:intl/intl.dart' as intl;
import 'package:hijri/hijri_calendar.dart';

import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class QadaaSettingsScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  const QadaaSettingsScreen({super.key, this.onSettingsChanged});

  @override
  State<QadaaSettingsScreen> createState() => _QadaaSettingsScreenState();
}

class _QadaaSettingsScreenState extends State<QadaaSettingsScreen> {
  bool _requiresPrayerQadaa = true;
  bool _hasZakatWealth = false;
  String? _zakatDate;
  bool _dailyPrayerReminder = false;
  TimeOfDay? _prayerReminderTime;
  String _fastingReminderFrequency = 'إيقاف';
  int _fastingStartMonth = 7; // Default Rajab
  int _fastingReminderDay = 7; // Default Sunday (1=Mon, 7=Sun)

  final List<String> hijriMonths = [
    "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
    "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
  ];

  final List<String> weekDays = [
    "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = CacheHelper.prefs;
    setState(() {
      _requiresPrayerQadaa = prefs.getBool('qadaa_requires_prayer') ?? true;
      _hasZakatWealth = prefs.getBool('qadaa_has_zakat') ?? false;
      _zakatDate = prefs.getString('qadaa_zakat_date');
      _dailyPrayerReminder = prefs.getBool('qadaa_daily_prayer_reminder') ?? false;
      final timeStr = prefs.getString('qadaa_daily_prayer_time');
      if (timeStr != null && timeStr.contains(':')) {
        final parts = timeStr.split(':');
        _prayerReminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      _fastingReminderFrequency = prefs.getString('qadaa_fasting_reminder_freq') ?? 'إيقاف';
      _fastingStartMonth = prefs.getInt('qadaa_fasting_reminder_start_month') ?? 7;
      _fastingReminderDay = prefs.getInt('qadaa_fasting_reminder_day') ?? 7;
    });
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt(key, value);
    PrayerService().scheduleNotifications();
    widget.onSettingsChanged?.call();
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = CacheHelper.prefs;
    await prefs.setBool(key, value);
    PrayerService().scheduleNotifications();
    widget.onSettingsChanged?.call();
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = CacheHelper.prefs;
    await prefs.setString(key, value);
    PrayerService().scheduleNotifications();
    widget.onSettingsChanged?.call();
  }

  Future<void> _selectPrayerTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _prayerReminderTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) {
      setState(() => _prayerReminderTime = picked);
      await _saveString('qadaa_daily_prayer_time', '${picked.hour}:${picked.minute}');
      if (!_dailyPrayerReminder) {
        setState(() => _dailyPrayerReminder = true);
        await _saveBool('qadaa_daily_prayer_reminder', true);
      }
    }
  }

  void _showZakatDatePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          child: Container(
            height: 400.h,
            padding: EdgeInsets.all(16.w),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: const Color(0xFFD0A871),
                    labelColor: const Color(0xFFD0A871),
                    unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontFamily: AppConsts.expoArabic, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: "ميلادي"),
                      Tab(text: "هجري"),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildGregorianTab(ctx),
                        _buildHijriTab(ctx),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildGregorianTab(BuildContext ctx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "سيتم تحديد التاريخ بالميلادي ونقوم بحفظه للتذكير السنوي بناءً على السنة الهجرية.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 12.sp,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          SizedBox(height: 25.h),
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: const Color(0xFFD0A871),
                        onPrimary: Colors.white,
                        onSurface: isDark ? Colors.white : Colors.black,
                      ), dialogTheme: DialogThemeData(backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                final prefs = CacheHelper.prefs;
                await prefs.setString('qadaa_zakat_date', picked.toIso8601String());
                setState(() {
                  _zakatDate = picked.toIso8601String();
                });
                widget.onSettingsChanged?.call();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A871),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            label: const Text("فتح التقويم", style: TextStyle(color: Colors.white, fontFamily: AppConsts.expoArabic)),
          ),
        ],
      ),
    );
  }

  Widget _buildHijriTab(BuildContext ctx) {
    int day = 1;
    int month = 1;
    int year = HijriCalendar.now().hYear;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "اختر التاريخ الهجري الذي بلغت فيه أموالك النصاب",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 11.sp,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildHijriDropdown<int>(
                    value: day,
                    items: List.generate(30, (i) => i + 1),
                    onChanged: (v) => setModalState(() => day = v!),
                    isDark: isDark,
                  ),
                  _buildHijriDropdown<int>(
                    value: month,
                    items: List.generate(12, (i) => i + 1),
                    labelBuilder: (v) => hijriMonths[v - 1],
                    onChanged: (v) => setModalState(() => month = v!),
                    isDark: isDark,
                  ),
                  _buildHijriDropdown<int>(
                    value: year,
                    items: List.generate(10, (i) => HijriCalendar.now().hYear + i - 1),
                    onChanged: (v) => setModalState(() => year = v!),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            SizedBox(height: 30.h),
            ElevatedButton(
              onPressed: () async {
                try {
                  final temp = HijriCalendar();
                  final greg = temp.hijriToGregorian(year, month, day);
                  final prefs = CacheHelper.prefs;
                  await prefs.setString('qadaa_zakat_date', greg.toIso8601String());
                  setState(() {
                    _zakatDate = greg.toIso8601String();
                  });
                  widget.onSettingsChanged?.call();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  // Fallback
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text("حفظ التاريخ", style: TextStyle(color: Colors.white, fontFamily: AppConsts.expoArabic)),
            )
          ],
        );
      }
    );
  }

  Widget _buildHijriDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
    String Function(T)? labelBuilder,
  }) {
    return DropdownButton<T>(
      value: value,
      underline: const SizedBox(),
      dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            labelBuilder != null ? labelBuilder(item) : item.toString(),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontFamily: AppConsts.expoArabic,
              fontSize: 13.sp,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  void _clearData() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text(
          "تأكيد التصفير",
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: AppConsts.expoArabic, color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          "هل أنت متأكد من مسح جميع بيانات القضاء والزكاة؟ هذا الإجراء لا يمكن التراجع عنه.",
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: AppConsts.expoArabic, color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: AppConsts.expoArabic)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = CacheHelper.prefs;
              await prefs.remove('qadaa_fajr');
              await prefs.remove('qadaa_dhuhr');
              await prefs.remove('qadaa_asr');
              await prefs.remove('qadaa_maghrib');
              await prefs.remove('qadaa_isha');
              await prefs.remove('qadaa_max_fajr');
              await prefs.remove('qadaa_max_dhuhr');
              await prefs.remove('qadaa_max_asr');
              await prefs.remove('qadaa_max_maghrib');
              await prefs.remove('qadaa_max_isha');
              await prefs.remove('qadaa_zakat_date');
              // Clear current month fasting misses if applicable
              final year = HijriCalendar.now().hYear;
              for (int i=1; i<=30; i++) {
                await prefs.remove('qada_${year}_$i');
              }
              setState(() {
                _zakatDate = null;
                _hasZakatWealth = false;
                _requiresPrayerQadaa = true;
              });
              await prefs.remove('qadaa_has_zakat');
              await prefs.remove('qadaa_requires_prayer');
              widget.onSettingsChanged?.call();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("مسح البيانات", style: TextStyle(color: Colors.white, fontFamily: AppConsts.expoArabic)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFD0A871);

    String? zakatFormatted;
    if (_zakatDate != null) {
      final d = DateTime.tryParse(_zakatDate!);
      if (d != null) {
        zakatFormatted = intl.DateFormat('yyyy/MM/dd').format(d);
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCard(
              isDark,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      "هل مذهبك يوجب قضاء الصلاة؟",
                      style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 14.sp, color: isDark ? Colors.white : Colors.black),
                    ),
                    value: _requiresPrayerQadaa,
                    activeThumbColor: goldColor,
                    onChanged: (val) {
                      setState(() => _requiresPrayerQadaa = val);
                      _saveBool('qadaa_requires_prayer', val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(
                      "هل لك مال تؤدي عنه الزكاة؟",
                      style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 14.sp, color: isDark ? Colors.white : Colors.black),
                    ),
                    subtitle: _hasZakatWealth && zakatFormatted != null
                        ? InkWell(
                            onTap: () => _showZakatDatePicker(context),
                            child: Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: Text(
                                "موعد الزكاة: $zakatFormatted\n(اضغط للتعديل)",
                                style: TextStyle(fontFamily: AppConsts.expoArabic, color: goldColor, fontSize: 12.sp),
                              ),
                            ),
                          )
                        : null,
                    value: _hasZakatWealth,
                    activeThumbColor: goldColor,
                    onChanged: (val) {
                      setState(() => _hasZakatWealth = val);
                      _saveBool('qadaa_has_zakat', val);
                      if (val) {
                        _showZakatDatePicker(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _buildCard(
              isDark,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      "تذكير يومي بإضافة الصلوات المقضية",
                      style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 14.sp, color: isDark ? Colors.white : Colors.black),
                    ),
                    subtitle: _prayerReminderTime != null && _dailyPrayerReminder
                        ? Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: Text(
                              "وقت التذكير: ${_prayerReminderTime!.format(context)}",
                              style: const TextStyle(fontFamily: AppConsts.expoArabic, color: goldColor),
                            ),
                          )
                        : null,
                    value: _dailyPrayerReminder,
                    activeThumbColor: goldColor,
                    secondary: IconButton(
                      icon: Icon(Icons.access_time, color: _dailyPrayerReminder ? goldColor : Colors.grey),
                      onPressed: () => _selectPrayerTime(context),
                    ),
                    onChanged: (val) {
                      setState(() => _dailyPrayerReminder = val);
                      _saveBool('qadaa_daily_prayer_reminder', val);
                      if (val && _prayerReminderTime == null) {
                        _selectPrayerTime(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _buildCard(
              isDark,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // In RTL, start is right
                  children: [
                    Text(
                      "تكرار تذكير الصيام",
                      style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 14.sp, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 10.w,
                      children: ["14 يومًا", "أسبوع", "إيقاف"].map((label) {
                        final isSelected = _fastingReminderFrequency == label;
                        return ChoiceChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: goldColor,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                          showCheckmark: false,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _fastingReminderFrequency = label);
                              _saveString('qadaa_fasting_reminder_freq', label);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (_fastingReminderFrequency == 'أسبوع') ...[
                      SizedBox(height: 16.h),
                      Text(
                        "تنبيه كل يوم:",
                        style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        height: 40.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 7,
                          itemBuilder: (context, index) {
                            final dayNum = index + 1;
                            final isSelected = _fastingReminderDay == dayNum;
                            return Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: ChoiceChip(
                                label: Text(
                                  weekDays[index],
                                  style: TextStyle(
                                    fontFamily: AppConsts.expoArabic,
                                    fontSize: 11.sp,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: goldColor,
                                backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                showCheckmark: false,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _fastingReminderDay = dayNum);
                                    _saveInt('qadaa_fasting_reminder_day', dayNum);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            if (_fastingReminderFrequency != 'إيقاف')
              _buildCard(
                isDark,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "بدء التذكير من شهر (هجري)",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 14.sp,
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 40.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final monthNum = index + 1;
                            final isSelected = _fastingStartMonth == monthNum;
                            return Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: ChoiceChip(
                                label: Text(
                                  hijriMonths[index],
                                  style: TextStyle(
                                    fontFamily: AppConsts.expoArabic,
                                    fontSize: 11.sp,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: goldColor,
                                backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                showCheckmark: false,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _fastingStartMonth = monthNum);
                                    _saveInt('qadaa_fasting_reminder_start_month', monthNum);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "سيتم تجاهل التذكير في الشهور الهجرية التي تسبق الشهر المختار",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 10.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 24.h),
            Card(
              elevation: 0,
              color: Colors.red.withAlpha(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.r),
                side: BorderSide(color: Colors.red.withAlpha(50)),
              ),
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  "تصفير جميع البيانات",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                onTap: _clearData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.r),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }
}
