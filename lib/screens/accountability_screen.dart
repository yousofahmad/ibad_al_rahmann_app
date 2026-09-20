import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/islamic_day.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'stats_screen.dart';
import '../services/daily_tracker_service.dart';

import 'package:ibad_al_rahmann/main.dart'; // To access scaffoldMessengerKey
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';

class AccountabilityScreen extends StatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  State<AccountabilityScreen> createState() => _AccountabilityScreenState();
}

class _AccountabilityScreenState extends State<AccountabilityScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadDailyProgress();
  }

  void _initSectionItems(
    SharedPreferences prefs,
    String storageKey,
    List<String> defaultList,
    Map<String, bool> targetMap,
  ) {
    final custom = prefs.getStringList('custom_items_$storageKey') ?? [];
    final deleted = (prefs.getStringList('deleted_items_$storageKey') ?? []).toSet();
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

    // تهيئة القوائم بالبنود الافتراضية والمخصصة
    _initSectionItems(prefs, 'temp_prayers', _defaultPrayers, _prayers);
    _initSectionItems(prefs, 'temp_quran', _defaultQuran, _quran);
    _initSectionItems(prefs, 'temp_azkar', _defaultAzkar, _azkar);
    _initSectionItems(prefs, 'temp_deeds', _defaultGoodDeeds, _goodDeeds);

    // ✅ احفظ البيانات النيتف المهمة قبل أي reset
    final nativeTempPrayers = prefs.getString('temp_prayers');

    // ✅ التأكد من تهيئة بيانات اليوم وعمل Reset لو يوم جديد
    await DailyTrackerService.initStatsForToday();

    // ✅ لو DailyTracker مسح temp_prayers (يوم جديد) ارجع للبيانات النيتف لو موجودة
    if (nativeTempPrayers != null && prefs.getString('temp_prayers') == null) {
      await prefs.setString('temp_prayers', nativeTempPrayers);
    }

    await prefs.reload(); // Reload مرة تانية بعد initStatsForToday

    // ✅ استرجاع العلامات التي علمناها لليوم الحالي
    _loadMapFromPrefs(prefs, 'temp_prayers', _prayers);
    _loadMapFromPrefs(prefs, 'temp_quran', _quran);
    _loadMapFromPrefs(prefs, 'temp_azkar', _azkar);
    _loadMapFromPrefs(prefs, 'temp_deeds', _goodDeeds);

    // ✅ دمج الصلوات المسجلة في صلاتي (Prayer Focus) لليوم الحالي
    final todayKey = await IslamicDay.todayKey();
    final focusLogRaw = prefs.getString('prayer_focus_log_$todayKey');
    if (focusLogRaw != null) {
      try {
        final Map<String, dynamic> focusMap = json.decode(focusLogRaw);
        focusMap.forEach((k, v) {
          String actualKey = k;
          if (k == 'الجمعة' && _prayers.containsKey('الظهر')) {
            actualKey = 'الظهر';
          }
          if (_prayers.containsKey(actualKey)) {
            if (v is Map && v['status'] != null) {
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
      _azkar['أذكار الصباح'] = await DailyTrackerService.isDone('morning_azkar');
    }
    if (_azkar.containsKey('أذكار المساء')) {
      _azkar['أذكار المساء'] = await DailyTrackerService.isDone('evening_azkar');
    }
    if (_azkar.containsKey('أذكار الصلاة')) {
      _azkar['أذكار الصلاة'] = await DailyTrackerService.isDone('prayer_azkar');
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

      _dynamicWirds.clear();
      final khatmaState = context.read<KhatmaCubit>().state;
      if (khatmaState is KhatmaLoaded) {
        for (final k in khatmaState.khatmas) {
          final label = k.accountabilityLabel.isNotEmpty ? k.accountabilityLabel : 'ورد التلاوة';
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

      setState(() {
        _isLoading = false;
      });
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

    if (key == 'temp_prayers') {
      final todayKey = await IslamicDay.todayKey();
      final logKey = 'prayer_focus_log_$todayKey';
      final focusLogRaw = prefs.getString(logKey);
      final focusMap = <String, dynamic>{};
      if (focusLogRaw != null) {
        try { focusMap.addAll(json.decode(focusLogRaw)); } catch (_) {}
      }
      if (value) {
        focusMap[itemKey] = {'status': 'ontime', 'ts': DateTime.now().millisecondsSinceEpoch};
      } else {
        focusMap.remove(itemKey);
      }
      AppLogger.log("Accountability", "writing $logKey: ${json.encode(focusMap)} AND temp_prayers: ${json.encode(map)}");
      await prefs.setString(logKey, json.encode(focusMap));
    }
    await AccountabilitySyncService.syncAndSaveTodayStats();

    // ✅ حفظ فوري للإحصائيات (Auto-Save)
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
    double calcPercent(Map<String, bool> map) {
      int checked = map.values.where((e) => e).length;
      return map.isEmpty ? 0 : (checked / map.length) * 100;
    }

    double prayerScore = calcPercent(_prayers);
    double quranScore = calcPercent(_quran);
    double azkarScore = calcPercent(_azkar);
    double deedsScore = calcPercent(_goodDeeds);
    double totalScore =
        (prayerScore + quranScore + azkarScore + deedsScore) / 4;

    final String dateKey = await IslamicDay.todayKey();
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
      final String dateKey =
          "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
      final String formattedKey = DateFormat('yyyy-MM-dd').format(pickedDate);

      final prefs = CacheHelper.prefs;
      String? jsonStr =
          prefs.getString('stats_$formattedKey') ??
          prefs.getString('stats_$dateKey');

      if (!mounted) return;

      if (jsonStr != null) {
        Map<String, dynamic> data = json.decode(jsonStr);
        _showDayStatsDialog(data);
      } else {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              "لا يوجد سجل لهذا اليوم",
              style: TextStyle(fontFamily: AppConsts.expoArabic),
            ),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  void _showDayStatsDialog(Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          "إنجاز يوم ${data['date']}",
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD0A871),
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(
              "إجمالي الإنجاز",
              data['total'],
              textColor,
              isTotal: true,
            ),
            const Divider(color: Colors.grey),
            _buildStatRow("الصلاة", data['prayer'], textColor),
            _buildStatRow("القرآن", data['quran'], textColor),
            _buildStatRow("الأذكار", data['azkar'], textColor),
            _buildStatRow("الطاعات", data['deeds'], textColor),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "إغلاق",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: Color(0xFFD0A871),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String title,
    dynamic score,
    Color textColor, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            "${score.toInt()}%",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: isTotal ? const Color(0xFFD0A871) : textColor,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 نافذة تعديل / إضافة / حذف بنود القسم 🔥
  void _showEditSectionDialog(
    String sectionTitle,
    String storageKey,
    List<String> defaultList,
    Map<String, bool> dataMap,
  ) {
    final TextEditingController textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      ),
                      onPressed: () async {
                        final text = textController.text.trim();
                        if (text.isEmpty) return;
                        if (dataMap.containsKey(text)) {
                          scaffoldMessengerKey.currentState?.showSnackBar(
                            const SnackBar(content: Text("هذا البند موجود بالفعل")),
                          );
                          return;
                        }

                        final prefs = CacheHelper.prefs;
                        final customList = prefs.getStringList('custom_items_$storageKey') ?? [];
                        customList.add(text);
                        await prefs.setStringList('custom_items_$storageKey', customList);

                        final deleted = (prefs.getStringList('deleted_items_$storageKey') ?? []).toSet();
                        deleted.remove(text);
                        await prefs.setStringList('deleted_items_$storageKey', deleted.toList());

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
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black12 : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFFD0A871).withValues(alpha: 0.2)),
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
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                final prefs = CacheHelper.prefs;

                                final customList = prefs.getStringList('custom_items_$storageKey') ?? [];
                                customList.remove(item);
                                await prefs.setStringList('custom_items_$storageKey', customList);

                                final deleted = (prefs.getStringList('deleted_items_$storageKey') ?? []).toSet();
                                deleted.add(item);
                                await prefs.setStringList('deleted_items_$storageKey', deleted.toList());

                                setState(() {
                                  dataMap.remove(item);
                                });
                                await prefs.setString(storageKey, json.encode(dataMap));
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

    return Scaffold(
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
                padding: EdgeInsets.only(top: 20.h),
                child: Column(
                  children: [
                    // الشريط العلوي (أزرار التحكم)
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 10.h,
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
                                padding: EdgeInsets.symmetric(
                                  vertical: 12.h,
                                ),
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
                                padding: EdgeInsets.symmetric(
                                  vertical: 12.h,
                                ),
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
                          _buildSection(
                            "القرآن الكريم",
                            "القرآن شفيع لأصحابه",
                            _quran,
                            "temp_quran",
                            _defaultQuran,
                          ),

                          // ✅ سورة الكهف (يوم الجمعة فقط)
                          if (_isFriday)
                            Container(
                              margin: EdgeInsets.only(bottom: 12.h),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF000000) : Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: const Color(0xFFD0A871).withValues(alpha: 0.5)),
                              ),
                              child: CheckboxListTile(
                                activeColor: const Color(0xFFD0A871),
                                checkColor: Colors.white,
                                value: _isKahfDone,
                                onChanged: (val) async {
                                  if (val == true) {
                                    await DailyTrackerService.markKahfDone();
                                    setState(() => _isKahfDone = true);
                                  }
                                },
                                title: Text(
                                  'قراءة سورة الكهف 📖',
                                  style: TextStyle(
                                    fontFamily: AppConsts.expoArabic,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  'من قرأ سورة الكهف في يوم الجمعة أضاء له النور',
                                  style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 11.sp, color: const Color(0xFFD0A871)),
                                ),
                              ),
                            ),

                          // ✅ الأوراد (من הختمات النشطة)
                          _buildDynamicWirdsSection(isDark, textColor),

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

                          SizedBox(height: 20.h),

                          // مؤشر الحفظ التلقائي
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: 14.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD0A871).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(15.r),
                              border: Border.all(
                                color: const Color(0xFFD0A871).withValues(alpha: 0.35),
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
              Text(
                "الصلاة على النبي ﷺ",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD0A871),
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
                border: Border.all(color: const Color(0xFFD0A871).withValues(alpha: 0.3)),
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
          border: Border.all(color: const Color(0xFFD0A871).withValues(alpha: 0.4)),
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
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFD0A871).withValues(alpha: 0.15),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20.r),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: const Color(0xFFD0A871), size: 20.sp),
                  onPressed: () => _showEditSectionDialog(title, storageKey, defaultList, dataMap),
                  tooltip: "تخصيص بنود $title",
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppConsts.motoNastaliq,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFFD0A871),
                            height: 1.5,
                          ),
                        ),
                      SizedBox(height: 3.h),
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
                SizedBox(width: 40.w), // Balance spacing opposite to the edit button
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
                              _updateStateAndSave(dataMap, storageKey, key, val ?? false);
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

  Widget _buildDynamicWirdsSection(bool isDark, Color textColor) {
    if (_dynamicWirds.isEmpty) return const SizedBox.shrink();

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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          collapsedIconColor: const Color(0xFFD0A871),
          iconColor: const Color(0xFFD0A871),
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          title: Text(
            "الأوراد",
            style: TextStyle(
              fontFamily: AppConsts.motoNastaliq,
              fontSize: 22.sp,
              fontWeight: FontWeight.normal,
              color: const Color(0xFFD0A871),
              height: 1.5,
            ),
          ),
          subtitle: Text(
            "أوراد الختمات النشطة",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 12.sp,
              color: subTextColor,
            ),
          ),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                children: _dynamicWirds.keys.map((key) {
                  final isDone = _dynamicWirds[key] ?? false;
                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            key,
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 14.sp,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isDone ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
