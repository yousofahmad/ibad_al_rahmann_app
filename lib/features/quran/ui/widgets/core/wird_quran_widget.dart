import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';

import '../../../../../core/app_constants.dart';
import '../menus/single_tap_menu.dart';
import 'wbw_page_widget.dart';

class WirdQuranWidget extends StatefulWidget {
  final int? targetStartPage;
  final int? targetEndPage;

  const WirdQuranWidget({super.key, this.targetStartPage, this.targetEndPage});

  @override
  State<WirdQuranWidget> createState() => _WirdQuranWidgetState();
}

class _WirdQuranWidgetState extends State<WirdQuranWidget>
    with TickerProviderStateMixin {
  late PageController _controller;
  late ScrollController _autoScrollController;
  int _currentIndex = 0;
  int _itemCount = 0;
  bool _showOverlays = true;
  bool _showMenu = false;
  Timer? _hideMenuTimer;
  double _cachedPageHeight = 800;
  late Ticker _ticker;
  late AnimationController _autoScrollMenuController;

  @override
  void initState() {
    super.initState();
    _currentIndex = (widget.targetStartPage ?? 1) - 1;
    _controller = PageController(initialPage: 0);
    _autoScrollController = ScrollController();
    _ticker = createTicker((elapsed) {
      if (mounted && _autoScrollController.hasClients) {
        final speed = context.read<QuranCubit>().state.autoScrollSpeed;
        _autoScrollController.jumpTo(
          _autoScrollController.offset + (speed * 1.5),
        );
      }
    });

    _autoScrollMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    _autoScrollController.dispose();
    _ticker.dispose();
    _autoScrollMenuController.dispose();
    _hideMenuTimer?.cancel();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
      _showOverlays = !_showMenu;
      if (_showOverlays) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  bool _hasInitializedWirdPage = false;

  @override
  Widget build(BuildContext context) {
    _cachedPageHeight = MediaQuery.of(context).size.height * 0.9;

    return BlocListener<QuranCubit, QuranState>(
      listener: (context, state) {
        if (!_hasInitializedWirdPage && state.currentPage != null) {
          _hasInitializedWirdPage = true;
          final start = state.wirdStartPage ?? widget.targetStartPage ?? 1;
          final int relative = (state.currentPage! - (start - 1)).clamp(0, _itemCount - 1);
          _currentIndex = state.currentPage!;
          if (_controller.hasClients) {
            _controller.jumpToPage(relative);
          }
        }
      },
      child: BlocBuilder<QuranCubit, QuranState>(
        builder: (context, state) {
          final start = state.wirdStartPage ?? widget.targetStartPage ?? 1;
          final end = state.targetEndPage ?? widget.targetEndPage ?? start;
          _itemCount = end - start + 1;

        final bool isFullLayout = state.layout == QuranLayout.full;

        final Color? savedColor = state.isWirdMode ? state.wirdPaperColor : (state.isKahfMode ? state.kahfPaperColor : null);

        final scaffoldBg =
            savedColor ?? Theme.of(context).scaffoldBackgroundColor;
        final isActuallyDark = scaffoldBg.computeLuminance() < 0.5;
        final textColor = isActuallyDark ? Colors.white : Colors.black;

        // Bars use primary color for consistency (Blue, Cyan, etc.)
        final Color barBg = Theme.of(context).primaryColor;
        final Color onBar = Theme.of(context).colorScheme.onPrimary;

        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return Scaffold(
          backgroundColor: scaffoldBg,
          body: SafeArea(
            bottom: false,
            top: false,
            left: isLandscape,
            right: isLandscape,
            child: GestureDetector(
              onTap: _toggleMenu,
              onDoubleTap: () {
                if (state.isAutoScrolling) {
                  context.read<QuranCubit>().setAutoScrollPaused(true);
                  _autoScrollMenuController.forward();
                } else {
                  context.read<QuranCubit>().changeLayout();
                }
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Top Bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _showOverlays ? null : 0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _showOverlays ? 1.0 : 0.0,
                          child: Container(
                            padding: EdgeInsets.only(
                              top: 10.h + MediaQuery.of(context).padding.top,
                              bottom: 10.h,
                              left: 20.w,
                              right: 20.w,
                            ),
                            decoration: BoxDecoration(
                              color: barBg,
                              border: Border(
                                bottom: BorderSide(
                                  color: onBar.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(
                                    Icons.close,
                                    color: onBar,
                                    size: 24.sp,
                                  ),
                                ),
                                SizedBox(width: 15.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      state.isKahfMode
                                          ? "سورة الكهف"
                                          : (state.isWirdMode
                                              ? "الورد اليومي"
                                              : "مصحف الورد"),
                                      style: TextStyle(
                                        fontFamily: AppConsts.expoArabic,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: onBar,
                                      ),
                                    ),
                                    Text(
                                      "من صـ ${start.toArabicNums} إلى ${end.toArabicNums}",
                                      style: TextStyle(
                                        fontFamily: AppConsts.cairo,
                                        fontSize: 10.sp,
                                        color: onBar.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.info_outline_rounded,
                                    color: onBar,
                                  ),
                                  onPressed: () =>
                                      IntroService.showQuranIntro(context),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.palette_outlined,
                                    color: onBar,
                                  ),
                                  onPressed: () =>
                                      PageActionBar.showColorPalette(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Quran Pages
                      Expanded(
                        child: (!state.isAutoScrolling)
                            ? PageView.builder(
      allowImplicitScrolling: true,
                                controller: _controller,
                                physics: const BouncingScrollPhysics(
                                  parent: PageScrollPhysics(),
                                ),
                                itemCount: _itemCount,
                                reverse: false,
                                onPageChanged: (relativeIndex) {
                                  final newAbsoluteIndex =
                                      relativeIndex + (start - 1);
                                  if (newAbsoluteIndex != _currentIndex) {
                                    _currentIndex = newAbsoluteIndex;
                                    context
                                        .read<QuranCubit>()
                                        .onQuranPageChanged(_currentIndex);
                                    setState(() {});
                                  }
                                },
                                itemBuilder: (context, relativeIndex) {
                                  final realPageIndex =
                                      relativeIndex + (start - 1);
                                  return WbwPageWidget(
                                    pageNumber: realPageIndex + 1,
                                    isZoomEnabled: true,
                                    showHeader: isFullLayout,
                                    showPageNumber: isFullLayout,
                                    textColorOverride: textColor,
                                    paperColorOverride: savedColor,
                                    isLandscape: isLandscape,
                                    startSuraNumber:
                                        state.isKahfMode ? 18 : null,
                                    startAyah: state.isKahfMode ? 1 : null,
                                    endSuraNumber:
                                        state.isKahfMode ? 18 : null,
                                    endAyah: state.isKahfMode ? 110 : null,
                                  );
                                },
                              )
                            : ListView.builder(
                                controller: _autoScrollController,
                                scrollDirection: Axis.vertical,
                                cacheExtent:
                                    MediaQuery.of(context).size.height * 3.0,
                                physics: const ClampingScrollPhysics(),
                                itemCount: _itemCount,
                                itemBuilder: (context, index) {
                                  final realPageIndex = index + (start - 1);
                                  return SizedBox(
                                    height: _cachedPageHeight,
                                    child: WbwPageWidget(
                                      key: ValueKey(
                                        'vertical_${realPageIndex + 1}',
                                      ),
                                      pageNumber: realPageIndex + 1,
                                      showHeader: isFullLayout,
                                      showPageNumber: isFullLayout,
                                      isZoomEnabled: false,
                                      textColorOverride: textColor,
                                      paperColorOverride: savedColor,
                                      isSeamlessScroll: true,
                                      isLandscape: isLandscape,
                                      startSuraNumber:
                                          state.isKahfMode ? 18 : null,
                                      startAyah: state.isKahfMode ? 1 : null,
                                      endSuraNumber:
                                          state.isKahfMode ? 18 : null,
                                      endAyah: state.isKahfMode ? 110 : null,
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Bottom Bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _showOverlays ? null : 0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _showOverlays ? 1.0 : 0.0,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 12.h,
                            ).copyWith(
                              bottom: 12.h + MediaQuery.of(context).padding.bottom,
                            ),
                            decoration: BoxDecoration(
                              color: barBg,
                              border: Border(
                                top: BorderSide(
                                  color: onBar.withValues(alpha: 0.1),
                                ),
                              ),
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
                                              ? (((_controller.hasClients
                                                        ? _controller.page ?? 0
                                                        : _currentIndex -
                                                              (start - 1))) /
                                                    (_itemCount - 1))
                                              : 1.0,
                                          backgroundColor:
                                              onBar.withValues(alpha: 0.1),
                                          valueColor: AlwaysStoppedAnimation(
                                            onBar,
                                          ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      "${((_controller.hasClients ? (_controller.page?.round() ?? 0) : _currentIndex - (start - 1)) + 1).toArabicNums} / ${_itemCount.toArabicNums}",
                                      style: TextStyle(
                                        color: onBar,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (state.isWirdMode &&
                                    state.khatmaId != null &&
                                    state.wirdIndex != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8.h),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: onBar,
                                              foregroundColor: barBg,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(
                                                  8,
                                                ),
                                              ),
                                            ),
                                            onPressed: () {
                                              context
                                                  .read<KhatmaCubit>()
                                                  .markWirdAsCompleted(
                                                    state.khatmaId!,
                                                    state.wirdIndex!,
                                                  );
                                              _showTopNotification(
                                                context,
                                                'تقبل الله طاعتكم! تم إتمام الورد بنجاح',
                                              );
                                            },
                                            child: const Text(
                                              'أتممت الورد',
                                              style: TextStyle(
                                                fontFamily: AppConsts.cairo,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        BlocBuilder<KhatmaCubit, KhatmaState>(
                                          builder: (context, khatmaState) {
                                            final nextWird = context.read<KhatmaCubit>().getNextWird(state.khatmaId!);
                                            if (nextWird == null) return const SizedBox.shrink();

                                            return Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white.withAlpha(40),
                                                  foregroundColor: onBar,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(
                                                      8,
                                                    ),
                                                    side: BorderSide(color: onBar, width: 1),
                                                  ),
                                                ),
                                                onPressed: () {
                                                  context.read<KhatmaCubit>().markWirdAsCompleted(state.khatmaId!, state.wirdIndex!);
                                                  context.read<QuranCubit>().jumpToWird(
                                                    startPage: nextWird.startPage,
                                                    endPage: nextWird.endPage,
                                                    index: nextWird.wirdIndex,
                                                  );
                                                  _showTopNotification(
                                                    context,
                                                    'تقبل الله طاعتكم! تم الانتقال للورد التالي',
                                                  );
                                                },
                                                child: const Text(
                                                  'الورد التالي',
                                                  style: TextStyle(
                                                    fontFamily: AppConsts.cairo,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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
                      child: PageActionBar(
                        pageNumber: _currentIndex + 1,
                        onDismiss: _toggleMenu,
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
}

  static void _showTopNotification(BuildContext context, String message,
      {bool isError = false}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notification',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }
}
