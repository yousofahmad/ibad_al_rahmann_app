import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import '../services/prayer_service.dart';
import 'widgets/prayer_detail_modal.dart';
import 'widgets/prayer_ring_widget.dart';
import 'prayer_taqwim_screen.dart';

import '../widgets/app_skeleton.dart';

import 'package:ibad_al_rahmann/main.dart'; // To access scaffoldMessengerKey
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final DateTime _selectedDate = DateTime.now();
  List<ExtendedPrayer> _prayers = [];
  List<ExtendedPrayer> _tomorrowPrayers = [];
  List<ExtendedPrayer> _yesterdayPrayers = [];
  ExtendedPrayer? _nextPrayer;
  Timer? _timer;
  Duration _timeToNext = Duration.zero;
  double _progressValue = 1.0;
  Map<String, String> _notifModes = {};
  Map<String, String> _muezzinNames = {};

  static const Color _goldColor = Color(0xFFD0A871);

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final yesterdayPrayers = await PrayerService().getExtendedPrayers(
      date: _selectedDate.subtract(const Duration(days: 1)),
    );
    final selectedDayPrayers = await PrayerService().getExtendedPrayers(
      date: _selectedDate,
    );
    final tomorrowPrayers = await PrayerService().getExtendedPrayers(
      date: _selectedDate.add(const Duration(days: 1)),
    );

    await _loadStatuses(selectedDayPrayers);

    if (mounted) {
      setState(() {
        _yesterdayPrayers = yesterdayPrayers;
        _prayers = selectedDayPrayers;
        _tomorrowPrayers = tomorrowPrayers;
        _updateNextPrayer();
      });
    }
  }

  Future<void> _loadStatuses(List<ExtendedPrayer> all) async {
    final prefs = CacheHelper.prefs;
    final Map<String, String> modes = {};
    final Map<String, String> names = {};

    for (var p in all) {
      final capKey = p.id[0].toUpperCase() + p.id.substring(1);
      final id = p.id.toLowerCase();

      bool def = (p.prayer != null || id == 'sunrise');
      final notifKey = p.prayer != null ? 'notif_prayer_$id' : 'notif_$id';
      final legacyBool = prefs.getBool(notifKey) ?? def;
      final mode =
          prefs.getString('adhan_mode_$capKey') ??
          (legacyBool ? 'sound' : 'none');
      modes[p.id] = mode;

      if (mode == 'sound') {
        if (p.id == 'sunrise') {
          names[p.id] = 'صوت الشروق';
        } else if (p.id == 'duha') {
          names[p.id] = 'تنبيه الضحى';
        } else if (p.id == 'first_third') {
          names[p.id] = 'تنبيه الثلث الأول';
        } else if (p.id == 'midnight') {
          names[p.id] = 'تنبيه منتصف الليل';
        } else if (p.id == 'last_third') {
          names[p.id] = 'تنبيه الثلث الأخير';
        } else {
          final soundId =
              prefs.getString('adhan_sound_$id') ??
              prefs.getString('adhan_muezzin_id') ??
              'nafis';
          names[p.id] = _getMuezzinName(soundId);
        }
      }
    }

    if (mounted) {
      setState(() {
        _notifModes = modes;
        _muezzinNames = names;
      });
    }
  }

  String _getMuezzinName(String id) {
    const Map<String, String> names = {
      // الأذان
      'nafis': 'أحمد النفيس',
      'mishary': 'مشاري العفاسي (1)',
      'mishary_2': 'مشاري العفاسي (2)',
      'abdulbasit': 'عبد الباسط (1)',
      'abdulbasit_2': 'عبد الباسط (2)',
      'abdulbasit_isha': 'عبد الباسط (العشاء)',
      'abdulbasit_cairo': 'عبد الباسط (القاهرة)',
      'rifat': 'محمد رفعت',
      'banna': 'محمود علي البنا',
      'mustafa_ismail': 'مصطفى إسماعيل',
      'shaisha': 'أبو العينين شعيشع',
      'hussary': 'محمود خليل الحصري',
      'minshawi': 'المنشاوي (1)',
      'minshawi_2': 'المنشاوي (2)',
      'naina_cairo': 'أحمد نعينع',
      'metwalli': 'السيد متولي',
      'nawaf': 'أحمد نواف',
      'mulla': 'علي ملا (مكة)',
      'raml': 'محمد رمل',
      'makkah_16': 'أذان مكة (16)',
      'makkah_19': 'أذان مكة (19)',
      'makkah_20': 'أذان مكة (20)',
      'makkah_3': 'أذان مكة (قديم 1)',
      'makkah_4': 'أذان مكة (قديم 2)',
      'bishi': 'مهدي البيشي',
      'saleh': 'عبد الرزاق صالح',
      'madinah': 'أذان المدينة',
      'madinah_18': 'أذان المدينة (18)',
      'madinah_2': 'أذان المدينة (2)',
      'surayhi': 'السريحي',
      'quds': 'أذان القدس',
      'aqsa_qazzaz': 'ناجي قزاز (1)',
      'aqsa_qazzaz_2': 'ناجي قزاز (2)',
      'turkey_1': 'تركيا (1)',
      'turkey_2': 'تركيا (2)',
      'duman': 'حسين إيرك (تركيا)',
      'syria': 'سوريا',
      'algeria': 'الجزائر',
      'tunisia': 'تونس',
      'kuwait_3': 'الكويت',
      'dubai': 'دبي',
      'oman': 'مسقط',
      'india': 'الهند',
      'pakistan': 'باكستان',
      'indonesia': 'إندونيسيا',
      'malaysia': 'ماليزيا',
      'brunei_1': 'بروني',
      'maldives': 'جزر المالديف',
      'rajhi': 'جامع الراجحي (1)',
      'rajhi_2': 'جامع الراجحي (2)',
      'halabiya': 'حمزة الحلبية',
      'emadi': 'أحمد العمادي',
      'taresh': 'زهير طارش',
      'ajman': 'عجمان',
      'georgia': 'جورجيا',
      'fajr_makkah': 'فجر مكة',
      'fajr_madinah': 'فجر المدينة',
      'fajr_egypt': 'فجر مصر',
      'fajr_quds': 'فجر القدس',
      'fajr_kuwait_1': 'فجر الكويت',
      'fajr_mishary_1': 'فجر مشاري (1)',
      'fajr_mishary_2': 'فجر مشاري (2)',
      'fajr_abdulbasit': 'فجر عبد الباسط',
      'pre_adhan': 'تنبيه عام قبل الأذان',
      'pre_fajr': 'تنبيه قبل الفجر',
      'pre_dhuhr': 'تنبيه قبل الظهر',
      'pre_asr': 'تنبيه قبل العصر',
      'pre_maghrib': 'تنبيه قبل المغرب',
      'pre_isha': 'تنبيه قبل العشاء',
      'iqama': 'الإقامة الافتراضية',
      'full_adhan_makkah': 'أذان مكة الكامل',
      'full_adhan_madina': 'أذان المدينة الكامل',
      'takbeer_makkah': 'تكبيرات مكة',
      'takbeer_madina': 'تكبيرات المدينة',
      'eid_takbeerat': 'تكبيرات العيد',
      'sabah': 'أذكار الصباح',
      'masaa': 'أذكار المساء',
      'saly_3ala_mo7amad': 'صلاة على النبي ﷺ',
      'night_last': 'ثلث الليل الأخير',
      'night_first': 'ثلث الليل الأول',
      'night_mid': 'منتصف الليل',
      'time_duha': 'صلاة الضحى',
      'time_shurooq': 'الشروق',
      'time_suhoor': 'تنبيه السحور',
      'pre_iftar': 'تنبيه الإفطار',
      'ibad_al_rahmann_tone': 'نغمة التطبيق الافتراضية',
      'default': 'نغمة النظام',
    };
    return names[id] ?? 'صوت مخصص';
  }

  void _updateNextPrayer() {
    if (_prayers.isEmpty) return;
    final now = DateTime.now();

    ExtendedPrayer? next;
    for (var p in _prayers) {
      if (p.prayer == Prayer.sunrise) continue;
      if (p.time.isAfter(now)) {
        next = p;
        break;
      }
    }

    if (next == null && _tomorrowPrayers.isNotEmpty) {
      for (var p in _tomorrowPrayers) {
        if (p.prayer == Prayer.sunrise) continue;
        next = p;
        break;
      }
    }

    _nextPrayer = next;
    _updateCountdown();
  }

  void _updateCountdown() {
    if (_nextPrayer == null) return;
    final now = DateTime.now();
    DateTime target = _nextPrayer!.time;

    if (target.isBefore(now)) {
      _loadData();
      return;
    }

    ExtendedPrayer? prev;
    for (var p in _prayers) {
      if (p.prayer == Prayer.sunrise) continue;
      if (p.time.isBefore(now)) {
        prev = p;
      } else {
        break;
      }
    }

    if (prev == null && _yesterdayPrayers.isNotEmpty) {
      prev = _yesterdayPrayers.lastWhere(
        (p) => p.prayer != null && p.prayer != Prayer.sunrise,
      );
    }

    if (prev != null) {
      final total = target.difference(prev.time).inSeconds;
      final remaining = target.difference(now).inSeconds;
      if (total > 0) {
        _progressValue = (remaining / total).clamp(0.0, 1.0);
      }
    }

    setState(() {
      _timeToNext = target.difference(now);
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Future<void> _forceRefreshLocation() async {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text(
          'جاري تحديث الموقع...',
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );

    await PrayerService().updateLocation();
    await _loadData();
    final times = PrayerService().getPrayerTimes();
    if (times != null) {
      await NotificationService.scheduleAll(times, isUserAction: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = _selectedDate.add(Duration(days: hijriOffset));
    final selectedHijri = HijriCalendar.fromDate(adjustedDate);
    final hijriStr =
        "${selectedHijri.hDay} ${selectedHijri.longMonthName} ${selectedHijri.hYear}";
    final gregStr = DateFormat('d MMMM yyyy', 'ar').format(_selectedDate);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              "مواقيت الصلاة",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: _goldColor,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            ListenableBuilder(
              listenable: PrayerService(),
              builder: (context, _) => Text(
                PrayerService().cityName,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _goldColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrayerTaqwimScreen()),
            ),
            tooltip: 'النتيجة اليومية',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefreshLocation,
            tooltip: 'تحديث الموقع',
          ),
        ],
      ),
      body: _prayers.isEmpty
          ? ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              itemCount: 8,
              itemBuilder: (_, __) => AppSkeleton.prayerRow(),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  if (isToday)
                    SizedBox(
                      height: 260.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PrayerRingWidget(
                            percent: _progressValue,
                            color: _goldColor,
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "المتبقي لـ ${_nextPrayer?.name ?? ''}",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  color: Colors.grey,
                                  fontSize: 13.sp,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24.w),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatDuration(_timeToNext),
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                      fontSize: 34.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                hijriStr,
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  color: _goldColor,
                                  fontSize: 13.sp,
                                ),
                              ),
                              Text(
                                gregStr,
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  color: Colors.grey,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    itemCount: isToday
                        ? _prayers.length + _tomorrowPrayers.length + 2
                        : _prayers.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildDateHeader(hijriStr);
                      }
                      if (index <= _prayers.length) {
                        final p = _prayers[index - 1];
                        final isNext = isToday && p == _nextPrayer;
                        return _buildPrayerRow(p, isNext);
                      }
                      if (isToday) {
                        if (index == _prayers.length + 1) {
                          final tomorrowDate = DateTime.now().add(
                            const Duration(days: 1),
                          );
                          final tomorrowH = HijriCalendar.fromDate(
                            tomorrowDate.add(Duration(days: hijriOffset)),
                          );
                          return _buildDateHeader(
                            "${tomorrowH.hDay} ${tomorrowH.longMonthName} ${tomorrowH.hYear}",
                          );
                        }
                        final p = _tomorrowPrayers[index - _prayers.length - 2];
                        final isNext = p == _nextPrayer;
                        return _buildPrayerRow(p, isNext);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDateHeader(String dateText) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        children: [
          const Expanded(child: Divider(color: _goldColor)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Text(
              dateText,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: _goldColor,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ),
          const Expanded(child: Divider(color: _goldColor)),
        ],
      ),
    );
  }

  Widget _buildPrayerRow(ExtendedPrayer p, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBgColor = isActive
        ? _goldColor
        : (isDark ? const Color(0xFF000000) : Colors.white);
    final rowTextColor = isActive
        ? Colors.black
        : (isDark ? Colors.white : Colors.black);
    final timeColor = isActive ? Colors.black : _goldColor;

    final mode = _notifModes[p.id] ?? 'none';
    final muezzin = _muezzinNames[p.id] ?? '';

    String statusText = (mode == 'sound')
        ? muezzin
        : (mode == 'silent_notif' ? 'تنبيه صامت' : 'مُعطَّل');
    IconData? statusIcon = (mode == 'sound')
        ? Icons.volume_up
        : (mode == 'silent_notif'
              ? Icons.notifications_none
              : Icons.notifications_off_outlined);

    return GestureDetector(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => PrayerDetailModal(prayer: p),
        );
        _loadData();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: rowBgColor,
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(
            color: isActive
                ? _goldColor
                : (isDark ? Colors.white10 : _goldColor.withValues(alpha: 0.2)),
            width: isActive ? 1.5.w : 1.0.w,
          ),
          boxShadow: (isActive || !isDark)
              ? [
                  BoxShadow(
                    color: Colors.grey.withAlpha(20),
                    blurRadius: 5.r,
                    offset: Offset(0, 2.h),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: rowTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        statusIcon,
                        size: 10.sp,
                        color: isActive
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.grey,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          color: isActive
                              ? Colors.black.withValues(alpha: 0.6)
                              : Colors.grey,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (isActive) ...[
                  Icon(
                    Icons.timer,
                    size: 16.sp,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    "القادمة",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: Colors.black.withValues(alpha: 0.6),
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                ],
                Text(
                  PrayerService().formatTime(p.time),
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: timeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
