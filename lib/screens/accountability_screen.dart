import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'stats_screen.dart';
import '../services/daily_tracker_service.dart';

import 'package:ibad_al_rahmann/main.dart'; // To access scaffoldMessengerKey
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

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

  bool _isLoading = true;

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
      setState(() {
        _isLoading = false;
      });
    }
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

    final String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

  // دالة حفظ السجل التاريخي (الإحصائيات النهائية)
  Future<void> _saveProgressToHistory() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snackBg = isDark ? const Color(0xFF000000) : const Color(0xFFD0A871);
    const snackText = Colors.white;

    await _saveStatsSilent();

    if (!mounted) return;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text(
          "تم حفظ إنجاز اليوم في السجل! تقبل الله",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: snackText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: snackBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
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

                          // زر الحفظ النهائي
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD0A871),
                              minimumSize: Size(double.infinity, 55.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.r),
                              ),
                              elevation: 5,
                              shadowColor: const Color(
                                0xFFD0A871,
                              ).withValues(alpha: 0.5),
                            ),
                            onPressed: _saveProgressToHistory,
                            child: Text(
                              "تسجيل اليوم في السجل",
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 18.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD0A871),
                        ),
                      ),
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
}
