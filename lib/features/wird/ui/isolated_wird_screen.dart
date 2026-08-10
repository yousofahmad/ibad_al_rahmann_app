import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart'; // For Ticker
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/single_tap_menu.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/core/wbw_page_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

/// A completely isolated screen for reading the Daily Wird or Surah Al-Kahf.
/// It creates its own QuranCubit with a localized state to avoid interfering
/// with the main Mushaf's current page or layout.
class IsolatedWirdScreen extends StatefulWidget {
  final bool isWirdMode;
  final bool isKahfMode;
  final String? khatmaId;
  final int targetStartPage;
  final int targetEndPage;
  final int? wirdIndex;

  const IsolatedWirdScreen({
    super.key,
    this.isWirdMode = false,
    this.isKahfMode = false,
    this.khatmaId,
    this.targetStartPage = 1,
    this.targetEndPage = 604,
    this.wirdIndex,
  });

  @override
  State<IsolatedWirdScreen> createState() => _IsolatedWirdScreenState();
}

class _IsolatedWirdScreenState extends State<IsolatedWirdScreen> with TickerProviderStateMixin {
  late QuranCubit _localQuranCubit;
  late PageController _pageController;
  late ScrollController _scrollController;
  int _currentIndex = 0;
  late int _itemCount;
  bool _showOverlays = true;
  bool _showMenu = false;
  bool _hasInitializedWirdPage = false;

  // Auto-scroll logic
  Ticker? _ticker;
  double _lastWidth = 0;

  @override
  void initState() {
    super.initState();
    // Enable wakelock to prevent screen from turning off while reading
    WakelockPlus.enable();
    
    // Hide status bar for immersive reading
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _itemCount = widget.targetEndPage - widget.targetStartPage + 1;
    _localQuranCubit = QuranCubit(
      QuranRepo(tablet: true),
      isWirdMode: widget.isWirdMode,
      isKahfMode: widget.isKahfMode,
      khatmaId: widget.khatmaId,
      wirdStartPage: widget.targetStartPage,
      targetEndPage: widget.targetEndPage,
      wirdIndex: widget.wirdIndex,
    );
    _pageController = PageController();
    _scrollController = ScrollController();
    
    _startTimer();
  }

  Future<void> _checkFirstTime(BuildContext context) async {
    final prefs = CacheHelper.prefs;
    final bool seen = prefs.getBool('seen_wird_instructions') ?? false;
    if (!seen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          IntroService.showQuranIntro(context);
        }
        prefs.setBool('seen_wird_instructions', true);
      });
    }
  }

  void _showInstructions(BuildContext context) {
    IntroService.showQuranIntro(context);
  }

  @override
  void dispose() {
    // Restore status bar
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    _ticker?.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _localQuranCubit.close();
    super.dispose();
  }

  void _startTimer() {
    _ticker?.dispose();
    _ticker = createTicker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final quranState = _localQuranCubit.state;
    if (!quranState.isAutoScrolling || quranState.isAutoScrollPaused) return;

    if (_scrollController.hasClients) {
      final double pixelsPerSec = quranState.autoScrollSpeed * 40;
      final double delta = pixelsPerSec / 60.0; // 60 FPS
      _scrollController.jumpTo(_scrollController.offset + delta);

      // Check if we swiped to next page based on scroll offset
      final expectedHeight = _getPageHeight(context);
      final int newIdx = (_scrollController.offset / expectedHeight).floor();
      if (newIdx != _currentIndex && newIdx < _itemCount) {
        setState(() {
          _currentIndex = newIdx;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(newIdx);
          }
        });
      }
    }
  }

  double _getPageHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    return isLandscape ? size.width * 1.66 : size.width * 1.85;
  }

  void _onFinishWird() async {
    if (widget.isKahfMode) {
      await DailyTrackerService.markKahfDone();
    } else if (widget.isWirdMode && widget.khatmaId != null && widget.wirdIndex != null) {
      context.read<KhatmaCubit>().markWirdAsCompleted(widget.khatmaId!, widget.wirdIndex!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "تم إتمام القراءة بنجاح، تقبل الله منا ومنكم صالح الأعمال.",
          style: TextStyle(fontFamily: AppConsts.cairo, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
      ),
    );
    Navigator.of(context).pop();
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
      // We no longer toggle _showOverlays here based on user request.
      // Single tap only opens/closes the menu.
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<QuranCubit>.value(value: _localQuranCubit),
        BlocProvider<VersePlayerCubit>(create: (_) => VersePlayerCubit()),
        BlocProvider<QuranThemeCubit>(create: (_) => QuranThemeCubit()),
        BlocProvider<ThemeCubit>(create: (c) => c.read<QuranThemeCubit>()),
      ],
      child: BlocListener<QuranCubit, QuranState>(
        listener: (context, state) {
          if (!_hasInitializedWirdPage && state.currentPage != null) {
            _hasInitializedWirdPage = true;
            final int relative = (state.currentPage! - (widget.targetStartPage - 1)).clamp(0, _itemCount - 1);
            _currentIndex = relative;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(relative);
            }
          }
        },
        child: Builder(
          builder: (context) {
            final quranState = context.watch<QuranCubit>().state;
            final paperColorState = quranState.isKahfMode ? quranState.kahfPaperColor : quranState.wirdPaperColor;
            final bgColor = paperColorState ?? Colors.white;
            final isActuallyDark = bgColor.computeLuminance() < 0.4;
            final appThemeState = context.watch<QuranThemeCubit>().state;
            final themeData = isActuallyDark
                ? appThemeState.theme.dark
                : appThemeState.theme.light;

            final isAutoScrolling = quranState.isAutoScrolling;

            final currentWidth = MediaQuery.of(context).size.width;
            if (_lastWidth != 0 && _lastWidth != currentWidth && isAutoScrolling) {
              final expectedHeight = _getPageHeight(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(_currentIndex * expectedHeight);
                }
              });
            }
            _lastWidth = currentWidth;

            return Theme(
              data: themeData,
              child: Builder(
                builder: (context) {
                  // Get the bar color directly from the BLoC for absolute consistency with the Mushaf
                  final quranTheme = context.watch<QuranThemeCubit>().state.theme;
                  final Color barColor = quranTheme.light.primaryColor;
                  
                  // Determine onBar color based on barColor brightness, same as PageActionBar
                  final Color onBar = ThemeData.estimateBrightnessForColor(barColor) == Brightness.dark
                      ? Colors.white
                      : Colors.black87;


                  String khatmaName = widget.isKahfMode ? "سورة الكهف" : "مصحف الورد";
                  final khatmaState = context.read<KhatmaCubit>().state;
                  if (khatmaState is KhatmaLoaded && !widget.isKahfMode) {
                    final khatma =
                        khatmaState.khatmas.where((k) => k.id == widget.khatmaId).firstOrNull;
                    if (khatma != null) khatmaName = khatma.name;
                  }

                  // Show instructions for first-time users using correct theme context
                  _checkFirstTime(context);

                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: isActuallyDark ? Brightness.light : Brightness.dark,
                    ),
                    child: Scaffold(
                      backgroundColor: bgColor,
                      body: SafeArea(
                        top: false,
                        bottom: false,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                // ── Top Bar ──
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  height: (_showOverlays && !isAutoScrolling)
                                      ? MediaQuery.of(context).padding.top + 60.h
                                      : 0,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: (_showOverlays && !isAutoScrolling) ? 1.0 : 0.0,
                                    child: SingleChildScrollView(
                                      physics: const NeverScrollableScrollPhysics(),
                                      child: Container(
                                        padding: EdgeInsets.only(
                                          top: MediaQuery.of(context).padding.top,
                                          left: 12,
                                          right: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: barColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(40),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: SizedBox(
                                          height: 60.h,
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.arrow_back_ios_rounded,
                                                  color: onBar,
                                                ),
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      khatmaName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily: AppConsts.expoArabic,
                                                        fontSize: 14.sp,
                                                        fontWeight: FontWeight.bold,
                                                        color: onBar,
                                                      ),
                                                    ),
                                                    Text(
                                                      "من صـ ${widget.targetStartPage.toArabicNums} إلى ${widget.targetEndPage.toArabicNums}",
                                                      style: TextStyle(
                                                        fontFamily: AppConsts.cairo,
                                                        fontSize: 10.sp,
                                                        color: onBar.withAlpha(180),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.info_outline_rounded, color: onBar),
                                                onPressed: () => _showInstructions(context),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.palette_outlined, color: onBar),
                                                onPressed: () => PageActionBar.showColorPalette(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // ── Main Content ──
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _toggleMenu,
                                    onDoubleTap: () {
                                      setState(() => _showOverlays = !_showOverlays);
                                    },
                                    child: PageView.builder(
      allowImplicitScrolling: true,
                                      controller: _pageController,
                                      itemCount: _itemCount,
                                      reverse: false,
                                      onPageChanged: (idx) {
                                        setState(() => _currentIndex = idx);
                                        _localQuranCubit.onQuranPageChanged(
                                          widget.targetStartPage + idx - 1,
                                        );
                                      },
                                      itemBuilder: (context, index) {
                                        return BlocBuilder<KhatmaCubit, KhatmaState>(
                                          builder: (context, state) {
                                            int? sSura, sAyah, eSura, eAyah;
                                            bool isPartial = false;

                                            if (widget.isKahfMode) {
                                              sSura = 18; sAyah = 1;
                                              eSura = 18; eAyah = 110;
                                              isPartial = true;
                                            } else if (widget.isWirdMode && widget.khatmaId != null && state is KhatmaLoaded) {
                                              final khatma = state.khatmas.firstWhere((k) => k.id == widget.khatmaId);
                                              if (widget.wirdIndex != null && widget.wirdIndex! < khatma.wirds.length) {
                                                final wird = khatma.wirds[widget.wirdIndex!];
                                                sSura = wird.startSuraNumber;
                                                sAyah = wird.startAyah;
                                                eSura = wird.endSuraNumber;
                                                eAyah = wird.endAyah;
                                                isPartial = wird.isPartial;
                                              }
                                            }

                                            final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                                            return WbwPageWidget(
                                              pageNumber: widget.targetStartPage + index,
                                              showHeader: true,
                                              showPageNumber: true,
                                              paperColorOverride: bgColor,
                                              textColorOverride: isActuallyDark ? Colors.white : Colors.black,
                                              startSuraNumber: sSura,
                                              startAyah: sAyah,
                                              endSuraNumber: eSura,
                                              endAyah: eAyah,
                                              collapseOutOfRange: isPartial,
                                              isLandscape: isLandscape,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // ── Bottom Bar ──
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  height: (_showOverlays && !isAutoScrolling) ? 120.h : 0,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: (_showOverlays && !isAutoScrolling) ? 1.0 : 0.0,
                                    child: SingleChildScrollView(
                                      physics: const NeverScrollableScrollPhysics(),
                                      child: Container(
                                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                                        decoration: BoxDecoration(
                                          color: barColor,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(40),
                                              blurRadius: 15,
                                              offset: const Offset(0, -4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(5),
                                                    child: LinearProgressIndicator(
                                                      value: _itemCount > 1
                                                          ? (_currentIndex / (_itemCount - 1))
                                                          : 1.0,
                                                      backgroundColor: onBar.withAlpha(20),
                                                      valueColor: const AlwaysStoppedAnimation(Color(0xFFD0A871)), // Gold progress
                                                      minHeight: 6,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  "${(_currentIndex + 1).toArabicNums} / ${_itemCount.toArabicNums}",
                                                  style: TextStyle(
                                                    color: onBar,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(top: 8.h),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: onBar.withValues(alpha: 0.15),
                                                        foregroundColor: onBar,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          side: BorderSide(color: onBar.withValues(alpha: 0.3)),
                                                        ),
                                                        padding: EdgeInsets.symmetric(vertical: 10.h),
                                                      ),
                                                      onPressed: _onFinishWird,
                                                      child: const Text(
                                                        "أتممت القراءة",
                                                        style: TextStyle(
                                                          fontFamily: AppConsts.cairo,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Next Wird Button (if available)
                                                  if (widget.isWirdMode && widget.khatmaId != null)
                                                    BlocBuilder<KhatmaCubit, KhatmaState>(
                                                      builder: (context, khatmaState) {
                                                        final nextWird = context.read<KhatmaCubit>().getNextWird(widget.khatmaId!);
                                                        if (nextWird == null) return const SizedBox.shrink();

                                                        return Expanded(
                                                          child: Padding(
                                                            padding: EdgeInsets.only(right: 12.w),
                                                            child: ElevatedButton(
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: onBar,
                                                                foregroundColor: barColor,
                                                                elevation: 5,
                                                                shadowColor: Colors.black.withValues(alpha: 0.3),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                                              ),
                                                              onPressed: () {
                                                                context.read<KhatmaCubit>().markWirdAsCompleted(widget.khatmaId!, widget.wirdIndex!);
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      "تم إتمام الورد بنجاح! جاري الانتقال للورد التالي...",
                                                                      style: TextStyle(fontFamily: AppConsts.cairo),
                                                                      textAlign: TextAlign.center,
                                                                    ),
                                                                    backgroundColor: Colors.green,
                                                                    duration: Duration(seconds: 2),
                                                                  ),
                                                                );
                                                                Navigator.pushReplacement(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) => IsolatedWirdScreen(
                                                                      isWirdMode: true,
                                                                      khatmaId: widget.khatmaId,
                                                                      wirdIndex: nextWird.wirdIndex,
                                                                      targetStartPage: nextWird.startPage,
                                                                      targetEndPage: nextWird.endPage,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              child: const Text(
                                                                "الورد التالي",
                                                                style: TextStyle(
                                                                  fontFamily: AppConsts.cairo,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  if (!widget.isWirdMode && _currentIndex < _itemCount - 1)
                                                    IconButton(
                                                      onPressed: () {
                                                        _pageController.nextPage(
                                                          duration: const Duration(milliseconds: 400),
                                                          curve: Curves.easeInOut,
                                                        );
                                                      },
                                                      icon: Icon(
                                                        Icons.arrow_forward_ios_rounded,
                                                        color: onBar,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Single Tap Menu (PageActionBar)
                            if (_showMenu)
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: _toggleMenu,
                                  behavior: HitTestBehavior.translucent,
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                            if (_showMenu)
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: PageActionBar(
                                    pageNumber: (widget.targetStartPage + _currentIndex),
                                    onDismiss: _toggleMenu,
                                  ),
                                ),
                              ),

                            // ── Mini Progress Bar (when overlays are hidden) ──
                            if (!_showOverlays && !isAutoScrolling)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(
                                  value: _itemCount > 1
                                      ? (_currentIndex / (_itemCount - 1))
                                      : 1.0,
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFFD0A871)), // Gold
                                  minHeight: 4,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
