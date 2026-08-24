import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/prayer_service.dart';
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// شاشة "صلاتي" — التركيز للصلاة
/// • Streak مستقل لكل صلاة (5 سلاسل)
/// • تقويم شهري بنقاط ملونة
/// • إحصائيات: في وقتها / متأخراً / فائتة
class PrayerFocusScreen extends StatefulWidget {
  const PrayerFocusScreen({super.key});

  @override
  State<PrayerFocusScreen> createState() => _PrayerFocusScreenState();
}

class _PrayerFocusScreenState extends State<PrayerFocusScreen> with WidgetsBindingObserver {
  String _getLogicalDate() {
    final now = DateTime.now();
    if (now.hour < 4) {
      return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    }
    return DateFormat('yyyy-MM-dd').format(now);
  }
  static const _channel = MethodChannel('app.ibad_al_rahmann/native_notifications');

  // أسماء الصلوات
  static const _prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  // أيقونات الصلوات — يوم الجمعة تظهر صورة الجمعة بدل الظهر
  List<String> get _prayerImages {
    final isFriday = DateTime.now().weekday == DateTime.friday;
    return [
      'assets/images/ic_fajr.png',
      isFriday ? 'assets/images/ic_jumuah_prayer.png' : 'assets/images/ic_dhuhr.png',
      'assets/images/ic_asr.png',
      'assets/images/ic_maghrib.png',
      'assets/images/ic_isha.png',
    ];
  }

  bool _isEnabled = false;
  bool _hasOverlayPermission = false;

  // Streak موحد لجميع الصلوات
  int _unifiedStreak = 0;
  // حالة صلوات اليوم: قيم ممكنة: null (لم يُصلَّ) / 'ontime' / 'late'
  final Map<String, String?> _todayStatus = {};

  // سجل 60 يوم: { 'yyyy-MM-dd' → { 'الفجر' → 'ontime'/'late'/null } }
  final Map<String, Map<String, String?>> _monthLog = {};
  
  // للتنقل بين الشهور في التقويم
  int _calendarMonthOffset = 0;
  DateTime _selectedCalendarDate = DateTime.now();
  
  // إعدادات شاشة التركيز
  int _preAdhanMinutes = 0;   // 0 = معطّل
  int _snoozeDuration  = 5;   // دقائق التأجيل الافتراضية

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (var p in _prayers) {
      _todayStatus[p] = null;
    }
    _unifiedStreak = 0;
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload data when the app comes back from the background
      // This ensures that if the user pressed "Prayed" on the native overlay,
      // the Flutter UI updates immediately.
      _loadData();
    }
  }

  // ─── Loading ────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 🔥 ضروري لسحب التعديلات من Native (نافذة التنبيه)

    // صلاحية overlay
    bool hasPerm = true;
    try {
      hasPerm = await _channel.invokeMethod('checkOverlayPermission') ?? true;
    } catch (_) {}

    // تشغيل الميزة
    final enabled = prefs.getBool('prayer_focus_enabled') ?? false;

    // صلوات اليوم
    final today = _getLogicalDate();
    final todayStatus = <String, String?>{};
    final todayLog = _parseLog(prefs, today);
    for (final p in _prayers) {
      todayStatus[p] = todayLog[p];
    }

    // سجل 60 يوم (شهرين) لدعم التنقل
    final monthLog = <String, Map<String, String?>>{};
    for (int i = 0; i < 62; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      monthLog[key] = _parseLog(prefs, key);
    }
    // اليوم الحالي من todayStatus
    monthLog[today] = Map.from(todayStatus);

    // تحميل إعدادات شاشة التركيز
    final preAdhanMinutes = prefs.getInt('pre_adhan_reminder_minutes') ?? 0;
    final snoozeDuration  = prefs.getInt('focus_snooze_duration')      ?? 5;

    final realStreak = await _recalculateTrueStreak(prefs);

    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _hasOverlayPermission = hasPerm;
        _todayStatus.addAll(todayStatus);
        _monthLog
          ..clear()
          ..addAll(monthLog);
        _unifiedStreak = realStreak;
        _preAdhanMinutes = preAdhanMinutes;
        _snoozeDuration  = snoozeDuration;
      });
    }
  }

  Map<String, String?> _parseLog(SharedPreferences prefs, String date) {
    final raw = prefs.getString('prayer_focus_log_$date')
        ?? prefs.getString('flutter.prayer_focus_log_$date');
    if (raw == null) return {for (var p in _prayers) p: null};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return {
        for (var p in _prayers)
          p: () {
            dynamic val = decoded[p];
            if (p == 'الظهر' && (val == null || val == false)) {
              if (decoded.containsKey('الجمعة')) val = decoded['الجمعة'];
            }
            if (p == 'الجمعة' && (val == null || val == false)) {
              if (decoded.containsKey('الظهر')) val = decoded['الظهر'];
            }
            if (val == null) return null;
            if (val is Map) return (val['status'] as String?) ?? 'on_time';
            if (val is bool) return val ? 'on_time' : null;
            if (val is String) return val.isNotEmpty ? val : null;
            return 'on_time';
          }(),
      };
    } catch (_) {
      return {for (var p in _prayers) p: null};
    }
  }

  Future<int> _recalculateTrueStreak(SharedPreferences prefs) async {
    int streak = 0;
    bool shouldContinue = true;
    final now = DateTime.now();

    // فحص التاريخ بالكامل دون التقيد بشهر واحد (حتى سنتين رجوعاً للخلف)
    for (int dayOffset = 0; dayOffset < 730; dayOffset++) {
      if (!shouldContinue) break;
      final d = now.subtract(Duration(days: dayOffset));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = _parseLog(prefs, dateStr);

      final isFriday = d.weekday == DateTime.friday;
      final prayersInReverse = [
        'العشاء',
        'المغرب',
        'العصر',
        if (isFriday) 'الجمعة' else 'الظهر',
        'الفجر',
      ];

      if (dayOffset == 0) {
        // اليوم الحالي: نبدأ من أحدث صلاة مسجلة
        bool foundLatest = false;
        for (final p in prayersInReverse) {
          final isLogged = log[p] != null;
          if (isLogged) {
            foundLatest = true;
            streak++;
          } else if (foundLatest) {
            // هناك صلاة غير مسجلة سابقة لأحدث صلاة اليوم
            shouldContinue = false;
            break;
          }
        }
      } else {
        // الأيام السابقة: كل صلاة غير مسجلة تكسر الاستريك
        for (final p in prayersInReverse) {
          final isLogged = log[p] != null;
          if (isLogged) {
            streak++;
          } else {
            shouldContinue = false;
            break;
          }
        }
      }
    }

    await prefs.setInt('prayer_streak_unified', streak);
    return streak;
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleFeature(bool value) async {
    if (value && !_hasOverlayPermission) {
      _requestOverlayPermission();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_focus_enabled', value);
    try {
      await _channel.invokeMethod('setPrayerFocusEnabled', {'enabled': value});
    } catch (_) {}
    setState(() => _isEnabled = value);
  }

  Future<void> _requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
      await Future.delayed(const Duration(seconds: 2));
      final hasPerm = await _channel.invokeMethod('checkOverlayPermission') ?? false;
      setState(() => _hasOverlayPermission = hasPerm);
      if (hasPerm && mounted) _toggleFeature(true);
    } catch (_) {}
  }

  /// تسجيل صلاة يدوياً → يُظهر dialog "في وقتها / متأخراً"
  Future<void> _markPrayer(String prayer) async {
    final current = _todayStatus[prayer];
    // لو مصلية → يلغيها
    if (current != null) {
      await _savePrayerStatus(prayer, null);
      return;
    }
    // يسأل: في وقتها أم متأخراً؟
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(prayer, ctx),
    );
    if (result != null) await _savePrayerStatus(prayer, result);
  }

  Future<void> _savePrayerStatusForDate(String prayer, String? status, String dateKey) async {
    final prefs = await SharedPreferences.getInstance();

    final logKey = 'prayer_focus_log_$dateKey';
    final existing = prefs.getString(logKey);
    Map<String, dynamic> logMap = {};
    if (existing != null) {
      try { logMap = json.decode(existing) as Map<String, dynamic>; } catch (_) {}
    }
    if (status == null) {
      logMap.remove(prayer);
    } else {
      logMap[prayer] = {'status': status, 'ts': DateTime.now().millisecondsSinceEpoch};
    }
    await prefs.setString(logKey, json.encode(logMap));

    final todayKey = _getLogicalDate();
    if (dateKey == todayKey) {
      final tempRaw = prefs.getString('temp_prayers');
      final tempMap = <String, dynamic>{};
      if (tempRaw != null) {
        try { tempMap.addAll(json.decode(tempRaw) as Map<String, dynamic>); } catch (_) {}
      }
      if (status == null) {
        tempMap.remove(prayer);
      } else {
        tempMap[prayer] = true;
      }
      await prefs.setString('temp_prayers', json.encode(tempMap));
    }

    // إعادة حساب الاستريك الفعلي من السجل
    final newStreak = await _recalculateTrueStreak(prefs);

    final updatedLog = Map<String, String?>.from(_monthLog[dateKey] ?? {})..[prayer] = status;
    
    if (mounted) {
      setState(() {
        if (dateKey == todayKey) {
          _todayStatus[prayer] = status;
        }
        _unifiedStreak = newStreak;
        _monthLog[dateKey] = updatedLog;
      });
    }
  }

  Future<void> _savePrayerStatus(String prayer, String? status) async {
    final today = _getLogicalDate();
    await _savePrayerStatusForDate(prayer, status, today);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ─── SliverAppBar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 150.h,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(bottom: 12.h),
              title: Text(
                'صلاتي',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontWeight: FontWeight.bold,
                  color: gold, // الذهبي يبرز بشكل رائع على الخلفية الداكنة
                  fontSize: 15.sp, // تصغير الكلمة قليلاً
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A1C14), Color(0xFF120A05)], // خلفية بنية داكنة جداً وفخمة
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 45.h), // رفع الصورة للأعلى لتجنب التداخل مع النص
                    child: Image.asset(
                      'assets/images/header_salati.png',
                      width: 60.w,
                      height: 60.w,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text('🕌', style: TextStyle(fontSize: 52.sp));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.all(16.w),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── 1. بطاقة التفعيل ──────────────────────────────────────
                _buildFeatureCard(isDark, cardBg, gold, textColor),
                SizedBox(height: 16.h),

                // ── 2. صلوات اليوم + Streak لكل صلاة ──────────────────────
                _buildTodayCard(isDark, cardBg, gold, textColor),
                SizedBox(height: 16.h),

                // ── 3. تقويم الشهر التفاعلي ─────────────────────────────────
                _buildCalendarCard(isDark, cardBg, gold, textColor),
                SizedBox(height: 16.h),

                // ── 4. رسم بياني: إتمام الصلاة الأسبوعي ──────────────────
                _buildWeeklyCompletionCard(isDark, cardBg, gold, textColor),
                SizedBox(height: 16.h),

                // ── 5. أعمدة الانتظام: ما مدى انتظامك؟ ───────────────────
                _buildWeeklyConsistencyCard(isDark, cardBg, gold, textColor),
                SizedBox(height: 16.h),

                // ── 6. تحليل أسباب التأخير وتفاصيل الصلوات ──────────────
                _buildDelayHabitsCard(isDark, cardBg, gold, textColor),
                SizedBox(height: 16.h),

                // ── 7. إحصائيات الشهر الإجمالية ───────────────────────────
                _buildStatsCard(isDark, cardBg, gold, textColor),
                SizedBox(height: 32.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature Card ───────────────────────────────────────────────────────────

  Widget _buildFeatureCard(bool isDark, Color cardBg, Color gold, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.mosque_rounded, color: gold, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('شاشة التركيز للصلاة',
                          style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: gold)),
                      Text('تظهر فوق التطبيقات عند كل أذان',
                          style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 12.sp,
                              color: textColor.withValues(alpha: 0.55))),
                    ],
                  ),
                ),
                Switch(value: _isEnabled, activeThumbColor: gold, onChanged: _toggleFeature),
              ],
            ),
          ),
          if (!_hasOverlayPermission)
            InkWell(
              onTap: _requestOverlayPermission,
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  border: Border(top: BorderSide(color: Colors.amber.withValues(alpha: 0.3))),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text('اضغط لمنح صلاحية الظهور فوق التطبيقات',
                          style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 13.sp,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.bold)),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 13.sp),
                  ],
                ),
              ),
            ),
          if (_hasOverlayPermission) ...[
            // إعداد: التذكير قبل الأذان
            _buildSettingRow(
              icon: Icons.notifications_active_outlined,
              label: 'تذكير قبل الأذان',
              gold: gold, textColor: textColor, isDark: isDark,
              child: DropdownButton<int>(
                value: _preAdhanMinutes,
                underline: const SizedBox(),
                dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp, color: gold),
                items: const [
                  DropdownMenuItem(value: 0,  child: Text('معطّل')),
                  DropdownMenuItem(value: 5,  child: Text('5 دق')),
                  DropdownMenuItem(value: 10, child: Text('10 دق')),
                  DropdownMenuItem(value: 15, child: Text('15 دق')),
                  DropdownMenuItem(value: 20, child: Text('20 دق')),
                  DropdownMenuItem(value: 30, child: Text('30 دق')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('pre_adhan_reminder_minutes', v);
                  try {
                    await _channel.invokeMethod('setPreAdhanReminderMinutes', {'minutes': v});
                  } catch (_) {}
                  setState(() => _preAdhanMinutes = v);
                },
              ),
            ),
            // إعداد: وقت التأجيل
            _buildSettingRow(
              icon: Icons.snooze_rounded,
              label: 'تأجيل التذكير',
              gold: gold, textColor: textColor, isDark: isDark,
              child: DropdownButton<int>(
                value: _snoozeDuration,
                underline: const SizedBox(),
                dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 13.sp, color: gold),
                items: const [
                  DropdownMenuItem(value: 3,  child: Text('3 دق')),
                  DropdownMenuItem(value: 5,  child: Text('5 دق')),
                  DropdownMenuItem(value: 10, child: Text('10 دق')),
                  DropdownMenuItem(value: 15, child: Text('15 دق')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('focus_snooze_duration', v);
                  setState(() => _snoozeDuration = v);
                },
              ),
            ),
            // زر معاينة نافذة التنبيه الحديثة
            InkWell(
              onTap: () async {
                try {
                  await _channel.invokeMethod('showFocusOverlayPreview', {
                    'prayerName': 'العصر',
                    'alarmId': 102,
                    'streak': _unifiedStreak,
                  });
                } catch (e) {
                  debugPrint('Failed to show overlay preview: $e');
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: gold.withValues(alpha: 0.12))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.remove_red_eye_outlined, size: 16.sp, color: gold),
                    SizedBox(width: 8.w),
                    Text(
                      'معاينة نافذة التنبيه',
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 13.sp,
                        color: gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12.sp, color: gold),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required Color gold,
    required Color textColor,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: gold.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: gold),
          SizedBox(width: 8.w),
          Text(label,
              style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 13.sp,
                  color: textColor.withValues(alpha: 0.8))),
          const Spacer(),
          child,
        ],
      ),
    );
  }

  // ─── Today Prayers Card ─────────────────────────────────────────────────────

  Widget _buildTodayCard(bool isDark, Color cardBg, Color gold, Color textColor) {
    final doneCount = _todayStatus.values.where((s) => s != null).length;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: gold, size: 22.sp),
                SizedBox(width: 10.w),
                Text('صلوات اليوم',
                    style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: gold)),
                const Spacer(),
                Text('$doneCount / 5',
                    style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: gold)),
              ],
            ),
          ),

          // 5 صلوات مع streak فردي
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_prayers.length, (i) {
                final prayer = _prayers[i];
                final status = _todayStatus[prayer];
                final isDone = status != null;
                final isOnTime = status == 'ontime';
                final circleColor = isDone
                    ? (isOnTime
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE65100))
                    : gold.withValues(alpha: 0.12);
                final borderColor = isDone
                    ? (isOnTime ? const Color(0xFF2E7D32) : const Color(0xFFE65100))
                    : gold.withValues(alpha: 0.4);

                return Column(
                  children: [
                    // دائرة الصلاة
                    GestureDetector(
                      onTap: () => _markPrayer(prayer),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 58.w,
                        height: 58.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: circleColor,
                          border: Border.all(color: borderColor, width: 2),
                          boxShadow: isDone
                              ? [BoxShadow(
                                  color: borderColor.withValues(alpha: 0.35),
                                  blurRadius: 8, spreadRadius: 1)]
                              : [],
                        ),
                        child: Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                _prayerImages[i],
                                width: 30.w,
                                height: 30.w,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.mosque, size: 22.sp, color: isDone ? Colors.white : gold),
                              ),
                              if (isDone)
                                Positioned(
                                  bottom: -4,
                                  right: -4,
                                  child: Container(
                                    padding: EdgeInsets.all(2.w),
                                    decoration: BoxDecoration(
                                      color: isOnTime ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: circleColor, width: 1.5),
                                    ),
                                    child: Text(
                                      isOnTime ? '✓' : '⏳',
                                      style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    // اسم الصلاة
                    Text(
                      (prayer == 'الظهر' && DateTime.now().weekday == DateTime.friday) ? 'الجمعة' : prayer,
                      style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 10.sp,
                          color: isDone ? borderColor : textColor.withValues(alpha: 0.5),
                          fontWeight: isDone ? FontWeight.bold : FontWeight.normal),
                    ),
                    SizedBox(height: 14.h),
                  ],
                );
              }),
            ),
          ),

          // Progress bar
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: LinearProgressIndicator(
                    value: doneCount / 5.0,
                    backgroundColor: gold.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFD0A871)),
                    minHeight: 7.h,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  _progressMessage(doneCount),
                  style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 11.sp,
                      color: textColor.withValues(alpha: 0.45)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers for Hijri and Dates ──────────────────────────────────────────

  String _getHijriDateString(DateTime date) {
    try {
      final h = HijriCalendar.fromDate(date);
      return '${h.hDay} ${h.longMonthName} ${h.hYear} هـ';
    } catch (_) {
      return '';
    }
  }

  int _getDayDoneCount(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final log = _monthLog[key];
    if (log == null) return 0;
    return log.values.where((v) => v != null).length;
  }

  // ─── Calendar Card ──────────────────────────────────────────────────────────

  Widget _buildCalendarCard(bool isDark, Color cardBg, Color gold, Color textColor) {
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + _calendarMonthOffset, 1);
    final daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);
    final firstWeekday = DateTime(displayMonth.year, displayMonth.month, 1).weekday;

    final arabicMonths = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final shortDays = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];

    final selectedDayStr = DateFormat('EEEE، d MMMM yyyy', 'ar').format(_selectedCalendarDate);
    final selectedHijriStr = _getHijriDateString(_selectedCalendarDate);
    final selectedDoneCount = _getDayDoneCount(_selectedCalendarDate);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Header: Navigation
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: gold, size: 22.sp),
                SizedBox(width: 10.w),
                Text('${arabicMonths[displayMonth.month]} ${displayMonth.year}',
                    style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: gold)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: gold, size: 22.sp),
                  onPressed: () => setState(() => _calendarMonthOffset--),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.w),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_left,
                      color: _calendarMonthOffset < 0 ? gold : gold.withValues(alpha: 0.3),
                      size: 22.sp),
                  onPressed: _calendarMonthOffset < 0
                      ? () => setState(() => _calendarMonthOffset++)
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.w),
                ),
              ],
            ),
          ),

          // Selected Day Header Display (Matching Image 1)
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 8.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: gold.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedDayStr,
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (selectedHijriStr.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          selectedHijriStr,
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            fontSize: 11.5.sp,
                            color: gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: selectedDoneCount == 5
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                        : (selectedDoneCount > 0
                            ? gold.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '$selectedDoneCount / 5 صلوات',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: selectedDoneCount == 5
                          ? const Color(0xFF2E7D32)
                          : (selectedDoneCount > 0 ? gold : textColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              children: [
                // أيام الأسبوع
                Row(
                  children: shortDays.map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 10.sp,
                              color: textColor.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold)),
                    ),
                  )).toList(),
                ),
                SizedBox(height: 8.h),

                // الشبكة
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: firstWeekday - 1 + daysInMonth,
                  itemBuilder: (ctx, index) {
                    if (index < firstWeekday - 1) return const SizedBox();
                    final day = index - (firstWeekday - 1) + 1;
                    final dayDate = DateTime(displayMonth.year, displayMonth.month, day);
                    final key = DateFormat('yyyy-MM-dd').format(dayDate);
                    final log = _monthLog[key];
                    final isToday = dayDate.year == now.year && dayDate.month == now.month && day == now.day;
                    final isSelected = dayDate.year == _selectedCalendarDate.year &&
                        dayDate.month == _selectedCalendarDate.month &&
                        dayDate.day == _selectedCalendarDate.day;
                    final isFuture = dayDate.isAfter(now);

                    int ontime = 0, late = 0;
                    if (log != null) {
                      for (final v in log.values) {
                        if (v == 'ontime') ontime++;
                        if (v == 'late') late++;
                      }
                    }
                    final total = ontime + late;

                    Color dotColor;
                    if (isFuture || total == 0) {
                      dotColor = Colors.transparent;
                    } else if (total == 5 && ontime == 5) {
                      dotColor = const Color(0xFF2E7D32);
                    } else if (total == 5) {
                      dotColor = gold;
                    } else if (total > 0) {
                      dotColor = const Color(0xFFE65100);
                    } else {
                      dotColor = Colors.transparent;
                    }

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedCalendarDate = dayDate);
                        _showDayDetails(context, dayDate, log, isDark, cardBg, gold, textColor);
                      },
                      borderRadius: BorderRadius.circular(20.r),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30.w,
                            height: 30.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? const Color(0xFF00897B)
                                  : (isToday ? gold.withValues(alpha: 0.25) : Colors.transparent),
                              border: isToday && !isSelected
                                  ? Border.all(color: gold, width: 1.5)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 11.sp,
                                  color: isSelected
                                      ? Colors.white
                                      : (isToday ? gold : textColor.withValues(alpha: 0.7)),
                                  fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Legend
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot(const Color(0xFF2E7D32), 'في وقتها'),
                    SizedBox(width: 14.w),
                    _legendDot(gold, 'متأخر'),
                    SizedBox(width: 14.w),
                    _legendDot(const Color(0xFFE65100), 'فروض ناقصة'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Weekly Completion Curve Card (Matching Image 2) ────────────────────────

  Widget _buildWeeklyCompletionCard(bool isDark, Color cardBg, Color gold, Color textColor) {
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + _calendarMonthOffset, 1);
    final daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);

    final List<double> weeklyRates = [];

    for (int w = 0; w < 5; w++) {
      final startDay = w * 7 + 1;
      final endDay = (w == 4) ? daysInMonth : (w + 1) * 7;
      if (startDay > daysInMonth) {
        weeklyRates.add(0.0);
        continue;
      }

      int completed = 0;
      int expected = 0;

      for (int d = startDay; d <= endDay; d++) {
        final date = DateTime(displayMonth.year, displayMonth.month, d);
        if (date.isAfter(now)) continue;

        expected += 5;
        final key = DateFormat('yyyy-MM-dd').format(date);
        final log = _monthLog[key];
        if (log != null) {
          completed += log.values.where((v) => v != null).length;
        }
      }

      final rate = expected > 0 ? (completed / expected) * 100.0 : 0.0;
      weeklyRates.add(rate);
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.show_chart_rounded, color: gold, size: 22.sp),
                SizedBox(width: 10.w),
                Text(
                  'إتمام الصلاة الأسبوعي',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: gold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: SizedBox(
              height: 180.h,
              child: CustomPaint(
                size: Size.infinite,
                painter: WeeklyCompletionSplinePainter(
                  weeklyRates: weeklyRates,
                  isDark: isDark,
                  primaryColor: const Color(0xFF00897B),
                  textColor: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Weekly Consistency Bar Chart (Matching Image 2 & 3) ───────────────────

  Widget _buildWeeklyConsistencyCard(bool isDark, Color cardBg, Color gold, Color textColor) {
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + _calendarMonthOffset, 1);
    final daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);

    final List<int> onTimeList = [];
    final List<int> lateList = [];
    final List<int> missedList = [];

    for (int w = 0; w < 5; w++) {
      final startDay = w * 7 + 1;
      final endDay = (w == 4) ? daysInMonth : (w + 1) * 7;
      if (startDay > daysInMonth) {
        onTimeList.add(0);
        lateList.add(0);
        missedList.add(0);
        continue;
      }

      int ot = 0;
      int lt = 0;
      int expected = 0;

      for (int d = startDay; d <= endDay; d++) {
        final date = DateTime(displayMonth.year, displayMonth.month, d);
        if (date.isAfter(now)) continue;

        expected += 5;
        final key = DateFormat('yyyy-MM-dd').format(date);
        final log = _monthLog[key];
        if (log != null) {
          for (var v in log.values) {
            if (v == 'ontime') ot++;
            if (v == 'late') lt++;
          }
        }
      }

      final ms = (expected - (ot + lt)).clamp(0, expected);
      onTimeList.add(ot);
      lateList.add(lt);
      missedList.add(ms);
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.equalizer_rounded, color: gold, size: 22.sp),
                SizedBox(width: 10.w),
                Text(
                  'ما مدى انتظامك؟',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: gold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
            child: SizedBox(
              height: 180.h,
              child: CustomPaint(
                size: Size.infinite,
                painter: WeeklyConsistencyBarPainter(
                  onTimeList: onTimeList,
                  lateList: lateList,
                  missedList: missedList,
                  isDark: isDark,
                  textColor: textColor,
                  onTimeColor: const Color(0xFF00897B),
                  lateColor: const Color(0xFFFBC02D),
                  missedColor: const Color(0xFFE53935),
                ),
              ),
            ),
          ),
          // Legend (Matching Image 3)
          Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _barLegendItem(const Color(0xFFE53935), 'فاتتني (Missed)'),
                SizedBox(width: 14.w),
                _barLegendItem(const Color(0xFFFBC02D), 'متأخراً (Late)'),
                SizedBox(width: 14.w),
                _barLegendItem(const Color(0xFF00897B), 'في وقتها (On Time)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
        SizedBox(width: 5.w),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 10.sp,
            color: const Color(0xFF888888),
          ),
        ),
      ],
    );
  }

  // ─── Delay Habits Card (Matching Image 3) ───────────────────────────────────

  Widget _buildDelayHabitsCard(bool isDark, Color cardBg, Color gold, Color textColor) {
    final Map<String, int> prayerDelayCount = {};
    final Map<String, int> prayerOnTimeCount = {};
    for (var p in _prayers) {
      prayerDelayCount[p] = 0;
      prayerOnTimeCount[p] = 0;
    }

    for (var log in _monthLog.values) {
      for (var p in _prayers) {
        final status = log[p];
        if (status == 'late' || status == null) {
          prayerDelayCount[p] = (prayerDelayCount[p] ?? 0) + 1;
        } else if (status == 'ontime') {
          prayerOnTimeCount[p] = (prayerOnTimeCount[p] ?? 0) + 1;
        }
      }
    }

    String mostDelayedPrayer = 'الفجر';
    int maxDelay = -1;
    for (var entry in prayerDelayCount.entries) {
      if (entry.value > maxDelay) {
        maxDelay = entry.value;
        mostDelayedPrayer = entry.key;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_alt_outlined, color: gold, size: 22.sp),
                SizedBox(width: 10.w),
                Text(
                  'ما الذي يسبب تأخيرك؟',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: gold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: const Color(0xFFE53935), size: 20.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'أكثر صلاة بحاجة لمزيد من الحرص: $mostDelayedPrayer',
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                ..._prayers.map((p) {
                  final ot = prayerOnTimeCount[p] ?? 0;
                  final dl = prayerDelayCount[p] ?? 0;
                  final total = ot + dl;
                  final onTimePct = total > 0 ? (ot / total) : 0.0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p,
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 12.sp,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '${(onTimePct * 100).round()}% في وقتها',
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontSize: 11.sp,
                                color: onTimePct >= 0.7 ? const Color(0xFF00897B) : const Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: onTimePct,
                            minHeight: 6.h,
                            backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(
                              onTimePct >= 0.7 ? const Color(0xFF00897B) : const Color(0xFFFBC02D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Day Details Dialog ─────────────────────────────────────────────────────

  void _showDayDetails(
    BuildContext context, 
    DateTime date, 
    Map<String, String?>? initialLog, 
    bool isDark, 
    Color cardBg, 
    Color gold, 
    Color textColor
  ) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final dateStr = DateFormat('yyyy-MM-dd', 'ar').format(date);
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentLog = _monthLog[dateKey] ?? {};

            return Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "سجل يوم $dateStr",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 16.sp,
                      color: gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ..._prayers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final status = currentLog[p];
                    
                    String statusText = "اضغط للتسجيل";
                    Color statusColor = textColor.withValues(alpha: 0.5);
                    IconData iconData = Icons.radio_button_unchecked;

                    if (status == 'ontime') {
                      statusText = "في وقتها";
                      statusColor = const Color(0xFF2E7D32);
                      iconData = Icons.check_circle;
                    } else if (status == 'late') {
                      statusText = "متأخراً";
                      statusColor = const Color(0xFFE65100);
                      iconData = Icons.access_time_filled;
                    }

                    return InkWell(
                      onTap: () async {
                        if (date.isAfter(now)) return;

                        if (status != null) {
                          await _savePrayerStatusForDate(p, null, dateKey);
                          setModalState(() {});
                        } else {
                          final result = await showDialog<String>(
                            context: context,
                            builder: (dialogCtx) => _buildConfirmDialog(p, dialogCtx),
                          );
                          if (result != null) {
                            await _savePrayerStatusForDate(p, result, dateKey);
                            setModalState(() {});
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(10.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
                        child: Row(
                          children: [
                            Image.asset(
                              _prayerImages[idx],
                              width: 20.w,
                              height: 20.w,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.mosque, size: 20.sp, color: gold),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              p,
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 14.sp,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontSize: 12.sp,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(iconData, color: statusColor, size: 18.sp),
                          ],
                        ),
                      ),
                    );
                  }),
                  SizedBox(height: 16.h),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8.w, height: 8.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        SizedBox(width: 4.w),
        Text(text, style: TextStyle(
            fontFamily: AppConsts.expoArabic, fontSize: 9.sp,
            color: const Color(0xFF888888))),
      ],
    );
  }

  // ─── Stats Card ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard(bool isDark, Color cardBg, Color gold, Color textColor) {
    int totalOnTime = 0, totalLate = 0, totalMissed = 0;
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + _calendarMonthOffset, 1);
    
    int expectedPrayers = 0;
    if (displayMonth.year == now.year && displayMonth.month == now.month) {
      int daysPassed = now.day - 1;
      expectedPrayers += daysPassed * 5;
      final cp = PrayerService().getPrayerTimes()?.currentPrayer() ?? Prayer.none;
      if (cp == Prayer.fajr) {
        expectedPrayers += 1;
      } else if (cp == Prayer.dhuhr) {
        expectedPrayers += 2;
      } else if (cp == Prayer.asr) {
        expectedPrayers += 3;
      } else if (cp == Prayer.maghrib) {
        expectedPrayers += 4;
      } else if (cp == Prayer.isha) {
        expectedPrayers += 5;
      }
    } else if (displayMonth.isBefore(now)) {
      int daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);
      expectedPrayers += daysInMonth * 5;
    }

    final monthEntries = _monthLog.entries.where((e) {
      try {
        final d = DateTime.parse(e.key);
        return d.year == displayMonth.year && d.month == displayMonth.month;
      } catch (_) { return false; }
    });

    for (final entry in monthEntries) {
      for (final status in entry.value.values) {
        if (status == 'ontime') {
          totalOnTime++;
        } else if (status == 'late') {
          totalLate++;
        }
      }
    }
    totalMissed = expectedPrayers - (totalOnTime + totalLate);
    if (totalMissed < 0) totalMissed = 0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: gold, size: 22.sp),
                SizedBox(width: 10.w),
                Text('إحصائيات الشهر',
                    style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: gold)),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  children: [
                    _statBubble('في وقتها', totalOnTime, const Color(0xFF2E7D32), textColor),
                    SizedBox(width: 8.w),
                    _statBubble('متأخراً', totalLate, const Color(0xFFE65100), textColor),
                    SizedBox(width: 8.w),
                    _statBubble('فائتة', totalMissed, const Color(0xFFB0BEC5), textColor),
                  ],
                ),
                SizedBox(height: 20.h),
                ..._prayers.map((prayer) {
                  int pOnTime = 0, pLate = 0;
                  for (final log in _monthLog.values) {
                    final s = log[prayer];
                    if (s == 'ontime') {
                      pOnTime++;
                    } else if (s == 'late') {
                      pLate++;
                    }
                  }
                  final pTotal = _monthLog.length;
                  final pDone = pOnTime + pLate;
                  final pct = pTotal > 0 ? pDone / pTotal : 0.0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46.w,
                          child: Text(prayer,
                              style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 11.sp,
                                  color: textColor.withValues(alpha: 0.65))),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 10.h,
                                decoration: BoxDecoration(
                                    color: textColor.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(6.r)),
                              ),
                              FractionallySizedBox(
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(
                                  height: 10.h,
                                  decoration: BoxDecoration(
                                    color: pct > 0.8
                                        ? const Color(0xFF2E7D32)
                                        : pct > 0.4
                                            ? gold
                                            : const Color(0xFFE65100),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBubble(String label, int count, Color color, Color textColor) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 10.sp,
                    color: textColor.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  // ─── Confirm Dialog ─────────────────────────────────────────────────────────

  Widget _buildConfirmDialog(String prayer, BuildContext ctx) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      title: Text(
        'صلاة $prayer',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD0A871)),
      ),
      content: Text(
        'هل صليتَها في وقتها أم متأخراً؟',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 14.sp),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'ontime'),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          ),
          child: Text('في وقتها ✓',
              style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 14.sp,
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'late'),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFE65100).withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          ),
          child: Text('متأخراً ⏳',
              style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 14.sp,
                  color: const Color(0xFFE65100),
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _progressMessage(int count) {
    if (count == 0) return 'لم تُسجَّل أي صلاة بعد — اضغط على الدائرة لتسجيل';
    if (count == 5) return 'أتممتَ الصلوات الخمس! تقبّل الله طاعتك ✓';
    return 'باقي ${5 - count} صلاة';
  }
}

// ─── Custom Chart Painters ──────────────────────────────────────────────────

class WeeklyCompletionSplinePainter extends CustomPainter {
  final List<double> weeklyRates;
  final bool isDark;
  final Color primaryColor;
  final Color textColor;

  WeeklyCompletionSplinePainter({
    required this.weeklyRates,
    required this.isDark,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 16.0;
    const double rightPadding = 48.0;
    const double topPadding = 16.0;
    const double bottomPadding = 36.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.rtl,
    );

    for (int i = 0; i <= 5; i++) {
      final pct = (100 - i * 20);
      final y = topPadding + (i / 5.0) * chartHeight;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final textSpan = TextSpan(
        text: '$pct\n%',
        style: TextStyle(
          fontFamily: AppConsts.cairo,
          fontSize: 9.5.sp,
          height: 1.0,
          color: textColor.withValues(alpha: 0.5),
        ),
      );
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding + chartWidth + 6.0, y - (textPainter.height / 2)),
      );
    }

    if (weeklyRates.isEmpty) return;

    final points = <Offset>[];
    for (int i = 0; i < 5; i++) {
      final double x = leftPadding + (i / 4.0) * chartWidth;
      final double rate = (i < weeklyRates.length ? weeklyRates[i] : 0.0).clamp(0.0, 100.0);
      final double y = topPadding + (1.0 - (rate / 100.0)) * chartHeight;
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final cp1 = Offset((midX + p0.dx) / 2, p0.dy);
      final cp2 = Offset((midX + p1.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, topPadding + chartHeight)
      ..lineTo(points.first.dx, topPadding + chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.35),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()..color = primaryColor;
    final dotBorderPaint = Paint()
      ..color = isDark ? const Color(0xFF1E1E1E) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      canvas.drawCircle(pt, 5.0, dotPaint);
      canvas.drawCircle(pt, 5.0, dotBorderPaint);

      final textSpan = TextSpan(
        text: '${i + 1}',
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: textColor.withValues(alpha: 0.75),
        ),
      );
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pt.dx - (textPainter.width / 2), topPadding + chartHeight + 6.0),
      );
    }

    final weekLabelSpan = TextSpan(
      text: 'أسبوع',
      style: TextStyle(
        fontFamily: AppConsts.expoArabic,
        fontSize: 11.sp,
        color: textColor.withValues(alpha: 0.5),
      ),
    );
    textPainter.text = weekLabelSpan;
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((leftPadding + (chartWidth / 2)) - (textPainter.width / 2), topPadding + chartHeight + 20.0),
    );
  }

  @override
  bool shouldRepaint(covariant WeeklyCompletionSplinePainter oldDelegate) => true;
}

class WeeklyConsistencyBarPainter extends CustomPainter {
  final List<int> onTimeList;
  final List<int> lateList;
  final List<int> missedList;
  final bool isDark;
  final Color textColor;
  final Color onTimeColor;
  final Color lateColor;
  final Color missedColor;

  WeeklyConsistencyBarPainter({
    required this.onTimeList,
    required this.lateList,
    required this.missedList,
    required this.isDark,
    required this.textColor,
    required this.onTimeColor,
    required this.lateColor,
    required this.missedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 16.0;
    const double rightPadding = 36.0;
    const double topPadding = 16.0;
    const double bottomPadding = 36.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    int maxVal = 10;
    for (int i = 0; i < 5; i++) {
      final ot = i < onTimeList.length ? onTimeList[i] : 0;
      final lt = i < lateList.length ? lateList[i] : 0;
      final ms = i < missedList.length ? missedList[i] : 0;
      final m = [ot, lt, ms].reduce((a, b) => a > b ? a : b);
      if (m > maxVal) maxVal = m;
    }
    maxVal = ((maxVal + 4) ~/ 5) * 5;
    if (maxVal < 10) maxVal = 10;

    final steps = [maxVal, (maxVal * 0.7).round(), (maxVal * 0.5).round(), (maxVal * 0.2).round(), 0];
    for (int step in steps) {
      final y = topPadding + (1.0 - (step / maxVal)) * chartHeight;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final textSpan = TextSpan(
        text: '$step',
        style: TextStyle(
          fontFamily: AppConsts.cairo,
          fontSize: 9.5.sp,
          color: textColor.withValues(alpha: 0.45),
        ),
      );
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding + chartWidth + 6.0, y - (textPainter.height / 2)));
    }

    final barGroupWidth = chartWidth / 5.0;
    final singleBarWidth = 6.5.w;

    final onTimePaint = Paint()..color = onTimeColor;
    final latePaint = Paint()..color = lateColor;
    final missedPaint = Paint()..color = missedColor;

    for (int i = 0; i < 5; i++) {
      final centerX = leftPadding + (i * barGroupWidth) + (barGroupWidth / 2);
      final ot = (i < onTimeList.length ? onTimeList[i] : 0).clamp(0, maxVal);
      final lt = (i < lateList.length ? lateList[i] : 0).clamp(0, maxVal);
      final ms = (i < missedList.length ? missedList[i] : 0).clamp(0, maxVal);

      final baseY = topPadding + chartHeight;

      if (ot > 0) {
        final otHeight = (ot / maxVal) * chartHeight;
        final otRect = Rect.fromLTWH(centerX - singleBarWidth * 1.5 - 2, baseY - otHeight, singleBarWidth, otHeight);
        canvas.drawRRect(RRect.fromRectAndRadius(otRect, Radius.circular(3.r)), onTimePaint);
      }

      if (lt > 0) {
        final ltHeight = (lt / maxVal) * chartHeight;
        final ltRect = Rect.fromLTWH(centerX - singleBarWidth * 0.5, baseY - ltHeight, singleBarWidth, ltHeight);
        canvas.drawRRect(RRect.fromRectAndRadius(ltRect, Radius.circular(3.r)), latePaint);
      }

      if (ms > 0) {
        final msHeight = (ms / maxVal) * chartHeight;
        final msRect = Rect.fromLTWH(centerX + singleBarWidth * 0.5 + 2, baseY - msHeight, singleBarWidth, msHeight);
        canvas.drawRRect(RRect.fromRectAndRadius(msRect, Radius.circular(3.r)), missedPaint);
      }

      final textSpan = TextSpan(
        text: '${i + 1}',
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: textColor.withValues(alpha: 0.75),
        ),
      );
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - (textPainter.width / 2), baseY + 6.0),
      );
    }

    final weekLabelSpan = TextSpan(
      text: 'أسبوع',
      style: TextStyle(
        fontFamily: AppConsts.expoArabic,
        fontSize: 11.sp,
        color: textColor.withValues(alpha: 0.5),
      ),
    );
    textPainter.text = weekLabelSpan;
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((leftPadding + (chartWidth / 2)) - (textPainter.width / 2), topPadding + chartHeight + 20.0),
    );
  }

  @override
  bool shouldRepaint(covariant WeeklyConsistencyBarPainter oldDelegate) => true;
}
