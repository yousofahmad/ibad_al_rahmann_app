import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import '../bloc/khatma_cubit.dart';
import '../../quran/bloc/quran/quran_cubit.dart';
import '../../quran/data/repo/quran_repo.dart';
import '../../quran/ui/widgets/wbw_page_widget.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';

class IsolatedWirdScreen extends StatefulWidget {
  final int wirdIndex;
  final int targetStartPage;
  final int targetEndPage;

  const IsolatedWirdScreen({
    super.key,
    required this.wirdIndex,
    required this.targetStartPage,
    required this.targetEndPage,
  });

  @override
  State<IsolatedWirdScreen> createState() => _IsolatedWirdScreenState();
}

class _IsolatedWirdScreenState extends State<IsolatedWirdScreen> {
  Timer? _finishTimer;
  bool _showFinishButton = false;
  late PageController _pageController;
  String _currentTheme = 'light';
  bool _isLoadingTheme = true;
  int _currentIndex = 0;
  bool _hasInitializedWirdPage = false;
  String _wirdStartDate = 'default';

  @override
  void initState() {
    super.initState();
    DailyTrackerService.markAsStarted('wird');

    _pageController = PageController(initialPage: _currentIndex);

    // Enter full immersive mode — hide status bar + nav bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadWirdProgress();
    _loadTheme();
    _showDoubleTapHint();
  }

  Future<void> _loadWirdProgress() async {
    final cache = getIt<CacheService>();
    _wirdStartDate = await cache.getString('wird_start_date') ?? 'default';
    final savedIndex =
        cache.getInt(
          'wird_${_wirdStartDate}_${widget.wirdIndex}_current_page',
        ) ??
        0;

    if (mounted && savedIndex != _currentIndex) {
      setState(() {
        _currentIndex = savedIndex.clamp(0, _itemCount - 1);
      });
      // Defer jumpToPage until the PageView is built and controller is attached
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
  }

  Future<void> _loadTheme() async {
    final theme =
        await getIt<CacheService>().getString('wird_reading_theme') ?? 'light';
    if (mounted) {
      setState(() {
        _currentTheme = theme;
        _isLoadingTheme = false;
      });
      // After the PageView is first built, jump to saved progress
      if (_currentIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_currentIndex);
          }
        });
      }
    }
  }

  void _showDoubleTapHint() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'اضغط مرتين لتغيير لون الخلفية',
              style: TextStyle(fontFamily: 'cairo'),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _toggleTheme() async {
    final nextTheme = _currentTheme == 'light'
        ? 'sepia'
        : (_currentTheme == 'sepia' ? 'dark' : 'light');

    await getIt<CacheService>().setString('wird_reading_theme', nextTheme);
    if (mounted) {
      setState(() {
        _currentTheme = nextTheme;
      });
    }
  }

  Color _getBackgroundColor(String theme) {
    switch (theme) {
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'dark':
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _pageController.dispose();
    // Restore system UI when leaving
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  int get _itemCount =>
      (widget.targetEndPage - widget.targetStartPage + 1).clamp(0, 604);

  void _finishWird() {
    context.read<KhatmaCubit>().markWirdAsCompleted(widget.wirdIndex);
    getIt<CacheService>().setInt('wird_${widget.wirdIndex}_current_page', 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تقبل الله طاعتكم! أتممت الورد بنجاح.',
          style: TextStyle(fontFamily: AppConsts.cairo),
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTheme) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bgColor = _getBackgroundColor(_currentTheme);
    final isActuallyDark = bgColor.computeLuminance() < 0.4;
    final textColor = isActuallyDark ? Colors.white : Colors.black;

    return BlocProvider<QuranCubit>(
      create: (context) => QuranCubit(
        QuranRepo(
          initialPage: (widget.targetStartPage + _currentIndex - 1).clamp(
            0,
            603,
          ),
        ),
        isWirdMode: true,
      ),
      child: Builder(
        builder: (context) {
          // Save initial Wird page using the CORRECT context (below BlocProvider)
          if (!_hasInitializedWirdPage) {
            _hasInitializedWirdPage = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<QuranCubit>().onQuranPageChanged(
                  widget.targetStartPage + _currentIndex - 1,
                );
              }
            });
          }
          return Scaffold(
            backgroundColor: bgColor,
            // No SafeArea — fully immersive, no back button bar
            body: GestureDetector(
              onDoubleTap: _toggleTheme,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _itemCount,
                physics: const PageScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });

                  _finishTimer?.cancel();
                  if (index == _itemCount - 1) {
                    _finishTimer = Timer(const Duration(seconds: 60), () {
                      if (mounted) {
                        setState(() => _showFinishButton = true);
                      }
                    });
                  } else {
                    setState(() => _showFinishButton = false);
                  }

                  getIt<CacheService>().setInt(
                    'wird_${_wirdStartDate}_${widget.wirdIndex}_current_page',
                    index,
                  );
                  context.read<QuranCubit>().onQuranPageChanged(
                    widget.targetStartPage + index - 1,
                  );
                },
                itemBuilder: (context, index) {
                  final realPage = widget.targetStartPage + index;

                  final state = context.read<KhatmaCubit>().state;
                  int? sSura, sAyah, eSura, eAyah;

                  if (state is KhatmaLoaded) {
                    final wirdModel = state.khatma.wirds[widget.wirdIndex];
                    if (wirdModel.isPartial) {
                      sSura = wirdModel.startSuraNumber;
                      sAyah = wirdModel.startAyah;
                      eSura = wirdModel.endSuraNumber;
                      eAyah = wirdModel.endAyah;
                    }
                  }

                  return WbwPageWidget(
                    pageNumber: realPage,
                    startSuraNumber: sSura,
                    startAyah: sAyah,
                    endSuraNumber: eSura,
                    endAyah: eAyah,
                    textColorOverride: textColor,
                    paperColorOverride: bgColor,
                    isZoomEnabled: true,
                  );
                },
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: _showFinishButton
                ? FloatingActionButton.extended(
                    onPressed: _finishWird,
                    backgroundColor: const Color(0xFFD0A871),
                    icon: const Icon(
                      FontAwesomeIcons.checkDouble,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "أتممت القراءة",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}
