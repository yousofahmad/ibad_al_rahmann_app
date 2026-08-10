import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/theme_manager/theme_cubit.dart';

import 'widgets/core/wbw_page_widget.dart';
import 'widgets/menus/single_tap_menu.dart';
import 'layouts/mobile_quran_top_bar.dart';
import 'layouts/mobile_min_quran_bottom_section.dart';
import '../bloc/quran/quran_cubit.dart';

class WbwMushafScreen extends StatefulWidget {
  const WbwMushafScreen({super.key});

  @override
  State<WbwMushafScreen> createState() => _WbwMushafScreenState();
}

class _WbwMushafScreenState extends State<WbwMushafScreen> {
  late PageController _pageController;
  ScrollController _autoScrollController = ScrollController();
  bool _isPaused = false;
  double _scrollSpeed = 1.5;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;
  bool _showMenu = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _currentIndex = context.read<QuranCubit>().state.currentPage ?? 1;
    _pageController = PageController(initialPage: _currentIndex - 1);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _autoScrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused && _autoScrollController.hasClients) {
        final maxExtent = _autoScrollController.position.maxScrollExtent;
        final currentOffset = _autoScrollController.offset;

        if (currentOffset < maxExtent) {
          _autoScrollController.jumpTo(currentOffset + _scrollSpeed);
          int newIndex =
              (_autoScrollController.offset /
                      MediaQuery.of(context).size.height)
                  .round() +
              1;
          if (newIndex != _currentIndex && newIndex > 0 && newIndex <= 604) {
            _currentIndex = newIndex;
            context.read<QuranCubit>().onQuranPageChanged(_currentIndex);
          }
        } else {
          // Reached the end, stop auto-scroll
          context.read<QuranCubit>().toggleAutoScroll();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeCubit>().state.mode == ThemeMode.dark;
    final paperColor = isDark ? Colors.black : Colors.white;
    final isAutoScrolling = context.watch<QuranCubit>().state.isAutoScrolling;
    final themeColor = Theme.of(context).colorScheme.primary;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: paperColor,
      body: SafeArea(
        top: true,
        child: BlocListener<QuranCubit, QuranState>(
          listenWhen: (p, c) => p.isAutoScrolling != c.isAutoScrolling,
          listener: (context, state) {
            if (state.isAutoScrolling) {
              _isPaused = false;
              // Dispose old controller and create fresh one at current page
              _autoScrollController.dispose();
              _autoScrollController = ScrollController(
                initialScrollOffset:
                    (_currentIndex - 1) * MediaQuery.of(context).size.height,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startTimer();
              });
            } else {
              _autoScrollTimer?.cancel();
              setState(() {
                _pageController = PageController(
                  initialPage: _currentIndex - 1,
                );
              });
            }
          },
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 100.h,
                    child: const MobileQuranTopBar(),
                  ),
                  Expanded(
                    child: _TapListener(
                      onSingleTap: () {
                        if (!isAutoScrolling) {
                          setState(() => _showMenu = !_showMenu);
                        }
                      },
                      onDoubleTap: () =>
                          context.read<QuranCubit>().changeLayout(),
                      onPointerDown: () {
                        if (isAutoScrolling && !_isPaused) {
                          setState(() => _isPaused = true);
                        }
                      },
                      child: isAutoScrolling
                          ? ListView.builder(
                              controller: _autoScrollController,
                              scrollDirection: Axis.vertical,
                              physics: const ClampingScrollPhysics(),
                              itemCount: 604,
                              itemBuilder: (context, index) {
                                final isLandscape =
                                    MediaQuery.of(context).orientation ==
                                    Orientation.landscape;
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isLandscape ? 20 : 0,
                                    vertical: isLandscape ? 10 : 0,
                                  ),
                                  child: SizedBox(
                                    height: MediaQuery.of(context).size.height,
                                    child: WbwPageWidget(
                                      key: ValueKey('vert_${index + 1}'),
                                      pageNumber: index + 1,
                                      isZoomEnabled: false,
                                      isLandscape: isLandscape,
                                    ),
                                  ),
                                );
                              },
                            )
                          : PageView.builder(
      allowImplicitScrolling: true,
                              controller: _pageController,
                              itemCount: 604,
                              reverse: true,
                              physics: const ClampingScrollPhysics(
                                parent: PageScrollPhysics(),
                              ),
                              onPageChanged: (idx) {
                                _currentIndex = idx + 1;
                                _showMenu = false;
                                context.read<QuranCubit>().onQuranPageChanged(
                                  _currentIndex,
                                );
                              },
                              itemBuilder: (context, index) {
                                final isLandscape =
                                    MediaQuery.of(context).orientation ==
                                    Orientation.landscape;
                                return WbwPageWidget(
                                  key: ValueKey('horz_${index + 1}'),
                                  pageNumber: index + 1,
                                  isZoomEnabled: true,
                                  isLandscape: isLandscape,
                                );
                              },
                            ),
                    ),
                  ),
                  const MobileMinQuranBottomSection(),
                ],
              ),

              // ─── Single-tap menu (Fix 2: always at top in normal Mushaf) ───
              if (_showMenu && !isAutoScrolling)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: PageActionBar(
                    pageNumber: _currentIndex,
                    onDismiss: () => setState(() => _showMenu = false),
                  ),
                ),

              // ─── Auto-scroll control bar ───
              if (isAutoScrolling)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPaused = !_isPaused;
                            });
                          },
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.0,
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10.0,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              ),
                            ),
                            child: Slider(
                              value: _scrollSpeed,
                              min: 0.5,
                              max: 5.0,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white30,
                              onChanged: (val) {
                                setState(() {
                                  _scrollSpeed = val;
                                });
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () =>
                              context.read<QuranCubit>().toggleAutoScroll(),
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
  }
}

/// Detects single-tap and double-tap via raw pointer events so it works
/// correctly inside a PageView/ListView without gesture-arena conflicts.
class _TapListener extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onPointerDown;

  const _TapListener({
    required this.child,
    this.onSingleTap,
    this.onDoubleTap,
    this.onPointerDown,
  });

  @override
  State<_TapListener> createState() => _TapListenerState();
}

class _TapListenerState extends State<_TapListener> {
  Offset? _downPosition;
  DateTime? _lastTapTime;
  Timer? _singleTapTimer;

  static const double _maxMoveDelta = 10.0;
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  static const Duration _singleTapDelay = Duration(milliseconds: 320);

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    _downPosition = e.localPosition;
    widget.onPointerDown?.call();
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_downPosition == null) return;
    final delta = (e.localPosition - _downPosition!).distance;
    if (delta > _maxMoveDelta) {
      _downPosition = null;
      return;
    }
    _downPosition = null;

    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow) {
      _singleTapTimer?.cancel();
      _lastTapTime = null;
      widget.onDoubleTap?.call();
    } else {
      _lastTapTime = now;
      _singleTapTimer?.cancel();
      _singleTapTimer = Timer(_singleTapDelay, () {
        if (mounted) widget.onSingleTap?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: widget.child,
    );
  }
}
