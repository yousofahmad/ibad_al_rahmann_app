import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:flutter/services.dart';
import 'qada_list_screen.dart';

// New Imports for Share Cards
import 'package:ibad_al_rahmann/features/share_cards/models/share_card_model.dart';
import 'package:ibad_al_rahmann/features/share_cards/services/share_cards_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

const _gold = Color(0xFFD0A871);

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  bool _iftarAlarm = false;
  bool _suhoorAlarm = false;
  bool _eidFitr = false;
  bool _eidFitrTakbeer = false;
  String _iftarMode = 'ramadan';
  String _suhoorMode = 'ramadan';
  int _iftarMinutesBefore = 30;
  int _suhoorMinutesBefore = 60;
  int _iftarDays = 0x7F;
  int _suhoorDays = 0x7F;
  int _eidFitrTakbeerInterval = 15;
  int _eidFitrMinutesAfterSunrise = 30;
  int _qadaCount = 0;
  int _ishaDelayMode = 0;

  // Share Cards State
  final ShareCardsService _shareService = ShareCardsService();
  List<ShareCardItem> _ramadanCards = [];
  bool _loadingCards = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadSettings();
    _loadRamadanCards();
  }

  Future<void> _loadRamadanCards() async {
    final categories = await _shareService.fetchShareCards();
    if (mounted) {
      setState(() {
        final ramadanCat = categories.firstWhere(
          (c) => c.categoryName.contains('رمضان'),
          orElse: () => ShareCardCategory(categoryName: '', items: []),
        );
        _ramadanCards = ramadanCat.items;
        _loadingCards = false;
      });
    }
  }

  Future<void> _shareCard(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/ramadan_share.jpg";
      await Dio().download(url, path);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'رمضان كريم من تطبيق عباد الرحمن');
    } catch (_) {}
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

  Future<void> _loadSettings() async {
    final prefs = CacheHelper.prefs;
    int missed = 0;
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = DateTime.now().add(Duration(days: hijriOffset));
    int year = HijriCalendar.fromDate(adjustedDate).hYear;
    for (int i = 1; i <= 30; i++) {
      if (prefs.getBool('qada_${year}_$i') ?? false) missed++;
    }
    setState(() {
      _iftarAlarm = prefs.getBool('iftar_alarm') ?? false;
      _suhoorAlarm = prefs.getBool('suhoor_alarm') ?? false;
      _eidFitr =
          prefs.getBool('eid_fitr_alarm') ??
          prefs.getBool('eid_alarm') ??
          false;
      _eidFitrTakbeer = prefs.getBool('eid_fitr_takbeer') ?? false;
      _iftarMode = prefs.getString('iftar_mode') ?? 'ramadan';
      _suhoorMode = prefs.getString('suhoor_mode') ?? 'ramadan';
      _iftarMinutesBefore = prefs.getInt('iftar_minutes_before') ?? 30;
      _suhoorMinutesBefore = prefs.getInt('suhoor_minutes_before') ?? 60;
      _iftarDays = prefs.getInt('iftar_all_year_days') ?? 0x7F;
      _suhoorDays = prefs.getInt('suhoor_all_year_days') ?? 0x7F;
      _eidFitrTakbeerInterval = prefs.getInt('eid_fitr_takbeer_interval') ?? 15;
      _eidFitrMinutesAfterSunrise =
          prefs.getInt('eid_prayer_minutes_after_sunrise') ?? 30;
      _qadaCount = missed;
      _ishaDelayMode = PrayerService().ramadanIshaDelayMode;
    });
  }

  Future<void> _save(String key, dynamic val) async {
    final prefs = CacheHelper.prefs;
    if (val is bool) await prefs.setBool(key, val);
    if (val is int) await prefs.setInt(key, val);
    if (val is String) await prefs.setString(key, val);
    PrayerService().scheduleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 100.h,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "رمضان كريم",
          style: TextStyle(
            fontFamily: AppConsts.motoNastaliq,
            color: _gold,
            fontWeight: FontWeight.bold,
            fontSize: 38.sp,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 30.h, left: 16.w, right: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Ramadan Share Cards Section ────────────────────────────────
            if (_loadingCards)
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[900]! : Colors.grey[300]!,
                  highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  child: Container(
                    height: 140.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                ),
              )
            else if (_ramadanCards.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: SizedBox(
                  height: 160.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // Arabic RTL feel
                    itemCount: _ramadanCards.length,
                    itemBuilder: (context, index) {
                      final item = _ramadanCards[index];
                      final fullUrl = _shareService.getFullImageUrl(item.url);
                      return GestureDetector(
                        onTap: () => _shareCard(fullUrl),
                        child: Container(
                          width: 130.w,
                          margin: EdgeInsets.only(left: 12.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15.r),
                            border: Border.all(color: _gold.withValues(alpha: 0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15.r),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: fullUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: isDark ? Colors.black26 : Colors.grey[100]),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [Colors.black54, Colors.transparent],
                                      ),
                                    ),
                                    padding: EdgeInsets.all(6.w),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.share, color: Colors.white, size: 14.sp),
                                        SizedBox(width: 4.w),
                                        Text(
                                          "مشاركة",
                                          style: TextStyle(color: Colors.white, fontSize: 10.sp, fontFamily: 'Cairo'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── Qada Card ──────────────────────────────────────────────────
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QadaListScreen()),
                );
                _loadSettings();
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD0A871), Color(0xFFB88E50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.3),
                      blurRadius: 12.r,
                      offset: Offset(0, 5.h),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 25.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "أيام القضاء",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "الأيام التي فاتتك: $_qadaCount",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: Colors.white70,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ── Alarms Section ─────────────────────────────────────────────
            _sectionHeader("تنبيهات الصيام"),

            // Iftar
            _buildIftarSuhoorCard(
              title: 'منبه الإفطار',
              icon: Icons.dinner_dining_outlined,
              alarmKey: 'iftar_alarm',
              modeKey: 'iftar_mode',
              minutesKey: 'iftar_minutes_before',
              daysKey: 'iftar_all_year_days',
              isOn: _iftarAlarm,
              mode: _iftarMode,
              minutes: _iftarMinutesBefore,
              days: _iftarDays,
              prayer: 'المغرب',
              onToggle: (v) {
                setState(() => _iftarAlarm = v);
                _save('iftar_alarm', v);
              },
              onMode: (v) {
                setState(() => _iftarMode = v);
                _save('iftar_mode', v);
              },
              onMinutes: (v) {
                setState(() => _iftarMinutesBefore = v);
                _save('iftar_minutes_before', v);
              },
              onDays: (v) {
                setState(() => _iftarDays = v);
                _save('iftar_all_year_days', v);
              },
            ),
            SizedBox(height: 10.h),

            // Suhoor
            _buildIftarSuhoorCard(
              title: 'منبه السحور',
              icon: Icons.restaurant_outlined,
              alarmKey: 'suhoor_alarm',
              modeKey: 'suhoor_mode',
              minutesKey: 'suhoor_minutes_before',
              daysKey: 'suhoor_all_year_days',
              isOn: _suhoorAlarm,
              mode: _suhoorMode,
              minutes: _suhoorMinutesBefore,
              days: _suhoorDays,
              prayer: 'الفجر',
              onToggle: (v) {
                setState(() => _suhoorAlarm = v);
                _save('suhoor_alarm', v);
              },
              onMode: (v) {
                setState(() => _suhoorMode = v);
                _save('suhoor_mode', v);
              },
              onMinutes: (v) {
                setState(() => _suhoorMinutesBefore = v);
                _save('suhoor_minutes_before', v);
              },
              onDays: (v) {
                setState(() => _suhoorDays = v);
                _save('suhoor_all_year_days', v);
              },
            ),

            SizedBox(height: 24.h),
            _sectionHeader("تنبيهات عيد الفطر"),

            // Eid prayer
            _expandableCard(
              icon: Icons.celebration_outlined,
              title: 'منبه صلاة العيد',
              subtitle: '$_eidFitrMinutesAfterSunrise دقيقة بعد الشروق',
              value: _eidFitr,
              onToggle: (v) {
                setState(() => _eidFitr = v);
                _save('eid_fitr_alarm', v);
              },
              expanded: _eidFitr,
              child: _minutesPicker(
                label: 'الدقائق بعد الشروق',
                value: _eidFitrMinutesAfterSunrise,
                min: 10,
                max: 90,
                step: 10,
                onChanged: (v) {
                  setState(() => _eidFitrMinutesAfterSunrise = v);
                  _save('eid_prayer_minutes_after_sunrise', v);
                },
              ),
            ),
            SizedBox(height: 10.h),

            // Eid Fitr Takbeer chain
            _expandableCard(
              icon: Icons.graphic_eq_outlined,
              title: 'تكبيرات عيد الفطر',
              subtitle:
                  'تكبير كل $_eidFitrTakbeerInterval دقيقة ابتداءً من ليلة العيد',
              value: _eidFitrTakbeer,
              onToggle: (v) {
                setState(() => _eidFitrTakbeer = v);
                _save('eid_fitr_takbeer', v);
              },
              expanded: _eidFitrTakbeer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الله أكبر الله أكبر الله أكبر، لا إله إلا الله، الله أكبر الله أكبر ولله الحمد',
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      color: _gold,
                      fontSize: 12.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  _intervalChips(
                    label: 'الفترة بين كل تكبير والتالي',
                    options: const [5, 10, 15, 20, 30],
                    labels: const ['5 دق', '10 دق', '15 دق', '20 دق', '30 دق'],
                    value: _eidFitrTakbeerInterval,
                    onChanged: (v) {
                      setState(() => _eidFitrTakbeerInterval = v);
                      _save('eid_fitr_takbeer_interval', v);
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // ── Isha Mode ──────────────────────────────────────────────────
            _sectionHeader("وقت العشاء"),
            _buildIshaCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: _gold,
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIshaCard(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(40),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: Column(
        children: [
          RadioListTile<int>(
            activeColor: _gold,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            title: Text(
              'الوقت الأصلي',
              style: TextStyle(
                color: textColor,
                fontFamily: AppConsts.cairo,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'حسب الحساب الفلكي',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12.sp,
                fontFamily: AppConsts.cairo,
              ),
            ),
            value: 0,
            // ignore: deprecated_member_use
            groupValue: _ishaDelayMode,
            // ignore: deprecated_member_use
            onChanged: (v) async {
              if (v != null) {
                await PrayerService().saveRamadanIshaDelay(v);
                setState(() => _ishaDelayMode = v);
              }
            },
          ),
          Divider(color: Colors.grey.withAlpha(30), height: 1.h),
          RadioListTile<int>(
            activeColor: _gold,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            title: Text(
              'بعد المغرب بـ 90 دقيقة',
              style: TextStyle(
                color: textColor,
                fontFamily: AppConsts.cairo,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'توقيت شائع في رمضان',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12.sp,
                fontFamily: AppConsts.cairo,
              ),
            ),
            value: 90,
            // ignore: deprecated_member_use
            groupValue: _ishaDelayMode,
            // ignore: deprecated_member_use
            onChanged: (v) async {
              if (v != null) {
                await PrayerService().saveRamadanIshaDelay(v);
                setState(() => _ishaDelayMode = v);
              }
            },
          ),
          Divider(color: Colors.grey.withAlpha(30), height: 1.h),
          RadioListTile<int>(
            activeColor: _gold,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            title: Text(
              'بعد المغرب بـ 120 دقيقة',
              style: TextStyle(
                color: textColor,
                fontFamily: AppConsts.cairo,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'تأخير رمضاني',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12.sp,
                fontFamily: AppConsts.cairo,
              ),
            ),
            value: 120,
            // ignore: deprecated_member_use
            groupValue: _ishaDelayMode,
            // ignore: deprecated_member_use
            onChanged: (v) async {
              if (v != null) {
                await PrayerService().saveRamadanIshaDelay(v);
                setState(() => _ishaDelayMode = v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIftarSuhoorCard({
    required String title,
    required IconData icon,
    required String alarmKey,
    required String modeKey,
    required String minutesKey,
    required String daysKey,
    required bool isOn,
    required String mode,
    required int minutes,
    required int days,
    required String prayer,
    required ValueChanged<bool> onToggle,
    required ValueChanged<String> onMode,
    required ValueChanged<int> onMinutes,
    required ValueChanged<int> onDays,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(40),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            secondary: Icon(icon, color: _gold, size: 22.sp),
            activeThumbColor: _gold,
            activeTrackColor: _gold.withAlpha(80),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: isDark ? Colors.black26 : Colors.grey.shade300,
            title: Text(
              title,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 16.sp,
              ),
            ),
            subtitle: Text(
              '$minutes دقيقة قبل $prayer',
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                color: Colors.grey,
                fontSize: 12.sp,
              ),
            ),
            value: isOn,
            onChanged: onToggle,
          ),
          if (isOn)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _minutesPicker(
                    label: 'الدقائق قبل $prayer',
                    value: minutes,
                    min: 5,
                    max: 120,
                    step: 5,
                    onChanged: onMinutes,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'متى يُشغَّل؟',
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      color: textColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _gold.withAlpha(220),
                      selectedForegroundColor: Colors.white,
                      foregroundColor: textColor,
                      textStyle: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 12.sp,
                      ),
                    ),
                    segments: [
                      ButtonSegment(
                        value: 'ramadan',
                        label: const Text('رمضان فقط'),
                        icon: Icon(Icons.nights_stay, size: 14.sp),
                      ),
                      ButtonSegment(
                        value: 'all_year',
                        label: const Text('طوال العام'),
                        icon: Icon(Icons.calendar_month, size: 14.sp),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => onMode(s.first),
                  ),
                  if (mode == 'all_year') ...[
                    SizedBox(height: 12.h),
                    Text(
                      'أيام الأسبوع',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        color: textColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _daysBitmaskPicker(days: days, onChanged: onDays),
                  ],
                  SizedBox(height: 12.h),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _daysBitmaskPicker({
    required int days,
    required ValueChanged<int> onChanged,
  }) {
    const dayNames = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    const dayLabels = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return Wrap(
      spacing: 8.w,
      children: List.generate(7, (i) {
        final bit = 1 << i;
        final selected = (days & bit) != 0;
        return Tooltip(
          message: dayLabels[i],
          child: GestureDetector(
            onTap: () => onChanged(selected ? (days & ~bit) : (days | bit)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38.w,
              height: 38.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _gold : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _gold : Colors.grey.withAlpha(100),
                ),
              ),
              child: Text(
                dayNames[i],
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  color: selected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _minutesPicker({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $value دقيقة',
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            color: Colors.grey,
            fontSize: 12.sp,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: _gold, size: 24.sp),
              onPressed: value > min
                  ? () => onChanged((value - step).clamp(min, max))
                  : null,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _gold,
                  thumbColor: _gold,
                  inactiveTrackColor: _gold.withAlpha(60),
                  overlayColor: _gold.withAlpha(30),
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.r),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 20.r),
                ),
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - min) ~/ step,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: _gold, size: 24.sp),
              onPressed: value < max
                  ? () => onChanged((value + step).clamp(min, max))
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _expandableCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onToggle,
    required bool expanded,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(40),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(icon, color: _gold, size: 22.sp),
            activeThumbColor: _gold,
            activeTrackColor: _gold.withAlpha(80),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: isDark ? Colors.black26 : Colors.grey.shade300,
            title: Text(
              title,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16.sp,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                color: Colors.grey,
                fontSize: 12.sp,
              ),
            ),
            value: value,
            onChanged: onToggle,
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 14.h),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _intervalChips({
    required String label,
    required List<int> options,
    required List<String> labels,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            color: Colors.grey,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: List.generate(options.length, (i) {
            final selected = value == options[i];
            return GestureDetector(
              onTap: () => onChanged(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 8.h,
                ),
                decoration: BoxDecoration(
                  color: selected ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: selected ? _gold : Colors.grey.withAlpha(100),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontFamily: AppConsts.cairo,
                    color: selected ? Colors.white : Colors.grey,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
