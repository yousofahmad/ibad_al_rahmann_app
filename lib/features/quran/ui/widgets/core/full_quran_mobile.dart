import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../menus/single_tap_menu.dart';
import '../scroll/auto_scroll_control_overlay.dart';

import './wbw_page_widget.dart';

class FullQuranWidget extends StatefulWidget {
  const FullQuranWidget({super.key, this.currentPage});
  final int? currentPage;

  @override
  State<FullQuranWidget> createState() => _FullQuranWidgetState();
}

class _FullQuranWidgetState extends State<FullQuranWidget>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late ScrollController _autoScrollController;
  late Ticker _ticker;
  double _lastElapsedMillis = 0;
  int _currentIndex = 0;
  bool _showOverlays = false;
  bool _showAutoScrollMenu = false;
  Timer? _hideMenuTimer;
  double _cachedPageHeight = 0.0;
  double _lastWidth = 0.0;
  bool _wasAutoScrolling = false;

  double _getPageHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    return isLandscape ? size.width * 1.95 : size.width * 1.85;
  }

  @override
  void initState() {
    _currentIndex = widget.currentPage ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    _autoScrollController = ScrollController();
    _ticker = createTicker(_onTick);
    
    // Start in immersive mode (status bar hidden) as it's full Mushaf view by default.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    super.initState();
    _showIntroIfNeeded();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<QuranCubit>().state;
      if (state.isAutoScrolling && !_ticker.isTicking) {
        _wasAutoScrolling = true;
        if (_cachedPageHeight == 0) {
          _cachedPageHeight = _getPageHeight(context);
        }
        setState(() {
          _showAutoScrollMenu = !state.isAutoScrollPaused;
          _showOverlays = false;
        });
        if (!state.isAutoScrollPaused) _startHideMenuTimer();
        if (_autoScrollController.hasClients) {
          _autoScrollController.jumpTo(_currentIndex * _cachedPageHeight);
        } else {
          _autoScrollController.dispose();
          _autoScrollController = ScrollController(
            initialScrollOffset: _currentIndex * _cachedPageHeight,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_ticker.isTicking && !state.isAutoScrollPaused) {
            _startAutoScrollTimer();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ticker.dispose();
    _hideMenuTimer?.cancel();
    _pageController.dispose();
    _autoScrollController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final state = context.read<QuranCubit>().state;
    if (state.isAutoScrolling &&
        !state.isAutoScrollPaused &&
        _autoScrollController.hasClients) {
      final double currentMillis = elapsed.inMicroseconds / 1000.0;
      double deltaMillis = currentMillis - _lastElapsedMillis;
      if (_lastElapsedMillis == 0 || deltaMillis > 100) deltaMillis = 16.6;
      _lastElapsedMillis = currentMillis;

      final double pixelsPerMs = 0.05 * state.autoScrollSpeed;
      final double move = deltaMillis * pixelsPerMs;

      final double currentOffset = _autoScrollController.offset;
      final maxExtent = _autoScrollController.position.maxScrollExtent;

      if (currentOffset < maxExtent) {
        _autoScrollController.jumpTo(currentOffset + move);

        if (_cachedPageHeight > 0) {
          final int newIndex =
              (_autoScrollController.offset / _cachedPageHeight).round().clamp(
                0,
                603,
              );
          if (newIndex != _currentIndex) {
            _currentIndex = newIndex;
            context.read<QuranCubit>().onQuranPageChanged(_currentIndex);
          }
        }
      } else {
        context.read<QuranCubit>().stopAutoScroll();
      }
    } else {
      _lastElapsedMillis = elapsed.inMicroseconds / 1000.0;
    }
  }

  void _startAutoScrollTimer() {
    _lastElapsedMillis = 0;
    _ticker.start();
  }

  void _startHideMenuTimer() {
    _hideMenuTimer?.cancel();
    _hideMenuTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !context.read<QuranCubit>().state.isAutoScrollPaused) {
        setState(() => _showAutoScrollMenu = false);
      }
    });
  }

  void _showIntroIfNeeded() {
    if (!IntroService.hasShownDoubleTapIntro()) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          IntroService.showQuranIntro(context);
        }
      });
    }
  }

  void _toggleOverlays() {
    setState(() {
      _showOverlays = !_showOverlays;
      if (_showOverlays) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuranCubit, QuranState>(
      listener: (context, state) {
        if (state.currentPage != null && state.currentPage != _currentIndex) {
          _currentIndex = state.currentPage!;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentIndex);
          }
        }

        if (state.isAutoScrolling != _wasAutoScrolling) {
          _wasAutoScrolling = state.isAutoScrolling;
          if (state.isAutoScrolling) {
            if (_cachedPageHeight == 0) {
              _cachedPageHeight = _getPageHeight(context);
            }

            setState(() {
              _showAutoScrollMenu = true;
              _showOverlays = false; // hide single-tap bar immediately
            });
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            _startHideMenuTimer();
            if (!_ticker.isTicking) {
              if (_autoScrollController.hasClients) {
                _autoScrollController.jumpTo(_currentIndex * _cachedPageHeight);
              } else {
                _autoScrollController.dispose();
                _autoScrollController = ScrollController(
                  initialScrollOffset: _currentIndex * _cachedPageHeight,
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startAutoScrollTimer();
              });
            }
          } else {
            _ticker.stop();
            setState(() => _showAutoScrollMenu = false);
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_currentIndex);
            } else {
              _pageController.dispose();
              _pageController = PageController(initialPage: _currentIndex);
            }
          }
        }
      },
      builder: (context, state) {
        final currentWidth = MediaQuery.of(context).size.width;
        if (_lastWidth != 0 && _lastWidth != currentWidth) {
          _cachedPageHeight = _getPageHeight(context);
          if (state.isAutoScrolling) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_autoScrollController.hasClients) {
                _autoScrollController.jumpTo(_currentIndex * _cachedPageHeight);
              }
            });
          }
        } else if (_cachedPageHeight == 0) {
          _cachedPageHeight = _getPageHeight(context);
        }
        _lastWidth = currentWidth;

        final paperColorOverride = state.quranPaperColor;
        final scaffoldBg =
            paperColorOverride ?? Theme.of(context).scaffoldBackgroundColor;
        final isActuallyDark = scaffoldBg.computeLuminance() < 0.5;
        final textColor = isActuallyDark ? Colors.white : Colors.black;
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return ColoredBox(
          color: scaffoldBg,
          child: SafeArea(
            top: false,
            bottom: false,
            left: true,
            right: true,
            child: Stack(
              children: [
                _TapListener(
                  onSingleTap: () {
                    if (state.isAutoScrolling) {
                      context.read<QuranCubit>().setAutoScrollPaused(true);
                      setState(() => _showAutoScrollMenu = true);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      _hideMenuTimer?.cancel();
                    } else {
                      _toggleOverlays();
                    }
                  },
                  onDoubleTap: () {
                    context.read<QuranCubit>().changeLayout();
                  },
                  child: state.isAutoScrolling
                      ? ListView.builder(
                          controller: _autoScrollController,
                          scrollDirection: Axis.vertical,
                          cacheExtent:
                              MediaQuery.of(context).size.height * 3.0,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 604,
                          itemBuilder: (context, index) {
                            return SizedBox(
                              height: _cachedPageHeight,
                              child: WbwPageWidget(
                                pageNumber: index + 1,
                                isZoomEnabled: false,
                                textColorOverride: textColor,
                                paperColorOverride: state.quranPaperColor,
                                isSeamlessScroll: true,
                                isLandscape: isLandscape,
                              ),
                            );
                          },
                        )
                      : PageView.builder(
                          allowImplicitScrolling: true,
                          controller: _pageController,
                          physics: const ClampingScrollPhysics(
                            parent: PageScrollPhysics(),
                          ),
                          pageSnapping: true,
                          itemCount: 604,
                          onPageChanged: (value) {
                            if (value != _currentIndex) {
                              _currentIndex = value;
                              context.read<QuranCubit>().onQuranPageChanged(
                                    value,
                                  );
                            }
                          },
                          itemBuilder: (context, index) {
                            return WbwPageWidget(
                              pageNumber: index + 1,
                              isZoomEnabled: true,
                              textColorOverride: textColor,
                              paperColorOverride: state.quranPaperColor,
                              isLandscape: isLandscape,
                            );
                          },
                        ),
                ),
                if (_showOverlays && !state.isAutoScrolling)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: PageActionBar(
                          pageNumber: _currentIndex + 1,
                          onDismiss: _toggleOverlays,
                        ),
                      ),
                    ),
                  ),
                if (state.isAutoScrolling && _showAutoScrollMenu)
                  Positioned(
                    bottom: 50.h,
                    left: 0,
                    right: 0,
                    child: AutoScrollControlOverlay(
                      onPlay: () {
                        context.read<QuranCubit>().setAutoScrollPaused(false);
                        _startHideMenuTimer();
                        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                      },
                      onStop: () {
                        context.read<QuranCubit>().stopAutoScroll();
                        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TapListener extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;

  const _TapListener({
    required this.child,
    this.onSingleTap,
    this.onDoubleTap,
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
  static const Duration _singleTapDelay = Duration(milliseconds: 280);

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    _downPosition = e.localPosition;
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
