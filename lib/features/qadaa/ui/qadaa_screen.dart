import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:intl/intl.dart' as intl;

import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/screens/qada_list_screen.dart';
import 'fiqh_screen.dart';
import 'qadaa_settings_screen.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class QadaaScreen extends StatefulWidget {
  const QadaaScreen({super.key});

  @override
  State<QadaaScreen> createState() => _QadaaScreenState();
}

class _QadaaScreenState extends State<QadaaScreen> {
  static const goldColor = Color(0xFFD0A871);
  // Prayer missed counts
  int fajr = 0, dhuhr = 0, asr = 0, maghrib = 0, isha = 0;
  // Max counts for progress calculation
  int maxFajr = 0, maxDhuhr = 0, maxAsr = 0, maxMaghrib = 0, maxIsha = 0;
  // Fasting missed counts
  int fasting = 0;
  // Zakat due date
  DateTime? zakatDate;

  int _currentRamadanYear = 1445;

  @override
  void initState() {
    super.initState();
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = DateTime.now().add(Duration(days: hijriOffset));
    _currentRamadanYear = HijriCalendar.fromDate(adjustedDate).hYear;
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = CacheHelper.prefs;
    
    // Load Ramadan Qada Count (linked to Ramadan Screen)
    int missed = 0;
    for (int i = 1; i <= 30; i++) {
      if (prefs.getBool('qada_${_currentRamadanYear}_$i') ?? false) missed++;
    }

    setState(() {
      fajr = prefs.getInt('qadaa_fajr') ?? 0;
      dhuhr = prefs.getInt('qadaa_dhuhr') ?? 0;
      asr = prefs.getInt('qadaa_asr') ?? 0;
      maghrib = prefs.getInt('qadaa_maghrib') ?? 0;
      isha = prefs.getInt('qadaa_isha') ?? 0;

      // Load max counts, default to current counts if not found
      maxFajr = prefs.getInt('qadaa_max_fajr') ?? fajr;
      maxDhuhr = prefs.getInt('qadaa_max_dhuhr') ?? dhuhr;
      maxAsr = prefs.getInt('qadaa_max_asr') ?? asr;
      maxMaghrib = prefs.getInt('qadaa_max_maghrib') ?? maghrib;
      maxIsha = prefs.getInt('qadaa_max_isha') ?? isha;

      // Ensure max >= current
      if (maxFajr < fajr) maxFajr = fajr;
      if (maxDhuhr < dhuhr) maxDhuhr = dhuhr;
      if (maxAsr < asr) maxAsr = asr;
      if (maxMaghrib < maghrib) maxMaghrib = maghrib;
      if (maxIsha < isha) maxIsha = isha;

      fasting = missed; // Linked to Ramadan logic
      final dateStr = prefs.getString('qadaa_zakat_date');
      if (dateStr != null) {
        zakatDate = DateTime.tryParse(dateStr);
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt('qadaa_fajr', fajr);
    await prefs.setInt('qadaa_dhuhr', dhuhr);
    await prefs.setInt('qadaa_asr', asr);
    await prefs.setInt('qadaa_maghrib', maghrib);
    await prefs.setInt('qadaa_isha', isha);

    // Save max counts
    await prefs.setInt('qadaa_max_fajr', maxFajr);
    await prefs.setInt('qadaa_max_dhuhr', maxDhuhr);
    await prefs.setInt('qadaa_max_asr', maxAsr);
    await prefs.setInt('qadaa_max_maghrib', maxMaghrib);
    await prefs.setInt('qadaa_max_isha', maxIsha);

    if (zakatDate != null) {
      await prefs.setString('qadaa_zakat_date', zakatDate!.toIso8601String());
    } else {
      await prefs.remove('qadaa_zakat_date');
    }
  }

  Future<void> _updateFastingCount(bool increment) async {
    final prefs = CacheHelper.prefs;
    List<int> missedDays = [];
    for (int i = 1; i <= 30; i++) {
      if (prefs.getBool('qada_${_currentRamadanYear}_$i') ?? false) {
        missedDays.add(i);
      }
    }

    if (increment) {
      // Find first day that isn't missed
      for (int i = 1; i <= 30; i++) {
        if (!(prefs.getBool('qada_${_currentRamadanYear}_$i') ?? false)) {
          await prefs.setBool('qada_${_currentRamadanYear}_$i', true);
          break;
        }
      }
    } else {
      // Find last missed day and mark as done
      if (missedDays.isNotEmpty) {
        await prefs.setBool('qada_${_currentRamadanYear}_${missedDays.last}', false);
      }
    }
    _loadData();
  }

  int get totalMissedPrayers => fajr + dhuhr + asr + maghrib + isha;
  int get totalMaxPrayers => maxFajr + maxDhuhr + maxAsr + maxMaghrib + maxIsha;

  double get totalProgress {
    if (totalMaxPrayers == 0) return 1.0;
    return 1.0 - (totalMissedPrayers / totalMaxPrayers);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            "القضاء والزكاة",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Color(0xFFD0A871),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: goldColor),
          bottom: TabBar(
            indicatorColor: goldColor,
            labelColor: goldColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
            tabs: const [
              Tab(text: "حساب القضاء"),
              Tab(text: "فقه القضاء"),
              Tab(text: "الإعدادات"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildQadaaMainTab(isDark, goldColor),
            const FiqhScreen(),
            QadaaSettingsScreen(onSettingsChanged: _loadData),
          ],
        ),
      ),
    );
  }

  Widget _buildQadaaMainTab(bool isDark, Color goldColor) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Column(
        children: [
          _buildPrayerSection(isDark, goldColor),
          SizedBox(height: 20.h),
          _buildFastingSection(isDark, goldColor),
          if (zakatDate != null) ...[
            SizedBox(height: 20.h),
            _buildZakatSection(isDark, goldColor),
          ],
        ],
      ),
    );
  }

  Widget _buildPrayerSection(bool isDark, Color goldColor) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 80.w), // Spacer
              Text(
                "قضاء الصلاة",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
              InkWell(
                onTap: () => _showAddPeriodDialog(goldColor),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: goldColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: goldColor, width: 1),
                  ),
                  child: Text(
                    "إضافة فوائت",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 12.sp,
                      color: goldColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 15.h),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120.w,
                height: 120.w,
                child: CircularProgressIndicator(
                  value: 1.0, // Fixed bg
                  strokeWidth: 8,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              SizedBox(
                width: 120.w,
                height: 120.w,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: totalProgress),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOutCubic,
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      color: goldColor,
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalMissedPrayers.toString(),
                    style: TextStyle(
                      fontSize: 30.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    "إجمالي الفوائت",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPrayerCounter("الفجر", fajr, maxFajr, (v) => setState(() => fajr = v)),
                _buildPrayerCounter("الظهر", dhuhr, maxDhuhr, (v) => setState(() => dhuhr = v)),
                _buildPrayerCounter("العصر", asr, maxAsr, (v) => setState(() => asr = v)),
                _buildPrayerCounter("المغرب", maghrib, maxMaghrib, (v) => setState(() => maghrib = v)),
                _buildPrayerCounter("العشاء", isha, maxIsha, (v) => setState(() => isha = v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPeriodDialog(Color goldColor) {
    final TextEditingController controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedPeriod = 'أيام'; // 'أيام', 'شهور', 'سنين'

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              title: Text(
                "إضافة فوائت",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: goldColor,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "سيتم إضافة هذا العدد لكل الصلوات",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 12.sp,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  SizedBox(height: 15.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPeriodOption('سنين', selectedPeriod, goldColor, (val) => setStateDialog(() => selectedPeriod = val)),
                      SizedBox(width: 8.w),
                      _buildPeriodOption('شهور', selectedPeriod, goldColor, (val) => setStateDialog(() => selectedPeriod = val)),
                      SizedBox(width: 8.w),
                      _buildPeriodOption('أيام', selectedPeriod, goldColor, (val) => setStateDialog(() => selectedPeriod = val)),
                    ],
                  ),
                  SizedBox(height: 15.h),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "أدخل العدد",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: goldColor.withAlpha(100)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: goldColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final count = int.tryParse(controller.text) ?? 0;
                    if (count > 0) {
                      int multiplier = 1;
                      if (selectedPeriod == 'شهور') multiplier = 30;
                      if (selectedPeriod == 'سنين') multiplier = 365;
                      
                      final days = count * multiplier;
                      setState(() {
                        fajr += days;
                        dhuhr += days;
                        asr += days;
                        maghrib += days;
                        isha += days;
                        // Update max counts
                        if (fajr > maxFajr) maxFajr = fajr;
                        if (dhuhr > maxDhuhr) maxDhuhr = dhuhr;
                        if (asr > maxAsr) maxAsr = asr;
                        if (maghrib > maxMaghrib) maxMaghrib = maghrib;
                        if (isha > maxIsha) maxIsha = isha;
                      });
                      _saveData();
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                  child: const Text("إضافة", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildPeriodOption(String title, String selected, Color goldColor, Function(String) onTap) {
    final isSelected = title == selected;
    return GestureDetector(
      onTap: () => onTap(title),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? goldColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: goldColor),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : goldColor,
            fontFamily: AppConsts.expoArabic,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerCounter(String name, int count, int max, Function(int) onUpdate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double progress = (max == 0) ? 1.0 : (1.0 - (count / max));

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 14.sp,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8.h),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50.w,
                height: 50.w,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 3,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              SizedBox(
                width: 50.w,
                height: 50.w,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      color: const Color(0xFFD0A871),
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
              ),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  onUpdate(count + 1);
                  // If we manually add, we should probably update max to avoid confusing progress
                  setState(() {
                    if (name == "الفجر" && fajr > maxFajr) maxFajr = fajr;
                    if (name == "الظهر" && dhuhr > maxDhuhr) maxDhuhr = dhuhr;
                    if (name == "العصر" && asr > maxAsr) maxAsr = asr;
                    if (name == "المغرب" && maghrib > maxMaghrib) maxMaghrib = maghrib;
                    if (name == "العشاء" && isha > maxIsha) maxIsha = isha;
                  });
                  _saveData();
                },
                borderRadius: BorderRadius.circular(20),
                child: Icon(Icons.add_circle, color: const Color(0xFFD0A871), size: 28.w),
              ),
              SizedBox(width: 4.w),
              InkWell(
                onTap: () {
                  if (count > 0) {
                    onUpdate(count - 1);
                    _saveData();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Icon(Icons.check_circle, color: Colors.green, size: 28.w),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFastingSection(bool isDark, Color goldColor) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            "قضاء الصيام",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: goldColor,
            ),
          ),
          SizedBox(height: 15.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QadaListScreen()),
                  );
                  _loadData();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80.w,
                      height: 80.w,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 6,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    SizedBox(
                      width: 80.w,
                      height: 80.w,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: fasting > 0 ? (fasting / 30) : 0.0),
                        duration: const Duration(milliseconds: 1200),
                        builder: (context, value, child) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            color: goldColor,
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                    ),
                    Text(
                      fasting.toString(),
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  InkWell(
                    onTap: () => _updateFastingCount(true),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: goldColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: goldColor),
                      ),
                      child: Text(
                        "إضافة فوت",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: goldColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  InkWell(
                    onTap: () => _updateFastingCount(false),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        "قضاء",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            "اضغط على العداد لعرض تفاصيل أيام رمضان",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 10.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZakatSection(bool isDark, Color goldColor) {
    int daysLeft = 0;
    DateTime? displayDate = zakatDate;

    if (displayDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Calculate next occurrence based on Hijri year (approx 354 days)
      final hDate = HijriCalendar.fromDate(displayDate);
      final currentH = HijriCalendar.now();
      
      // Find the next occurrence of this Hijri day/month
      var targetHYear = currentH.hYear;
      DateTime target;
      
      try {
        target = HijriCalendar().hijriToGregorian(targetHYear, hDate.hMonth, hDate.hDay);
      } catch (_) {
        // Handle case where day 30 doesn't exist in that Hijri month
        target = HijriCalendar().hijriToGregorian(targetHYear, hDate.hMonth, 29);
      }

      if (target.isBefore(today)) {
        targetHYear++;
        try {
          target = HijriCalendar().hijriToGregorian(targetHYear, hDate.hMonth, hDate.hDay);
        } catch (_) {
          target = HijriCalendar().hijriToGregorian(targetHYear, hDate.hMonth, 29);
        }
      }
      
      daysLeft = target.difference(today).inDays;
      displayDate = target;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            "تذكير الزكاة",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: goldColor,
            ),
          ),
          SizedBox(height: 15.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90.w,
                    height: 90.w,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 7,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  SizedBox(
                    width: 90.w,
                    height: 90.w,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: (daysLeft > 0 && daysLeft <= 365) ? (daysLeft / 355) : 0.0), // Use 355 for Hijri scale
                      duration: const Duration(milliseconds: 1200),
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 7,
                          color: goldColor,
                          strokeCap: StrokeCap.round,
                        );
                      },
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        daysLeft.toString(),
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        "يوم متبقي",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 10.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                children: [
                  if (displayDate != null)
                    Text(
                      "موعد الزكاة:\n${intl.DateFormat('yyyy/MM/dd').format(displayDate)}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 12.sp,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  SizedBox(height: 10.h),
                  InkWell(
                    onTap: () => _showZakatDatePicker(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: goldColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        zakatDate == null ? "تحديد الموعد" : "تعديل الموعد",
                        style: const TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
                initialDate: zakatDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
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
                setState(() {
                  zakatDate = picked;
                });
                _saveData();
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
    final List<String> hijriMonths = [
      "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
      "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
    ];

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
                  setState(() {
                    zakatDate = greg;
                  });
                  _saveData();
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
}
