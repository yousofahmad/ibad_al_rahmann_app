import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'hisn_muslim_screen.dart'; // Import Hisn Screen
import 'nawawi_screen.dart';
import 'ramadan_screen.dart';
import 'widgets/prayer_ring_widget.dart';
import 'more_screen.dart'; // Import More Screen
import 'accountability_screen.dart';
import '../features/qadaa/ui/qadaa_screen.dart';
import 'time_for_allah_screen.dart';
import '../features/quran/ui/quran_screen.dart';
import '../features/wird/ui/wird_dashboard_screen.dart';
import '../features/wird/ui/isolated_wird_screen.dart';
import '../features/wird/bloc/khatma_cubit.dart';
import '../services/daily_tracker_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  final PrayerService _prayerService = PrayerService();
  PrayerTimes? _prayerTimes;
  Prayer? _nextPrayer;
  Prayer? _currentPrayer;
  bool _isCountUp = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _prayerService.init().then((_) {
        if (mounted) {
          _loadPrayerTimes();
          _updateCountdown();
          _checkDailyTasks();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // Add listener to prayer service to handle cases where it initializes late
    _prayerService.addListener(_loadPrayerTimes);
    
    _loadPrayerTimes();
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small delay to ensure UI is stable
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        NotificationService.checkAndRequestBatteryPermission(context);
      }
    });

    _checkDailyTasks();
  }

  bool _isMorningAzkarDone = false;
  bool _isEveningAzkarDone = false;
  bool _isMorningAzkarStarted = false;
  bool _isEveningAzkarStarted = false;
  bool _isKahfDone = false;
  int? _kahfProgressPage;

  void _checkDailyTasks() async {
    final mDone = await DailyTrackerService.isDone('morning_azkar');
    final eDone = await DailyTrackerService.isDone('evening_azkar');
    final mStarted = await DailyTrackerService.isStarted('morning_azkar');
    final eStarted = await DailyTrackerService.isStarted('evening_azkar');
    final kDone = await DailyTrackerService.isKahfDone();
    final kProgress = await DailyTrackerService.getKahfProgress();

    if (mounted) {
      setState(() {
        _isMorningAzkarDone = mDone;
        _isEveningAzkarDone = eDone;
        _isMorningAzkarStarted = mStarted;
        _isEveningAzkarStarted = eStarted;
        _isKahfDone = kDone;
        _kahfProgressPage = kProgress;
      });
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
  double _progressValue = 1.0;

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
    if (_currentPrayer == Prayer.sunrise) _currentPrayer = Prayer.fajr;

    _nextPrayer = _prayerTimes!.nextPrayer();
    if (_nextPrayer == Prayer.sunrise) _nextPrayer = Prayer.dhuhr;

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

    // 2. 45-Minute Rule (and general interval start)
    DateTime? currentTime;
    if (_currentPrayer != Prayer.none) {
      currentTime = _prayerTimes!.timeForPrayer(_currentPrayer!);
    } else {
      // If before Fajr, previous was yesterday's Isha
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayTimes = _prayerService.getPrayerTimesForDate(yesterday);
      currentTime = yesterdayTimes?.isha;
    }

    // Calculate progress (Gold = remaining time)
    if (currentTime != null && nextTime != null) {
      final total = nextTime.difference(currentTime).inSeconds;
      final remaining = nextTime.difference(now).inSeconds;
      if (total > 0) {
        setState(() {
          _progressValue = (remaining / total).clamp(0.0, 1.0);
        });
      }
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
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 10.h, top: 5.h),
      child: Column(
        children: [
          Text(
            "${hijri.toFormat("dd MMMM yyyy")} | ${DateFormat("EEEE", 'ar').format(now)}",
            style: TextStyle(
              color: const Color(0xFFD0A871),
              fontSize: 11.sp,
              fontFamily: AppConsts.cairo,
            ),
          ),
          SizedBox(height: 4.h),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240.w,
                height: 240.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                      blurRadius: 20.r,
                      spreadRadius: 5.r,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 205.w,
                height: 205.w,
                child: PrayerRingWidget(
                  percent: _progressValue,
                  color: const Color(0xFFD0A871),
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isCountUp ? "مضى على" : "الصلاة القادمة",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.sp,
                      fontFamily: AppConsts.expoArabic,
                    ),
                  ),
                  SizedBox(height: 8.h),
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
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConsts.expoArabic,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    countdownStr,
                    style: TextStyle(
                      color: const Color(0xFFD0A871),
                      fontSize: 30.sp,
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
    bool hideTitle = false,
  }) {
    final double iconSize = customIconSize ?? 60.w;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: const Color(0xFFD0A871).withValues(alpha: 0.5),
            width: 1.0.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
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
                      width: hideTitle ? 100.w : iconSize,
                      height: hideTitle ? 100.w : iconSize,
                      fit: BoxFit.contain,
                    )
            else
              Icon(icon, size: 40.w, color: const Color(0xFFD0A871)),
            if (!hideTitle) ...[
              SizedBox(height: 12.h),
              Transform.translate(
                offset: Offset(0, textOffset.h),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
            ],
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
            final delayedWirds = context.read<KhatmaCubit>().getDaysLate(
              khatma.id,
            );
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
                          isWirdMode: true,
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
            } else if (delayedWirds == 0) {
              final target = context.read<KhatmaCubit>().getCurrentTargetWird(
                khatma.id,
              );
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
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
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
              if (_prayerService.isKahfTime() && !_isKahfDone)
                _buildReminderCard(
                  _kahfProgressPage != null && _kahfProgressPage! > 0
                      ? "أكمل قراءة سورة الكهف"
                      : "اقرأ سورة الكهف لنيل النور بين الجمعتين",
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IsolatedWirdScreen(
                          isKahfMode: true,
                          targetStartPage: 293,
                          targetEndPage: 304,
                        ),
                      ),
                    ).then((_) => _checkDailyTasks());
                  },
                  isDelayed: false,
                ),

              ...inProgressWirdCards,

              if (showMorningInProgress)
                _buildReminderCard(
                  _isMorningAzkarStarted ? "أكمل أذكار الصباح" : "اقرأ أذكار الصباح",
                  () {
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
                  },
                  isDelayed: false,
                ),

              if (showEveningInProgress)
                _buildReminderCard(
                  _isEveningAzkarStarted ? "أكمل أذكار المساء" : "اقرأ أذكار المساء",
                  () {
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
                  },
                  isDelayed: false,
                ),
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
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: borderColor, width: 1.5.w),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Icon(
                    isDelayed
                        ? FontAwesomeIcons.circleExclamation
                        : FontAwesomeIcons.clockRotateLeft,
                    color: themeColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: themeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.arrow_forward_ios, color: themeColor, size: 16.sp),
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
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.dark
              : Brightness.light,
        ),
        // ── Use a plain Column so content fills ALL the way to the top
        // edge of the screen (under the status bar). We manually add
        // padding equal to the status-bar height so nothing is hidden.
        child: CustomScrollView(
          slivers: [
            // Status-bar spacer
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top),
            ),
            // Reminder cards (Alerts)
            SliverToBoxAdapter(child: _buildReminderCards()),
            // Header (Countdown)
            SliverToBoxAdapter(child: _buildHeader()),
            // Grid items
            SliverPadding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 18.h),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16.w,
                mainAxisSpacing: 16.h,
                childAspectRatio: 1.3,
                children: [
                  _buildGridItem(
                    "القرآن الكريم",
                    FontAwesomeIcons.bookQuran,
                    const QuranScreen(),
                    imagePath: Theme.of(context).brightness == Brightness.dark
                        ? AppImages.sectionsQuranDark
                        : AppImages.sectionsQuranLight,
                    customIconSize: 75.w,
                    textOffset: -10.0,
                  ),
                  _buildGridItem(
                    "الأذكار",
                    FontAwesomeIcons.handsPraying,
                    const MuslimAzkarScreen(),
                    imagePath: Theme.of(context).brightness == Brightness.dark
                        ? AppImages.sectionsAzkarDark
                        : AppImages.sectionsAzkarLight,
                  ),
                  _buildGridItem(
                    "حاسب نفسك",
                    FontAwesomeIcons.clipboardCheck,
                    const AccountabilityScreen(),
                    imagePath: "assets/images/accountability_card.png",
                  ),
                  _buildGridItem(
                    "السبحة",
                    Icons.radio_button_checked_rounded,
                    const TasbeehScreen(),
                    imagePath: "assets/images/pngtree-luxury-islamic-prayer-beads-macro-png-image_18712828.webp",
                  ),
                  _buildGridItem(
                    "القضاء",
                    Icons.history_rounded,
                    const QadaaScreen(),
                    imagePath: "assets/images/qadaa_card.png",
                    hideTitle: true,
                  ),
                  _buildGridItem(
                    "وقت لله",
                    Icons.hourglass_bottom_rounded,
                    const TimeForAllahScreen(),
                    imagePath: "assets/images/time_for_allah_card.png",
                  ),
                  _buildGridItem(
                    "حصن المسلم",
                    FontAwesomeIcons.shieldHalved,
                    const HisnMuslimScreen(),
                    imagePath: "assets/images/hisn_muslim_card.png",
                    hideTitle: true,
                  ),
                  _buildGridItem(
                    "الأربعين النووية",
                    FontAwesomeIcons.bookOpenReader,
                    const NawawiScreen(),
                    imagePath: "assets/images/nawawi_card.png",
                    hideTitle: true,
                  ),
                ],
              ),
            ),
          ],
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
      // Wrap the body or use Scaffold properties carefully to avoid layout errors
      body: bottomScreens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFD0A871),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20.r,
              offset: Offset(0, -5.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.white.withValues(alpha: 0.8),
            selectedFontSize: 12.sp,
            unselectedFontSize: 12.sp,
            selectedLabelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.normal,
              fontSize: 12.sp,
            ),
            currentIndex: _currentIndex,
            onTap: (index) async {
              setState(() {
                _currentIndex = index;
                if (index == 0) _loadPrayerTimes();
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('last_home_tab_index', index);
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
