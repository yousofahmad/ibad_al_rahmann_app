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
  // بيانات الأقسام (شلت final عشان نقدر نعدل عليها لما نحمل البيانات)
  final Map<String, bool> _prayers = {
    'الفجر': false,
    'الظهر': false,
    'العصر': false,
    'المغرب': false,
    'العشاء': false,
    'الضحى': false,
    'القيام': false,
    'السنن': false,
  };

  final Map<String, bool> _quran = {
    'ورد التلاوة': false,
    'حفظ جديد': false,
    'مراجعة': false,
    'سماع قرآن': false,
  };

  final Map<String, bool> _azkar = {
    'أذكار الصباح': false,
    'أذكار المساء': false,
    'أذكار النوم': false,
    'أذكار الصلاة': false,
  };

  final Map<String, bool> _goodDeeds = {
    'بر الوالدين': false,
    'صدقة': false,
    'صلة رحم': false,
    'إطعام مسكين': false,
    'زيارة مريض': false,
    'طلب علم': false,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyProgress();
  }

  // 🔥 دالة تحميل البيانات المحفوظة لليوم الحالي 🔥
  Future<void> _loadDailyProgress() async {
    final prefs = CacheHelper.prefs;
    // 🔥 ضروري: نجيب البيانات من الديسك أولاً BEFORE أي reset منطق
    // عشان البيانات اللي كتبها الأندرويد النيتف (PrayerFocusOverlay) متتمسحش
    await prefs.reload();

    // ✅ احفظ البيانات النيتف المهمة قبل أي reset
    final nativeTempPrayers = prefs.getString('temp_prayers');

    // ✅ التأكد من تهيئة بيانات اليوم وعمل Reset لو يوم جديد
    await DailyTrackerService.initStatsForToday();

    // ✅ لو DailyTracker مسح temp_prayers (يوم جديد) ارجع للبيانات النيتف لو موجودة
    // (ممكن تكون كتبها PrayerFocusOverlay قبل ما الفلاتر يفتح)
    if (nativeTempPrayers != null && prefs.getString('temp_prayers') == null) {
      await prefs.setString('temp_prayers', nativeTempPrayers);
    }

    await prefs.reload(); // Reload مرة تانية بعد initStatsForToday

    // ✅ استرجاع العلامات التي علمناها لليوم الحالي
    _loadMapFromPrefs(prefs, 'temp_prayers', _prayers);
    _loadMapFromPrefs(prefs, 'temp_quran', _quran);
    _loadMapFromPrefs(prefs, 'temp_deeds', _goodDeeds);

    // Load Azkar from Service + Prefs
    _azkar['أذكار الصباح'] = await DailyTrackerService.isDone('morning_azkar');
    _azkar['أذكار المساء'] = await DailyTrackerService.isDone('evening_azkar');
    _azkar['أذكار الصلاة'] = await DailyTrackerService.isDone('prayer_azkar');

    // Load others from manual prefs if exists
    String? jsonStr = prefs.getString('temp_azkar');
    if (jsonStr != null) {
      Map<String, dynamic> decoded = json.decode(jsonStr);
      if (decoded.containsKey('أذكار النوم')) {
        _azkar['أذكار النوم'] = decoded['أذكار النوم'];
      }
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
        if (targetMap.containsKey(actualKey)) {
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
    // بنحول الماب لنص JSON ونحفظها في مفتاح مؤقت
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
    // هذا يمنع الإحباط ويشجع على الاستمرار
    if (azkarScore >= 50.0) {
      final morningDone = _azkar['أذكار الصباح'] ?? false;
      final eveningDone = _azkar['أذكار المساء'] ?? false;
      // لو عدلها من شاشة حاسب نفسك ولم يدخل صفحة الأذكار، نسجل الاستريك
      if (morningDone) await DailyTrackerService.markAsDone('morning_azkar');
      if (eveningDone) await DailyTrackerService.markAsDone('evening_azkar');
    }
  }

  // دالة حفظ السجل التاريخي (الإحصائيات النهائية)
  Future<void> _saveProgressToHistory() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snackBg = isDark ? const Color(0xFF000000) : const Color(0xFFD0A871);
    const snackText = Colors.white;

    // الحفظ الفعلي
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

  // ... (دالة _reviewOldEntry و _showDayStatsDialog زي ما هما في كودك القديم، مفيش تغيير) ...
  // انسخهم هنا زي ما كانوا

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
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final String dateKey =
          "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
      // تصليح بسيط عشان يتوافق مع صيغة DateFormat اللي فوق
      final String formattedKey = DateFormat('yyyy-MM-dd').format(pickedDate);

      final prefs = CacheHelper.prefs;
      // بنجرب الصيغتين عشان التوافق
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

  @override
  Widget build(BuildContext context) {
    // 1. تعريف الألوان حسب الوضع
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
                          // 👇 تمرير مفتاح الحفظ لكل قسم
                          _buildSection(
                            "الصلاة",
                            "الصلاة نور وبرهان",
                            _prayers,
                            "temp_prayers",
                          ),
                          _buildSection(
                            "القرآن الكريم",
                            "القرآن شفيع لأصحابه",
                            _quran,
                            "temp_quran",
                          ),
                          _buildSection(
                            "الأذكار",
                            "ألا بذكر الله تطمئن القلوب",
                            _azkar,
                            "temp_azkar",
                          ),
                          _buildSection(
                            "الطاعات",
                            "وسارعوا إلى مغفرة",
                            _goodDeeds,
                            "temp_deeds",
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
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: const Color(0xFFD0A871).withValues(alpha: 0.15),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20.r),
              ),
            ),
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
          Padding(
            padding: EdgeInsets.all(10.w),
            child: Wrap(
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
                      value: dataMap[key],
                      onChanged: (val) {
                        // 👇 التعديل هنا: الحفظ الفوري
                        _updateStateAndSave(dataMap, storageKey, key, val!);
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
