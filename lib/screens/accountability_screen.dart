import 'package:ibad_al_rahmann/services/prayer_service.dart' as ibad_al_rahmann_prayer;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/islamic_day.dart';
import 'package:ibad_al_rahmann/core/helpers/prayer_day_helper.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'stats_screen.dart';
import '../services/daily_tracker_service.dart';

import 'package:ibad_al_rahmann/main.dart'; // To access scaffoldMessengerKey
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';

class AccountabilityScreen extends StatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  State<AccountabilityScreen> createState() => _AccountabilityScreenState();
}

class _AccountabilityScreenState extends State<AccountabilityScreen> with WidgetsBindingObserver {
  bool _isPrayerPast(String prayerName) {
    final times = ibad_al_rahmann_prayer.PrayerService().getPrayerTimes();
    if (times == null) return true;
    final now = DateTime.now();
    switch (prayerName) {
      case 'Ø§Ù„Ù Ø¬Ø±':
        return now.isAfter(times.fajr);
      case 'Ø§Ù„Ø¸Ù‡Ø±':
      case 'Ø§Ù„Ø¬Ù…Ø¹Ø©':
        return now.isAfter(times.dhuhr);
      case 'Ø§Ù„Ø¹ØµØ±':
        return now.isAfter(times.asr);
      case 'Ø§Ù„Ù…ØºØ±Ø¨':
        return now.isAfter(times.maghrib);
      case 'Ø§Ù„Ø¹Ø´Ø§Ø¡':
        return now.isAfter(times.isha);
      default:
        return true;
    }
  }
  final List<String> _defaultPrayers = [
    'الفجر',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
    'الضحى',
    'القيام',
    'السنن',
  ];

  final List<String> _defaultQuran = [
    'ورد التلاوة',
    'حفظ جديد',
    'مراجعة',
    'سماع قرآن',
  ];

  final List<String> _defaultAzkar = [
    'أذكار الصباح',
    'أذكار المساء',
    'أذكار النوم',
    'أذكار الصلاة',
  ];

  final List<String> _defaultGoodDeeds = [
    'بر الوالدين',
    'صدقة',
    'صلة رحم',
    'إطعام مسكين',
    'زيارة مريض',
    'طلب علم',
  ];

  final Map<String, bool> _prayers = {};
  final Map<String, bool> _quran = {};
  final Map<String, bool> _azkar = {};
  final Map<String, bool> _goodDeeds = {};
  final Map<String, bool> _dynamicWirds = {};

  bool _isLoading = true;
  bool _isKahfDone = false;
  bool _isFriday = false;
  int _salawatCount = 0;

  double _todayTotalScore = 0.0;
  double _todayPrayerScore = 0.0;
  double _todayQuranScore = 0.0;
  double _todayAzkarScore = 0.0;
  double _todayDeedsScore = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDailyProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDailyProgress();
    }
  }

  void _initSectionItems(
    SharedPreferences prefs,
    String storageKey,
    List<String> defaultList,
    Map<String, bool> targetMap,
  ) {
    final custom = prefs.getStringList('custom_items_$storageKey') ?? [];
    final deleted = (prefs.getStringList('deleted_items_$storageKey') ?? [])
        .toSet();
    final items = [
      ...defaultList.where((e) => !deleted.contains(e)),
      ...custom.where((e) => !deleted.contains(e)),
    ];
    targetMap.clear();
    for (var item in items) {
      targetMap[item] = false;
    }
  }

  // 🔥 دالة تحميل البيانات المحفوظة لليوم الحالي 🔥
  Future<void> _loadDailyProgress() async {
    final prefs = CacheHelper.prefs;
    await prefs.reload();

    // ✅ التأكد من تهيئة بيانات اليوم وعمل Reset لو يوم جديد
    await DailyTrackerService.initStatsForToday();

    await prefs.reload();

    // تهيئة القوائم بالبنود الافتراضية والمخصصة
    _initSectionItems(prefs, 'temp_prayers', _defaultPrayers, _prayers);
    _initSectionItems(prefs, 'temp_quran', _defaultQuran, _quran);
    _initSectionItems(prefs, 'temp_azkar', _defaultAzkar, _azkar);
    _initSectionItems(prefs, 'temp_deeds', _defaultGoodDeeds, _goodDeeds);

    // ✅ استرجاع العلامات التي علمناها لليوم الحالي
    _loadMapFromPrefs(prefs, 'temp_prayers', _prayers);
    _loadMapFromPrefs(prefs, 'temp_quran', _quran);
    _loadMapFromPrefs(prefs, 'temp_azkar', _azkar);
    _loadMapFromPrefs(prefs, 'temp_deeds', _goodDeeds);

    // ✅ دمج الصلوات المسجلة في صلاتي (Prayer Focus) لليوم الحالي / الدورة النشطة
    final todayKey = await IslamicDay.todayKey();
    final activeKey = PrayerDayHelper.getActivePrayerCycleDate();
    final focusLogRaw =
        prefs.getString('prayer_focus_log_$activeKey') ??
        prefs.getString('prayer_focus_log_$todayKey');
    if (focusLogRaw != null) {
      try {
        final Map<String, dynamic> focusMap = json.decode(focusLogRaw);
        focusMap.forEach((k, v) {
          String actualKey = k;
          if (k == 'الجمعة' && _prayers.containsKey('الظهر')) {
            actualKey = 'الظهر';
          }
          if (_prayers.containsKey(actualKey)) {
            if (v is Map && v['status'] != null && v['status'] != 'missed') {
              _prayers[actualKey] = true;
            } else if (v == true) {
              _prayers[actualKey] = true;
            }
          }
        });
      } catch (_) {}
    }

    // Load Azkar from Service + Prefs
    if (_azkar.containsKey('أذكار الصباح')) {
      final done = await DailyTrackerService.isDone('morning_azkar');
      if (done) _azkar['أذكار الصباح'] = true;
    }
    if (_azkar.containsKey('أذكار المساء')) {
      final done = await DailyTrackerService.isDone('evening_azkar');
      if (done) _azkar['أذكار المساء'] = true;
    }
    if (_azkar.containsKey('أذكار الصلاة')) {
      final done = await DailyTrackerService.isDone('prayer_azkar');
      if (done) _azkar['أذكار الصلاة'] = true;
    }

    // Load others from manual prefs if exists
    String? jsonStr = prefs.getString('temp_azkar');
    if (jsonStr != null) {
      Map<String, dynamic> decoded = json.decode(jsonStr);
      decoded.forEach((k, v) {
        if (_azkar.containsKey(k) && v is bool) {
          _azkar[k] = v;
        }
      });
    }

    if (mounted) {
      // Load Kahf (Friday only) and Wird tracking
      _isFriday = DateTime.now().weekday == DateTime.friday;
      if (_isFriday) {
        _isKahfDone = await DailyTrackerService.isKahfDone();
      }
      _salawatCount = prefs.getInt('salawat_count_$todayKey') ?? 0;

      await _refreshDynamicWirds();
      await _saveStatsSilent();

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDynamicWirds() async {
    _dynamicWirds.clear();
    final khatmaState = context.read<KhatmaCubit>().state;
    if (khatmaState is KhatmaLoaded) {
      for (final k in khatmaState.khatmas) {
        final label = k.accountabilityLabel.isNotEmpty
            ? k.accountabilityLabel
            : 'ورد التلاوة';
        if (k.notificationType == 'prayer') {
          for (final p in ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']) {
            final key = '$label - $p';
            _dynamicWirds[key] = await DailyTrackerService.isWirdDone(key);
          }
        } else {
          _dynamicWirds[label] = await DailyTrackerService.isWirdDone(label);
        }
      }
    }
  }

  Future<void> _updateSalawatCount(int newCount) async {
    if (newCount < 0) newCount = 0;
    setState(() {
      _salawatCount = newCount;
    });
    final prefs = CacheHelper.prefs;
    final todayKey = await IslamicDay.todayKey();
    await prefs.setInt('salawat_count_$todayKey', newCount);
  }

  // دالة مساعدة لفك تشفير الماب المحفوظة
  void _loadMapFromPrefs(
    SharedPreferences prefs,
    String key,
    Map<String, bool> targetMap,
  ) {
    String? jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      Map<String, dynamic> decoded = json.decode(jsonStr);
      decoded.forEach((k, v) {
        String actualKey = k;
        if (k == 'الجمعة' && targetMap.containsKey('الظهر')) {
          actualKey = 'الظهر';
        }
        if (targetMap.containsKey(actualKey) && v is bool) {
          targetMap[actualKey] = v;
        }
      });
    }
  }

  // 🔥 دالة الحفظ اللحظي (عشان لما تعلم ومتقفلش يفضل محفوظ) 🔥
  Future<void> _updateStateAndSave(
    Map<String, bool> map,
    String key,
    String itemKey,
    bool value,
  ) async {
    setState(() {
      map[itemKey] = value;
    });

    final prefs = CacheHelper.prefs;
    await prefs.setString(key, json.encode(map));

    // Rule 15: If checking/unchecking prayers, write back to prayer_focus_log_$dateKey
    if (key == 'temp_prayers') {
      final dateKey = PrayerDayHelper.getPrayerDateKey(itemKey);
      final logKey = 'prayer_focus_log_$dateKey';
      final existing = prefs.getString(logKey);
      Map<String, dynamic> focusMap = {};
      if (existing != null) {
        try {
          focusMap = json.decode(existing) as Map<String, dynamic>;
        } catch (_) {}
      }
      if (value) {
        focusMap[itemKey] = {
          'status': 'ontime',
          'ts': DateTime.now().millisecondsSinceEpoch,
        };
      } else {
        focusMap.remove(itemKey);
      }
      await prefs.setString(logKey, json.encode(focusMap));
    }

    // ✅ حفظ فوري للإحصائيات وحساب نسبة الإنجاز فوراً
    await _saveStatsSilent();

    // Sync back to Service if it's an Azkar item
    if (value == true) {
      if (itemKey == 'أذكار الصباح') {
        await DailyTrackerService.markAsDone('morning_azkar');
      }
      if (itemKey == 'أذكار المساء') {
        await DailyTrackerService.markAsDone('evening_azkar');
      }
      if (itemKey == 'أذكار الصلاة') {
        await DailyTrackerService.markAsDone('prayer_azkar');
      }
    }
  }

  // دالة حفظ الإحصائيات (بدون رسالة)
  Future<void> _saveStatsSilent() async {
    
    final pastPrayers = _prayers.keys.where((k) => _isPrayerPast(k)).toList();
    int totalPrayerItems = pastPrayers.length;
    int checkedPrayerItems = pastPrayers.where((k) => _prayers[k] == true).length;

    double prayerScore = totalPrayerItems == 0
        ? 0.0
        : (checkedPrayerItems / totalPrayerItems) * 100.0;

    int totalQuranItems =
        _quran.length + _dynamicWirds.length + (_isFriday ? 1 : 0);
    int checkedQuranItems = _quran.values.where((e) => e).length +
        _dynamicWirds.values.where((e) => e).length +
        (_isFriday && _isKahfDone ? 1 : 0);
    double quranScore = totalQuranItems == 0
        ? 0.0
        : (checkedQuranItems / totalQuranItems) * 100.0;

    int totalAzkarItems = _azkar.length;
    int checkedAzkarItems = _azkar.values.where((e) => e).length;
    double azkarScore = totalAzkarItems == 0
        ? 0.0
        : (checkedAzkarItems / totalAzkarItems) * 100.0;

    int totalDeedsItems = _goodDeeds.length;
    int checkedDeedsItems = _goodDeeds.values.where((e) => e).length;
    double deedsScore = totalDeedsItems == 0
        ? 0.0
        : (checkedDeedsItems / totalDeedsItems) * 100.0;

    int totalAllItems =
        totalPrayerItems + totalQuranItems + totalAzkarItems + totalDeedsItems;
    int totalAllChecked = checkedPrayerItems +
        checkedQuranItems +
        checkedAzkarItems +
        checkedDeedsItems;

    double totalScore = totalAllItems == 0
        ? 0.0
        : (totalAllChecked / totalAllItems) * 100.0;

    final String dateKey = PrayerDayHelper.getActivePrayerCycleDate();
    final String todayCivilKey = await IslamicDay.todayKey();
    Map<String, dynamic> dailyData = {
      'date': dateKey,
      'prayer': prayerScore,
      'quran': quranScore,
      'azkar': azkarScore,
      'deeds': deedsScore,
      'total': totalScore,
    };

    final prefs = CacheHelper.prefs;
    await prefs.setString('stats_$dateKey', json.encode(dailyData));
    if (dateKey != todayCivilKey) {
      await prefs.setString('stats_$todayCivilKey', json.encode(dailyData));
    }

    if (mounted) {
      setState(() {
        _todayTotalScore = totalScore;
        _todayPrayerScore = prayerScore;
        _todayQuranScore = quranScore;
        _todayAzkarScore = azkarScore;
        _todayDeedsScore = deedsScore;
      });
    }

    // ✅ Streak بنسبة 50%: لو الأذكار وصلت 50%+ تُحسب في الاستريك حتى لو ما اكتملت
    if (azkarScore >= 50.0) {
      final morningDone = _azkar['أذكار الصباح'] ?? false;
      final eveningDone = _azkar['أذكار المساء'] ?? false;
      if (morningDone) await DailyTrackerService.markAsDone('morning_azkar');
      if (eveningDone) await DailyTrackerService.markAsDone('evening_azkar');
    }
  }

  Future<void> _reviewOldEntry() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFD0A871),
                    onPrimary: Colors.black,
                    surface: Color(0xFF000000),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFD0A871),
                    onPrimary: Colors.white,
                    surface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final String dateKey = DateFormat('yyyy-MM-dd').format(pickedDate);
      final String formattedKey = DateFormat('yyyy-M-d').format(pickedDate);

      final prefs = CacheHelper.prefs;
      String? jsonStr =
          prefs.getString('stats_$formattedKey') ??
          prefs.getString('stats_$dateKey');

      if (mounted) {
        if (jsonStr != null) {
          Map<String, dynamic> data = json.decode(jsonStr);
          showDialog(
            context: context,
            builder: (ctx) {
              final textColor = isDark ? Colors.white : Colors.black87;
              return AlertDialog(
                backgroundColor: isDark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                title: Text(
                  "إنجاز يوم $dateKey",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD0A871),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatRow("الصلاة", data['prayer'] ?? 0, textColor),
                    _buildStatRow(
                      "القرآن الكريم",
                      data['quran'] ?? 0,
                      textColor,
                    ),
                    _buildStatRow("الأذكار", data['azkar'] ?? 0, textColor),
                    _buildStatRow("الطاعات", data['deeds'] ?? 0, textColor),
                    const Divider(color: Color(0xFFD0A871)),
                    _buildStatRow(
                      "المجموع الكلي",
                      data['total'] ?? 0,
                      const Color(0xFFD0A871),
                      isTotal: true,
                    ),
                  ],
                ),
                actions: [
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        "إغلاق",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD0A871),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text("لا توجد بيانات مسجلة لهذا اليوم"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Widget _buildStatRow(
    String title,
    dynamic value,
    Color color, {
    bool isTotal = false,
  }) {
    double val = (value is double) ? value : (value as int).toDouble();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            "${val.round().toArabicNums}%",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSectionDialog(
    String sectionTitle,
    String storageKey,
    List<String> defaultList,
    Map<String, bool> dataMap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
              border: Border.all(
                color: const Color(0xFFD0A871).withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "تخصيص بنود $sectionTitle",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD0A871),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // حقل إضافة بند جديد
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        decoration: InputDecoration(
                          hintText: "أضف بنداً جديداً (مثل: ذكر، هدف...)",
                          hintStyle: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 13.sp,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 10.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 14.sp,
                          color: textColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD0A871),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                      ),
                      onPressed: () async {
                        final text = textController.text.trim();
                        if (text.isEmpty) return;
                        if (dataMap.containsKey(text)) {
                          scaffoldMessengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text("هذا البند موجود بالفعل"),
                            ),
                          );
                          return;
                        }

                        final prefs = CacheHelper.prefs;
                        final customList =
                            prefs.getStringList('custom_items_$storageKey') ??
                            [];
                        customList.add(text);
                        await prefs.setStringList(
                          'custom_items_$storageKey',
                          customList,
                        );

                        final deleted =
                            (prefs.getStringList('deleted_items_$storageKey') ??
                                    [])
                                .toSet();
                        deleted.remove(text);
                        await prefs.setStringList(
                          'deleted_items_$storageKey',
                          deleted.toList(),
                        );

                        setState(() {
                          dataMap[text] = false;
                        });
                        await prefs.setString(storageKey, json.encode(dataMap));
                        await _saveStatsSilent();

                        textController.clear();
                        setModalState(() {});
                      },
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 250.h),
                  child: ListView(
                    shrinkWrap: true,
                    children: dataMap.keys.map((item) {
                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 4.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black12 : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: const Color(
                              0xFFD0A871,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item,
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 14.sp,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () async {
                                final prefs = CacheHelper.prefs;

                                final customList =
                                    prefs.getStringList(
                                      'custom_items_$storageKey',
                                    ) ??
                                    [];
                                customList.remove(item);
                                await prefs.setStringList(
                                  'custom_items_$storageKey',
                                  customList,
                                );

                                final deleted =
                                    (prefs.getStringList(
                                              'deleted_items_$storageKey',
                                            ) ??
                                            [])
                                        .toSet();
                                deleted.add(item);
                                await prefs.setStringList(
                                  'deleted_items_$storageKey',
                                  deleted.toList(),
                                );

                                setState(() {
                                  dataMap.remove(item);
                                });
                                await prefs.setString(
                                  storageKey,
                                  json.encode(dataMap),
                                );
                                await _saveStatsSilent();

                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return BlocListener<KhatmaCubit, KhatmaState>(
      listener: (context, state) async {
        await _refreshDynamicWirds();
        await _saveStatsSilent();
        if (mounted) setState(() {});
      },
      child: Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
        title: const Text(
          'حاسب نفسك',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? ListView.builder(
                padding: EdgeInsets.only(top: 20.h),
                itemCount: 5,
                itemBuilder: (_, __) => AppSkeleton.card(height: 60.h),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.only(top: 14.h),
                child: Column(
                  children: [
                    // الشريط العلوي (أزرار التحكم)
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 6.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD0A871),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.r),
                                ),
                                elevation: 4,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const StatsScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.bar_chart, size: 20.sp),
                              label: Text(
                                "الإحصائيات",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 15.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF455A64)
                                    : Colors.blueGrey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.r),
                                ),
                                elevation: 4,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                              ),
                              onPressed: _reviewOldEntry,
                              icon: Icon(Icons.calendar_month, size: 20.sp),
                              label: Text(
                                "مراجعة",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ بطاقة الإنجاز اليومي اللحظي
                    _buildDailyAchievementCard(isDark, textColor),

                    // باقي محتوى الصفحة (الـ Checkboxes)
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        children: [
                          _buildSection(
                            "الصلاة",
                            "الصلاة نور وبرهان",
                            _prayers,
                            "temp_prayers",
                            _defaultPrayers,
                          ),

                          // ✅ القرآن الكريم مدمج مع الأوراد وسورة الكهف
                          _buildQuranAndWirdSection(isDark, textColor),

                          // ✅ عداد الصلاة على النبي ﷺ
                          _buildSalawatCounterCard(isDark, textColor),

                          _buildSection(
                            "الأذكار",
                            "ألا بذكر الله تطمئن القلوب",
                            _azkar,
                            "temp_azkar",
                            _defaultAzkar,
                          ),
                          _buildSection(
                            "الطاعات",
                            "وسارعوا إلى مغفرة",
                            _goodDeeds,
                            "temp_deeds",
                            _defaultGoodDeeds,
                          ),

                          SizedBox(height: 10.h),

                          // مؤشر الحفظ التلقائي
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: 14.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFD0A871,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(15.r),
                              border: Border.all(
                                color: const Color(
                                  0xFFD0A871,
                                ).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Color(0xFFD0A871),
                                  size: 22,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  "يتم حفظ إنجازك وسجل اليوم تلقائياً",
                                  style: TextStyle(
                                    fontFamily: AppConsts.expoArabic,
                                    fontSize: 14.sp,
                                    color: const Color(0xFFD0A871),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildDailyAchievementCard(bool isDark, Color textColor) {
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final progressInt = _todayTotalScore.round();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFD0A871).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: const Color(0xFFD0A871),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    "نسبة الإنجاز اليومي",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD0A871),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0A871).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "${progressInt.toArabicNums}%",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD0A871),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: (_todayTotalScore / 100.0).clamp(0.0, 1.0),
              minHeight: 10.h,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFD0A871),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniScore("الصلاة", _todayPrayerScore),
              _buildMiniScore("القرآن", _todayQuranScore),
              _buildMiniScore("الأذكار", _todayAzkarScore),
              _buildMiniScore("الطاعات", _todayDeedsScore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniScore(String label, double score) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 11.sp,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          "${score.round().toArabicNums}%",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD0A871),
          ),
        ),
      ],
    );
  }

  Widget _buildQuranAndWirdSection(bool isDark, Color textColor) {
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFD0A871).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 5.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color(0xFFD0A871).withValues(alpha: 0.15),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: const Color(0xFFD0A871),
                    size: 20.sp,
                  ),
                  onPressed: () => _showEditSectionDialog(
                    "القرآن الكريم",
                    "temp_quran",
                    _defaultQuran,
                    _quran,
                  ),
                  tooltip: "تخصيص بنود القرآن الكريم",
                ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 4.h, bottom: 8.h),
                        child: Text(
                          "القرآن الكريم",
                          style: TextStyle(
                            fontFamily: AppConsts.motoNastaliq,
                            fontSize: 23.sp,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFFD0A871),
                            height: 2.2,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "القرآن شفيع لأصحابه",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 12.sp,
                          color: subTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 40.w),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_quran.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Center(
                      child: Text(
                        "لا توجد بنود مضافة. اضغط على القلم ✏️ لإضافة بنود",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 13.sp,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: _quran.keys.map((key) {
                      return SizedBox(
                        width: MediaQuery.of(context).size.width / 2.5,
                        child: Theme(
                          data: ThemeData(
                            unselectedWidgetColor: const Color(0xFFD0A871),
                          ),
                          child: CheckboxListTile(
                            activeColor: const Color(0xFFD0A871),
                            checkColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              key,
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 14.sp,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            value: _quran[key] ?? false,
                            onChanged: (val) {
                              _updateStateAndSave(
                                _quran,
                                "temp_quran",
                                key,
                                val ?? false,
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                // ── الأوراد من الختمات النشطة ──
                if (_dynamicWirds.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Divider(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 8.h,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD0A871,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: const Color(0xFFD0A871),
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Padding(
                          padding: EdgeInsets.only(top: 4.h, bottom: 6.h),
                          child: Text(
                            "أوراد الختمات النشطة",
                            style: TextStyle(
                              fontFamily: AppConsts.motoNastaliq,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.normal,
                              color: const Color(0xFFD0A871),
                              height: 2.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._dynamicWirds.keys.map((key) {
                    final isDone = _dynamicWirds[key] ?? false;
                    return Container(
                      margin: EdgeInsets.symmetric(
                        vertical: 4.h,
                        horizontal: 2.w,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141414)
                            : const Color(0xFFFBF8F3),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFFD0A871)
                              : const Color(0xFFD0A871).withValues(alpha: 0.25),
                          width: isDone ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final newStatus = !isDone;
                          setState(() {
                            _dynamicWirds[key] = newStatus;
                          });
                          final dateStr =
                              PrayerDayHelper.getActivePrayerCycleDate();
                          if (newStatus) {
                            await DailyTrackerService.markWirdDone(
                              key,
                              dateKey: dateStr,
                            );
                          } else {
                            await CacheHelper.prefs.setBool(
                              'wird_done_${key}_$dateStr',
                              false,
                            );
                          }
                          await _saveStatsSilent();
                        },
                        borderRadius: BorderRadius.circular(10.r),
                        child: Row(
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.w,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFFD0A871)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: const Color(0xFFD0A871),
                                  width: 2.0,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                key,
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDone
                                      ? const Color(0xFFD0A871)
                                      : textColor,
                                ),
                              ),
                            ),
                            if (isDone)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD0A871,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  "مكتمل ✓",
                                  style: TextStyle(
                                    fontFamily: AppConsts.expoArabic,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD0A871),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // ── سورة الكهف (يوم الجمعة) ──
                if (_isFriday) ...[
                  SizedBox(height: 10.h),
                  Divider(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                  ),
                  CheckboxListTile(
                    activeColor: const Color(0xFFD0A871),
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                    value: _isKahfDone,
                    onChanged: (val) async {
                      final isChecked = val ?? false;
                      if (isChecked) {
                        await DailyTrackerService.markKahfDone();
                      } else {
                        final today = await IslamicDay.todayKey();
                        await CacheHelper.prefs.setBool(
                          'kahf_done_$today',
                          false,
                        );
                      }
                      setState(() => _isKahfDone = isChecked);
                      await _saveStatsSilent();
                    },
                    title: Padding(
                      padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
                      child: Text(
                        'قراءة سورة الكهف 📖',
                        style: TextStyle(
                          fontFamily: AppConsts.motoNastaliq,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.normal,
                          color: const Color(0xFFD0A871),
                          height: 2.2,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      'من قرأ سورة الكهف في يوم الجمعة أضاء له النور',
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 11.sp,
                        color: const Color(0xFFD0A871),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalawatCounterCard(bool isDark, Color textColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF000000) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFD0A871).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 5.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 4.h, bottom: 6.h),
                child: Text(
                  "الصلاة على النبي ﷺ",
                  style: TextStyle(
                    fontFamily: AppConsts.motoNastaliq,
                    fontSize: 21.sp,
                    fontWeight: FontWeight.normal,
                    color: const Color(0xFFD0A871),
                    height: 2.2,
                  ),
                ),
              ),
              if (_salawatCount > 0)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                  tooltip: "إعادة ضبط العداد",
                  onPressed: () => _updateSalawatCount(0),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          InkWell(
            onTap: () => _updateSalawatCount(_salawatCount + 1),
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 18.h),
              decoration: BoxDecoration(
                color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _salawatCount.toArabicNums,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 34.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD0A871),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "اضغط هنا لزيادة العداد +1",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 11.5.sp,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickSalawatBtn("+10", 10),
              _buildQuickSalawatBtn("+33", 33),
              _buildQuickSalawatBtn("+100", 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSalawatBtn(String label, int add) {
    return InkWell(
      onTap: () => _updateSalawatCount(_salawatCount + add),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFFD0A871).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFFD0A871).withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD0A871),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    String subtitle,
    Map<String, bool> dataMap,
    String storageKey,
    List<String> defaultList,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFD0A871).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 5.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color(0xFFD0A871).withValues(alpha: 0.15),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: const Color(0xFFD0A871),
                    size: 20.sp,
                  ),
                  onPressed: () => _showEditSectionDialog(
                    title,
                    storageKey,
                    defaultList,
                    dataMap,
                  ),
                  tooltip: "تخصيص بنود $title",
                ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 4.h, bottom: 8.h),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppConsts.motoNastaliq,
                            fontSize: 23.sp,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFFD0A871),
                            height: 2.2,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 12.sp,
                          color: subTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 40.w,
                ), // Balance spacing opposite to the edit button
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10.w),
            child: dataMap.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Text(
                      "لا توجد بنود مضافة. اضغط على القلم ✏️ لإضافة بنود",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 13.sp,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: dataMap.keys.map((key) {
                      return SizedBox(
                        width: MediaQuery.of(context).size.width / 2.5,
                        child: Theme(
                          data: ThemeData(
                            unselectedWidgetColor: const Color(0xFFD0A871),
                          ),
                          child: CheckboxListTile(
                            activeColor: const Color(0xFFD0A871),
                            checkColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              key,
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 14.sp,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            value: dataMap[key] ?? false,
                            onChanged: (val) {
                              _updateStateAndSave(
                                dataMap,
                                storageKey,
                                key,
                                val ?? false,
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
