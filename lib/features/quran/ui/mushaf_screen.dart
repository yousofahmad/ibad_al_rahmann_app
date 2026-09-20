import 'package:ibad_al_rahmann/features/quran/ui/widgets/scroll/easy_page_scroll_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/quran_db_helper.dart';
import 'layouts/mobile_quran_top_bar.dart';
import 'layouts/mobile_min_quran_bottom_section.dart';
import 'widgets/menus/single_tap_menu.dart';
import '../bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import '../../../widgets/app_skeleton.dart';



class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen>
    with SingleTickerProviderStateMixin {
  PageController _pageController = PageController();
  ScrollController _autoScrollController = ScrollController();
  late final Ticker _scrollTicker;
  Duration _lastElapsed = Duration.zero;
  int _currentIndex = 1;
  double _scrollSpeed = 0.5;
  bool _isPaused = false;
  bool _showMenu = false;
  double _cachedScreenHeight = 0; // cached to avoid MediaQuery every frame

  @override
  void initState() {
    super.initState();
    _scrollTicker = createTicker(_onTick);
    WakelockPlus.enable();
    _currentIndex = context.read<QuranCubit>().state.currentPage ?? 1;
    _pageController = PageController(initialPage: _currentIndex - 1);
    // Cache screen height once — safe to do in initState via WidgetsBinding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cachedScreenHeight = MediaQuery.of(context).size.height;
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (_isPaused || !_autoScrollController.hasClients) {
      _lastElapsed = elapsed;
      return;
    }
    final delta = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    // Clamp delta: skip frames > 100ms (e.g. after resume), use 16ms if 0
    if (delta <= 0) return;
    final clampedDelta = delta > 0.1 ? 0.016 : delta;

    final pixelsPerSec = _scrollSpeed * 33.3;
    final newOffset = _autoScrollController.offset + (pixelsPerSec * clampedDelta);
    if (newOffset <= _autoScrollController.position.maxScrollExtent) {
      _autoScrollController.jumpTo(newOffset);
      final pageHeight = _cachedScreenHeight > 0 ? _cachedScreenHeight : MediaQuery.of(context).size.height;
      if (pageHeight > 0) {
        final newIndex = (newOffset / pageHeight).round() + 1;
        if (newIndex != _currentIndex && newIndex > 0 && newIndex <= 604) {
          _currentIndex = newIndex;
          context.read<QuranCubit>().onQuranPageChanged(_currentIndex);
        }
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _scrollTicker.dispose();
    _pageController.dispose();
    _autoScrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _lastElapsed = Duration.zero;
    if (!_scrollTicker.isActive) {
      _scrollTicker.start();
    }
  }

  void _stopAutoScroll() {
    if (_scrollTicker.isActive) {
      _scrollTicker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAutoScrolling = context.watch<QuranCubit>().state.isAutoScrolling;
    final screenHeight = MediaQuery.of(context).size.height;
    _cachedScreenHeight = screenHeight;

    return BlocListener<QuranCubit, QuranState>(
      listenWhen: (p, c) => p.isAutoScrolling != c.isAutoScrolling,
      listener: (context, state) {
        if (state.isAutoScrolling) {
          _isPaused = false;
          _showMenu = false;
          _autoScrollController = ScrollController(
            initialScrollOffset: (_currentIndex - 1) * screenHeight,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startAutoScroll();
          });
        } else {
          _stopAutoScroll();
          _pageController = PageController(initialPage: _currentIndex - 1);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 100.h,
                    child: const MobileQuranTopBar(),
                  ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) {
                        if (isAutoScrolling && !_isPaused) {
                          setState(() {
                            _isPaused = true;
                          });
                        }
                      },
                      onPointerUp: (_) {
                        setState(() {
                          _showMenu = !_showMenu;
                        });
                      },
                      child: isAutoScrolling
                          ? ListView.builder(
                              controller: _autoScrollController,
                              scrollDirection: Axis.vertical,
                              physics: const ClampingScrollPhysics(),
                              itemCount: 604,
                              itemExtent: screenHeight,
                              cacheExtent: screenHeight * 2.0,
                              itemBuilder: (context, index) {
                                return _buildPageContent(index + 1);
                              },
                            )
                          : PageView.builder(
                              allowImplicitScrolling: true,
                              controller: _pageController,
                              itemCount: 604,
                              reverse: true,
                              physics: const BouncingScrollPhysics(parent: EasyPageScrollPhysics()),
                              onPageChanged: (idx) {
                                _currentIndex = idx + 1;
                                context.read<QuranCubit>().onQuranPageChanged(
                                  _currentIndex,
                                );
                              },
                              itemBuilder: (context, index) {
                                return _buildPageContent(index + 1);
                              },
                            ),
                    ),
                  ),
                  const MobileMinQuranBottomSection(),
                ],
              ),

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
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.95),
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
                              inactiveColor: Colors.white24,
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

  Widget _buildPageContent(int pageNumber) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: QuranDbHelper.instance.getPageLines(pageNumber),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return AppSkeleton.quranPage();
        }

        final lines = snapshot.data!;
        if (lines.isEmpty) {
          return const Center(child: Text('لا توجد بيانات لهذه الصفحة'));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: lines.map((lineData) {
              final text = lineData['line_text'] as String;
              final isCentered = lineData['is_centered'] as int;
              final isPage1Or2 = (pageNumber == 1 || pageNumber == 2);
              final fontFamily =
                  'qpc_v1_page${pageNumber.toString().padLeft(3, '0')}';

              return Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: (context.isTablet ? 24.0 : 0.0) +
                          context
                              .watch<QuranCubit>()
                              .state
                              .quranPageMargin,
                    ),
                    child: SizedBox(
                      width: 1000,
                      child: Wrap(
                        textDirection: TextDirection.rtl,
                        alignment: (isCentered == 1 || isPage1Or2)
                            ? WrapAlignment.center
                            : WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: text.split(' ').map((glyph) {
                          return Text(
                            glyph,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 125,
                              height: 1.5,
                              color:
                                  Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color ??
                                  Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
