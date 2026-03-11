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
import 'azkar_page.dart';
import '../features/qiblah/qiblah_screen.dart';
import 'tasbeeh_screen.dart';
import 'accountability_screen.dart';
import 'hisn_muslim_screen.dart'; // Import Hisn Screen
import 'nawawi_screen.dart';
import 'ramadan_screen.dart';
import 'more_screen.dart'; // Import More Screen
import '../features/quran/ui/quran_screen.dart';
import '../features/wird/ui/wird_dashboard_screen.dart';
import '../features/wird/ui/isolated_wird_screen.dart';
import '../features/wird/bloc/khatma_cubit.dart';
import '../services/daily_tracker_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  Prayer? _currentPrayer;
  bool _isCountUp = false;

  @override
  void initState() {
    super.initState();
    // Lock home screen to portrait — only Mushaf/Wird screens allow landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
        }
      });

      // Handle initial launch payload if any
      if (NotificationService.onNotificationTap.value != null) {
        _handleNotificationTap(NotificationService.onNotificationTap.value!);
      }
    });

    _checkDailyTasks();
  }

  bool _isMorningAzkarDone = false;
  bool _isEveningAzkarDone = false;

  void _checkDailyTasks() async {
    final mDone = await DailyTrackerService.isDone('morning_azkar');
    final eDone = await DailyTrackerService.isDone('evening_azkar');

    if (mounted) {
      setState(() {
        _isMorningAzkarDone = mDone;
        _isEveningAzkarDone = eDone;
      });
    }
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

    // 3. Wird (Quran) — open the reading screen directly
    if (payload.startsWith('wird')) {
      _openCurrentWird();
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

  void _openCurrentWird() {
    if (!mounted) return;
    final khatmaCubit = context.read<KhatmaCubit>();
    final khatma = khatmaCubit.getActiveKhatma();

    if (khatma != null) {
      final currentIndex = khatma.currentWirdIndex;
      if (currentIndex < khatma.wirds.length) {
        final currentWird = khatma.wirds[currentIndex];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IsolatedWirdScreen(
              khatmaId: khatma.id,
              wirdIndex: currentIndex,
              targetStartPage: currentWird.startPage,
              targetEndPage: currentWird.endPage,
            ),
          ),
        );
        return;
      }
    }

    // Fallback: no active khatma or completed — open dashboard
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WirdDashboardScreen()),
    );
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
        _updateCountdown();
      }
    });

    // Check daily tasks every 5 minutes instead of every second
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _checkDailyTasks();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _updateCountdown() async {
    if (_prayerTimes == null) return;

    final now = DateTime.now();

    // 1. Determine Current and Next
    _currentPrayer = _prayerTimes!.currentPrayer();
    _nextPrayer = _prayerTimes!.nextPrayer();

    DateTime? nextTime;
    if (_nextPrayer != Prayer.none) {
      nextTime = _prayerTimes!.timeForPrayer(_nextPrayer!);
    } else {
      // It's after Isha
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowTimes = _prayerService.getPrayerTimesForDate(tomorrow);
      nextTime = tomorrowTimes?.fajr;
      _nextPrayer = Prayer.fajr;
    }

    // 2. 45-Minute Rule
    DateTime? currentTime;
    if (_currentPrayer != Prayer.none) {
      currentTime = _prayerTimes!.timeForPrayer(_currentPrayer!);
    } else {
      // If before Fajr, previous was yesterday's Isha
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayTimes = _prayerService.getPrayerTimesForDate(yesterday);
      currentTime = yesterdayTimes?.isha;
    }

    _isCountUp = false;
    if (currentTime != null) {
      final elapsed = now.difference(currentTime);
      if (elapsed.inMinutes >= 0 && elapsed.inMinutes < 45) {
        _isCountUp = true;
        if (mounted) {
          setState(() {
            _timeUntilNext = elapsed;
          });
        }
        return;
      }
    }

    // 3. Standard Countdown
    if (nextTime != null) {
      if (mounted) {
        setState(() {
          _timeUntilNext = nextTime!.difference(now);
        });
      }
    } else {
      _loadPrayerTimes();
    }
  }

  Widget _buildHeader() {
    HijriCalendar.setLocal('ar');
    final now = DateTime.now();
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = now.add(Duration(days: hijriOffset));
    final hijri = HijriCalendar.fromDate(adjustedDate);
    final nextPrayerName = _nextPrayer != null
        ? _getPrayerName(_nextPrayer!)
        : "الفجر";

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final countdownStr =
        "${twoDigits(_timeUntilNext.inHours)}:${twoDigits(_timeUntilNext.inMinutes.remainder(60))}:${twoDigits(_timeUntilNext.inSeconds.remainder(60))}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 5),
      child: Column(
        children: [
          Text(
            "${hijri.toFormat("dd MMMM yyyy")} | ${DateFormat("EEEE", 'ar').format(now)}",
            style: const TextStyle(
              color: Color(0xFFD0A871),
              fontSize: 11,
              fontFamily: AppConsts.cairo,
            ),
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
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
              SizedBox(
                width: 205,
                height: 205,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFD0A871),
                  ),
                  backgroundColor: Colors.grey[900],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isCountUp ? "مضى على" : "الصلاة القادمة",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontFamily: AppConsts.expoArabic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCountUp
                        ? _getPrayerName(
                            _currentPrayer == Prayer.none ||
                                    _currentPrayer == null
                                ? Prayer.isha
                                : _currentPrayer!,
                          )
                        : nextPrayerName,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConsts.expoArabic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    countdownStr,
                    style: const TextStyle(
                      color: Color(0xFFD0A871),
                      fontSize: 30,
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

  Widget _buildReminderCards() {
    return BlocBuilder<KhatmaCubit, KhatmaState>(
      builder: (context, state) {
        final times = _prayerService.getPrayerTimes();
        final now = DateTime.now();

        // ─── أذكار الصباح ───
        // عادي (ذهبي): الفجر → الظهر
        // متأخر (أحمر): الظهر → العصر
        bool showMorningDelayed = false;
        bool showMorningInProgress = false;
        if (times != null && !_isMorningAzkarDone) {
          if (now.isAfter(times.fajr) && now.isBefore(times.dhuhr)) {
            // وقت عادي: الفجر للظهر
            showMorningInProgress = true;
          } else if (now.isAfter(times.dhuhr) && now.isBefore(times.asr)) {
            // متأخر: الظهر للعصر
            showMorningDelayed = true;
          }
        }

        // ─── أذكار المساء ───
        // عادي (ذهبي): العصر → المغرب
        // متأخر (أحمر): المغرب → الفجر
        bool showEveningDelayed = false;
        bool showEveningInProgress = false;
        if (times != null && !_isEveningAzkarDone) {
          if (now.isAfter(times.asr) && now.isBefore(times.maghrib)) {
            // وقت عادي: العصر للمغرب
            showEveningInProgress = true;
          } else if (now.isAfter(times.maghrib) || now.isBefore(times.fajr)) {
            // متأخر: بعد المغرب أو قبل الفجر
            showEveningDelayed = true;
          }
        }

        // ─── الورد القرآني ───
        List<Widget> lateWirdCards = [];
        List<Widget> inProgressWirdCards = [];

        if (state is KhatmaLoaded) {
          for (final khatma in state.khatmas) {
            final delayedWirds = context.read<KhatmaCubit>().getDaysLate(khatma.id);
            if (delayedWirds > 0) {
              lateWirdCards.add(
                _buildReminderCard(
                  "لديك تأخير في ${khatma.name} بمقدار $delayedWirds ورد",
                  () {
                    final w = khatma.wirds[khatma.currentWirdIndex];
                    final cubit = context.read<KhatmaCubit>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IsolatedWirdScreen(
                          khatmaId: khatma.id,
                          wirdIndex: khatma.currentWirdIndex,
                          targetStartPage: w.startPage,
                          targetEndPage: w.endPage,
                        ),
                      ),
                    ).then((_) {
                      if (!mounted) return;
                      _checkDailyTasks();
                      cubit.loadKhatma();
                    });
                  },
                  isDelayed: true,
                ),
              );
            } else {
              final target = context.read<KhatmaCubit>().getCurrentTargetWird(khatma.id);
              if (target != null && !target.isCompleted) {
                inProgressWirdCards.add(
                  _buildReminderCard(
                    "أكمل قراءة الورد الحالي: ${khatma.name}",
                    () {
                      final w = khatma.wirds[khatma.currentWirdIndex];
                      final cubit = context.read<KhatmaCubit>();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IsolatedWirdScreen(
                            khatmaId: khatma.id,
                            wirdIndex: khatma.currentWirdIndex,
                            targetStartPage: w.startPage,
                            targetEndPage: w.endPage,
                          ),
                        ),
                      ).then((_) {
                        if (!mounted) return;
                        _checkDailyTasks();
                        cubit.loadKhatma();
                      });
                    },
                    isDelayed: false,
                  ),
                );
              }
            }
          }
        }

        if (!showMorningDelayed &&
            !showMorningInProgress &&
            !showEveningDelayed &&
            !showEveningInProgress &&
            lateWirdCards.isEmpty &&
            inProgressWirdCards.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // 🔴 المتأخر يطلع الأول باللون الأحمر 🔴
              ...lateWirdCards,

              if (showMorningDelayed)
                _buildReminderCard("أذكار الصباح فات وقتها المفضل!", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AzkarPage(
                        title: "أذكار الصباح",
                        jsonFile: "morning.json",
                        image: "assets/images/morning.jpg",
                      ),
                    ),
                  ).then((_) => _checkDailyTasks());
                }, isDelayed: true),

              if (showEveningDelayed)
                _buildReminderCard("أذكار المساء فات وقتها المفضل!", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AzkarPage(
                        title: "أذكار المساء",
                        jsonFile: "evening.json",
                        image: "assets/images/night.jpg",
                      ),
                    ),
                  ).then((_) => _checkDailyTasks());
                }, isDelayed: true),

              // 🟡 الجاري تنفيذه باللون الذهبي 🟡
              ...inProgressWirdCards,

              if (showMorningInProgress)
                _buildReminderCard("أكمل أذكار الصباح", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AzkarPage(
                        title: "أذكار الصباح",
                        jsonFile: "morning.json",
                        image: "assets/images/morning.jpg",
                      ),
                    ),
                  ).then((_) => _checkDailyTasks());
                }, isDelayed: false),

              if (showEveningInProgress)
                _buildReminderCard("أكمل أذكار المساء", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AzkarPage(
                        title: "أذكار المساء",
                        jsonFile: "evening.json",
                        image: "assets/images/night.jpg",
                      ),
                    ),
                  ).then((_) => _checkDailyTasks());
                }, isDelayed: false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminderCard(
    String title,
    VoidCallback onTap, {
    bool isDelayed = true,
  }) {
    const goldColor = Color(0xFFD0A871);
    final themeColor = isDelayed ? Colors.redAccent : goldColor;
    final bgColor = isDelayed
        ? Colors.red.withValues(alpha: 0.15)
        : goldColor.withValues(alpha: 0.15);
    final borderColor = isDelayed
        ? Colors.red.withValues(alpha: 0.5)
        : goldColor.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isDelayed
                      ? FontAwesomeIcons.circleExclamation
                      : FontAwesomeIcons.clockRotateLeft,
                  color: themeColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppConsts.cairo,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios, color: themeColor, size: 16),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: Theme.of(context).brightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildReminderCards(),
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
                        _buildGridItem(
                          "حاسب نفسك",
                          FontAwesomeIcons.listCheck,
                          const AccountabilityScreen(),
                        ),
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

      // 2: Wird Dashboard
      const WirdDashboardScreen(),

      // 3: Qibla
      const QiblahScreen(),

      // 4: Ramadan
      const RamadanScreen(),

      // 5: More
      const MoreScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: bottomScreens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFD0A871),
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.white.withValues(alpha: 0.8),
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
                icon: Icon(FontAwesomeIcons.bookOpen),
                label: "الورد اليومي",
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
