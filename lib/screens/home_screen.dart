import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/theme/app_images.dart';

import 'package:flutter_svg/flutter_svg.dart'; // Import flutter_svg
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../services/prayer_service.dart';
import '../services/notification_service.dart';
import 'prayer_times_screen.dart';
import 'muslim_azkar_screen.dart';
import '../features/qiblah/qiblah_screen.dart';
import 'tasbeeh_screen.dart';
import 'accountability_screen.dart';
import 'hisn_muslim_screen.dart'; // Import Hisn Screen
import 'nawawi_screen.dart';
import 'ramadan_screen.dart';
import 'more_screen.dart'; // Import More Screen
import '../features/quran/ui/quran_screen.dart';
import 'ruqyah_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Default Home
  final PrayerService _prayerService = PrayerService();
  PrayerTimes? _prayerTimes;
  Prayer? _nextPrayer;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _startTimer();

    // Check battery permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.checkAndRequestBatteryPermission(context);

      // Listen for notification taps
      NotificationService.onNotificationTap.addListener(() {
        final payload = NotificationService.onNotificationTap.value;
        if (payload != null) {
          _handleNotificationTap(payload);
          // Clear it so we don't re-trigger on rebuilds if logical
          // NotificationService.onNotificationTap.value = null;
          // But ValueNotifier might act weird if we set null inside listener?
          // Better to just handle it.
        }
      });

      // Handle initial launch payload if any
      if (NotificationService.onNotificationTap.value != null) {
        _handleNotificationTap(NotificationService.onNotificationTap.value!);
      }
    });
  }

  void _handleNotificationTap(String payload) {
    if (!mounted) return;

    // 1. Prayer Times (Adhan)
    if (['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].contains(payload)) {
      setState(() => _currentIndex = 1); // Switch to Prayer Times Tab
      return;
    }

    // 2. Azkar
    if (payload == 'sabah' || payload == 'masaa') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MuslimAzkarScreen()),
      );
      return;
    }

    // 3. Wird (Quran)
    if (payload.startsWith('wird')) {
      int? page;
      try {
        final parts = payload.split(':');
        if (parts.length > 1) {
          page = int.tryParse(parts[1]);
        }
      } catch (_) {}

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuranScreen(initialPage: page)),
      );
      return;
    }

    // 4. Ruqyah
    if (payload == 'ruqyah') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RuqyahScreen()),
      );
      return;
    }
  }

  void _loadPrayerTimes() {
    setState(() {
      _prayerTimes = _prayerService.getPrayerTimes();
      _nextPrayer = _prayerTimes?.nextPrayer();
    });
  }

  Timer? _timer;
  Duration _timeUntilNext = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateCountdown();
        });
      }
    });
  }

  Future<void> _updateCountdown() async {
    if (_prayerTimes == null || _nextPrayer == null) return;

    // Check if next prayer is valid and in future
    DateTime? nextTime;
    if (_nextPrayer != Prayer.none) {
      nextTime = _prayerTimes!.timeForPrayer(_nextPrayer!);
    }

    final now = DateTime.now();

    // If nextTime is null or in the past (e.g. after Isha), we need tomorrow's Fajr
    if (nextTime == null || nextTime.isBefore(now)) {
      // Get tomorrow's Fajr
      // We can't easily get it from _prayerTimes (current day).
      // Let's use PrayerService to get tomorrow's data relative to now.
      // Or simply: if it's after Isha, next is Fajr tomorrow.

      // Quick fix: Get tomorrow's Fajr time
      // We assume tomorrow's Fajr is roughly 24h + today's Fajr (or re-fetch)
      // Best way:
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowService = await PrayerService().getPrayerTimesForDate(
        tomorrow,
      );
      if (tomorrowService != null) {
        nextTime = tomorrowService.fajr;
        // Update _nextPrayer to Fajr for display name
        if (mounted) {
          setState(() {
            _nextPrayer = Prayer.fajr;
          });
        }
      }
    }

    if (nextTime != null) {
      if (mounted) {
        setState(() {
          _timeUntilNext = nextTime!.difference(now);
        });
      }
    } else {
      // Fallback
      _loadPrayerTimes();
    }
  }

  // Header Widget (Circular Timer + Ramadan)
  Widget _buildHeader() {
    HijriCalendar.setLocal('ar');
    final now = DateTime.now();
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = now.add(Duration(days: hijriOffset));
    final hijri = HijriCalendar.fromDate(adjustedDate);
    final nextPrayerName = _nextPrayer != null
        ? _getPrayerName(_nextPrayer!)
        : "الفجر"; // Default fall back

    // Formatting Countdown
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final countdownStr =
        "${twoDigits(_timeUntilNext.inHours)}:${twoDigits(_timeUntilNext.inMinutes.remainder(60))}:${twoDigits(_timeUntilNext.inSeconds.remainder(60))}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 5),
      child: Column(
        children: [
          // Hijri Date Top
          Text(
            "${hijri.toFormat("dd MMMM yyyy")} | ${DateFormat("EEEE", 'ar').format(now)}",
            style: const TextStyle(
              color: Color(0xFFD0A871),
              fontSize: 11,
              fontFamily: AppConsts.cairo,
            ),
          ),
          const SizedBox(height: 4), // Reduced space
          // Circular Timer
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow/Shadow
              Container(
                width: 240, // Adjusted from 230
                height: 240, // Adjusted from 230
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              // Ring
              SizedBox(
                width: 205, // Adjusted from 200
                height: 205, // Adjusted from 200
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 10, // Slightly thicker
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFD0A871),
                  ),
                  backgroundColor: Colors.grey[900],
                ),
              ),
              // Inner Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "الصلاة القادمة",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontFamily: AppConsts.expoArabic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextPrayerName,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 28, // Same
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConsts.expoArabic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    countdownStr,
                    style: const TextStyle(
                      color: Color(0xFFD0A871),
                      fontSize: 30, // Reduced from 32
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
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

  String _getPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return "الفجر";
      case Prayer.sunrise:
        return "الشروق";
      case Prayer.dhuhr:
        return "الظهر";
      case Prayer.asr:
        return "العصر";
      case Prayer.maghrib:
        return "المغرب";
      case Prayer.isha:
        return "العشاء";
      case Prayer.none:
        return "الفجر";
    }
  }

  // Grid Button
  Widget _buildGridItem(
    String title,
    IconData icon,
    Widget page, {
    String? imagePath,
    double? customIconSize,
    double textOffset = 0.0,
  }) {
    final double iconSize = customIconSize ?? 60.w;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD0A871).withAlpha(80),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null)
              imagePath.endsWith('.svg')
                  ? SvgPicture.asset(
                      imagePath,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    )
                  : Image.asset(
                      imagePath,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    )
            else
              Icon(icon, size: 40.w, color: const Color(0xFFD0A871)),
            const SizedBox(height: 12),
            Transform.translate(
              offset: Offset(0, textOffset),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Screens for BottomNav
    final List<Widget> bottomScreens = [
      // 0: Home (Grid)
      Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Theme BG
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: Theme.of(context).brightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light, // iOS
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 18,
                    ),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: [
                        _buildGridItem(
                          "القرآن الكريم",
                          FontAwesomeIcons.bookQuran,
                          const QuranScreen(),
                          imagePath:
                              Theme.of(context).brightness == Brightness.dark
                              ? AppImages.sectionsQuranDark
                              : AppImages.sectionsQuranLight,
                          customIconSize: 75.w,
                          textOffset: -10.0,
                        ),
                        _buildGridItem(
                          "الأذكار",
                          FontAwesomeIcons.handsPraying,
                          const MuslimAzkarScreen(),
                          imagePath:
                              Theme.of(context).brightness == Brightness.dark
                              ? AppImages.sectionsAzkarDark
                              : AppImages.sectionsAzkarLight,
                        ),
                        _buildGridItem(
                          "حصن المسلم",
                          FontAwesomeIcons.shieldHalved,
                          const HisnMuslimScreen(),
                        ),
                        _buildGridItem(
                          "السبحة",
                          FontAwesomeIcons.stopwatch,
                          const TasbeehScreen(),
                          imagePath:
                              'assets/images/pngtree-luxury-islamic-prayer-beads-macro-png-image_18712828.webp',
                        ),

                        // Removed "القبلة"
                        _buildGridItem(
                          "حاسب نفسك",
                          FontAwesomeIcons.listCheck,
                          const AccountabilityScreen(),
                        ),

                        // Removed "الصيام"
                        _buildGridItem(
                          "الأربعين النووية",
                          FontAwesomeIcons.bookOpen,
                          const NawawiScreen(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // 1: Mawaqit (Prayer Times)
      const PrayerTimesScreen(),

      // 2: Qibla
      const QiblahScreen(),

      // 3: Ramadan
      const RamadanScreen(),

      // 4: More
      const MoreScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Theme BG
      body: bottomScreens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFD0A871), // Gold Background
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BottomNavigationBar(
            backgroundColor:
                Colors.transparent, // Transparent to show Container Gold
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.black, // Dark for contrast on Gold
            unselectedItemColor: Colors.white.withValues(
              alpha: 0.8,
            ), // White for unselected on Gold
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.normal,
            ),
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
                if (index == 0) _loadPrayerTimes();
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.house),
                label: "الرئيسية",
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.clock),
                label: "مواقيت",
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.compass),
                activeIcon: Icon(FontAwesomeIcons.solidCompass),
                label: "القبلة",
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.moon),
                activeIcon: Icon(FontAwesomeIcons.solidMoon),
                label: "رمضان",
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.ellipsis),
                label: "المزيد",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
