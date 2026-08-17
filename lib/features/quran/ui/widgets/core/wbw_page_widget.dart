import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import '../../../data/quran_word.dart';
import '../../../data/models/page_line.dart';
import '../../../data/db_helper.dart';
import '../../../bloc/quran/quran_cubit.dart';
import '../../../bloc/verse_player/verse_player_cubit.dart';
import '../../../../../core/app_constants.dart';
import '../../../../../core/helpers/extensions/int_extensions.dart';
import '../../../../../core/theme/theme_manager/theme_cubit.dart';
import '../menus/verse_overlay_widget.dart';
import '../components/header_widget.dart';
import '../../quran_hizb_data.dart';
import '../components/basmallah.dart';
import '../../../../../core/helpers/extensions/screen_details.dart';
import '../../../../../core/theme/quran_theme_extension.dart';
import '../../../../../core/helpers/fonts_helper.dart';
import '../../../data/models/selected_verse_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../components/ayah_marker_widget.dart';

import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';

class WbwPageWidget extends StatefulWidget {
  final int pageNumber;
  final bool isZoomEnabled;
  final int? startSuraNumber;
  final int? startAyah;
  final int? endSuraNumber;
  final int? endAyah;
  final bool showHeader;
  final bool showPageNumber;
  final Color? textColorOverride;
  final Color? paperColorOverride;
  final bool isSeamlessScroll;

  /// When true, lines that have no visible content (outside the rub' range)
  /// are fully collapsed to zero height, showing only the portion of the page
  /// that belongs to the current Rub' (quarter).
  final bool collapseOutOfRange;

  const WbwPageWidget({
    super.key,
    required this.pageNumber,
    this.isZoomEnabled = true,
    this.startSuraNumber,
    this.startAyah,
    this.endSuraNumber,
    this.endAyah,
    this.showHeader = true,
    this.showPageNumber = true,
    this.textColorOverride,
    this.paperColorOverride,
    this.isSeamlessScroll = false,
    this.collapseOutOfRange = false,
    this.isLandscape = false,
  });

  final bool isLandscape;

  @override
  State<WbwPageWidget> createState() => _WbwPageWidgetState();
}

class _WbwPageWidgetState extends State<WbwPageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PageLine>? _pageLines;
  Map<int, List<QuranWord>> _lineWordsMap = {};
  String? _error;
  QuranWord? _selectedWord;
  String? _fontFamily;
  bool _isLoading = true; // Gets overridden synchronously if cache hits
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformationController =
      TransformationController();
  bool _isAtBottom = false;
  bool _isZoomed = false;

  Timer? _bookmarkHighlightTimer;

  @override
  void initState() {
    super.initState();
    _fontFamily = FontsHelper.getFontFamily(widget.pageNumber);
    _loadLinesAndWords();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant WbwPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _fontFamily = FontsHelper.getFontFamily(widget.pageNumber);
      _loadLinesAndWords();
    }
  }

  void _onScroll() {
    final bool atBottom =
        _scrollController.position.pixels >=
        (_scrollController.position.maxScrollExtent - 20);

    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _transformationController.dispose();
    _bookmarkHighlightTimer?.cancel();
    super.dispose();
  }

  void _loadLinesAndWords() {
    final cachedLines = QuranWbwDbHelper.instance.getPageLinesSync(
      widget.pageNumber,
    );
    final cachedWords = QuranWbwDbHelper.instance.getPageWordsSync(
      widget.pageNumber,
    );
    final isFontLoaded = FontsHelper.isFontLoaded(_fontFamily!);

    if (cachedLines != null && cachedWords != null && isFontLoaded) {
      _pageLines = cachedLines;
      final Map<int, List<QuranWord>> lineMap = {};
      for (var word in cachedWords) {
        final ln = word.lineNumber ?? 1;
        lineMap.putIfAbsent(ln, () => []).add(word);
      }
      _lineWordsMap = lineMap;
      _isLoading = false;
      return;
    }

    // Async slow path
    _isLoading = true;
    _fetchAsync();
  }

  Future<void> _fetchAsync() async {
    // Optimization: minimal delay to maintain smoothness while skipping fast flicking
    await Future.delayed(const Duration(milliseconds: 20));
    if (!mounted) return;

    // Trigger neighbor preloading immediately in parallel
    _preloadNeighbor(widget.pageNumber + 1);
    _preloadNeighbor(widget.pageNumber - 1);

    try {
      await Future.wait([
        FontsHelper.loadFontFromFamily(_fontFamily!),
        _fetchDbData(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Preload a bit further in the background
        _preloadNeighbor(widget.pageNumber + 2);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _preloadNeighbor(int page) async {
    if (page < 1 || page > 604) return;
    try {
      final family = FontsHelper.getFontFamily(page);
      if (!FontsHelper.isFontLoaded(family)) {
        await FontsHelper.loadFontFromFamily(family);
      }
      await QuranWbwDbHelper.instance.getPageLines(page);
      await QuranWbwDbHelper.instance.getPageWords(page);
    } catch (e) {
      debugPrint('Error preloading neighbor page: $e');
    }
  }

  Future<void> _fetchDbData() async {
    final lines = await QuranWbwDbHelper.instance.getPageLines(
      widget.pageNumber,
    );
    final words = await QuranWbwDbHelper.instance.getPageWords(
      widget.pageNumber,
    );

    final Map<int, List<QuranWord>> lineMap = {};
    for (var word in words) {
      final ln = word.lineNumber ?? 1;
      lineMap.putIfAbsent(ln, () => []).add(word);
    }

    if (mounted) {
      _pageLines = lines;
      _lineWordsMap = lineMap;
    }
  }

  void _scheduleHighlightClear() {
    _bookmarkHighlightTimer?.cancel();
    _bookmarkHighlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        try {
          final playerCubit = context.read<VersePlayerCubit>();
          // Only clear the highlight if the audio player is not explicitly shown
          if (!playerCubit.state.showed) {
            playerCubit.hide();
          }
        } catch (e) {
          debugPrint('Error hiding player cubit on timer: $e');
        }
        if (mounted) {
          setState(() {
            _selectedWord = null;
          });
        }
      }
    });
  }

  Future<void> _onWordLongPressed(
    BuildContext context,
    VersePlayerCubit playerCubit,
    QuranWord word,
  ) async {
    if (word.suraNumber == null ||
        word.ayahNumber == null ||
        word.suraNumber == 0 ||
        word.ayahNumber == 0) {
      return;
    }

    setState(() {
      _selectedWord = word;
    });

    playerCubit.setVerse(
      surahNumber: word.suraNumber!,
      verseNumber: word.ayahNumber!,
      fontFamily: 'UthmanicHafs',
      verse:
          "${getVerse(word.suraNumber!, word.ayahNumber!)} ${getVerseEndSymbol(word.ayahNumber!)}",
    );

    final themeState = context.read<ThemeCubit>().state;
    final bool isDark = widget.paperColorOverride != null
        ? widget.paperColorOverride!.computeLuminance() < 0.4
        : (themeState.mode == ThemeMode.dark);

    await showModalBottomSheet(
      context: context,
      barrierColor: Colors.black38,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BlocProvider.value(
          value: playerCubit,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: VerseBottomSheet(
                    isDarkOverride: isDark,
                    pageNumber: widget.pageNumber,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      playerCubit.hide();
      setState(() {
        _selectedWord = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(fontFamily: AppConsts.cairo),
        ),
      );
    }
    if (_isLoading) {
      return AppSkeleton.quranPage();
    }
    if (_pageLines == null || _pageLines!.isEmpty) {
      return const Center(
        child: Text(
          'No lines found for this page.',
          style: TextStyle(fontFamily: AppConsts.cairo),
        ),
      );
    }

    final playingVerse = context.select<VersePlayerCubit, VerseModel?>(
      (cubit) => cubit.state.currentVerse,
    );
    // Read the navigation-highlight coordinates set by Fehres / bookmarks.
    final navHighlightSurah = context.select<QuranCubit, int?>(
      (cubit) => cubit.state.highlightedSurah,
    );
    final navHighlightAyah = context.select<QuranCubit, int?>(
      (cubit) => cubit.state.highlightedAyah,
    );

    // Only trigger the auto-clear timer when the audio player UI is visible.
    final playerShowed = context.select<VersePlayerCubit, bool>(
      (cubit) => cubit.state.showed,
    );
    if (playingVerse != null && _selectedWord == null && playerShowed) {
      _scheduleHighlightClear();
    }
    // Schedule a clear for the nav highlight after 8 s so it doesn't stick.
    if (navHighlightSurah != null) {
      _bookmarkHighlightTimer?.cancel();
      _bookmarkHighlightTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) {
          context.read<QuranCubit>().clearHighlightedVerse();
        }
      });
    }
    final isPage1or2 = widget.pageNumber <= 2;

    // Robustly detect the primary surah for this page by searching all lines.
    int? detectedSurah;
    for (var line in _pageLines!) {
      // 1. Try the surah_number column from map_db.pages
      if (line.surahNumber != null && line.surahNumber != 0) {
        detectedSurah = line.surahNumber;
        break;
      }
      // 2. Try the first word's surah from the words table
      final words = _lineWordsMap[line.lineNumber];
      if (words != null && words.isNotEmpty) {
        for (var w in words) {
          if (w.suraNumber != null && w.suraNumber != 0) {
            detectedSurah = w.suraNumber;
            break;
          }
        }
        if (detectedSurah != null) break;
      }
    }

    int surahNum = detectedSurah ?? 1;
    int verseNum = 1;

    // Determine verseNum for the first available ayah line to help with Juz calculation
    final firstAyahLine = _pageLines!.firstWhere(
      (l) => l.lineType == 'ayah',
      orElse: () => _pageLines!.first,
    );
    if (_lineWordsMap.isNotEmpty &&
        _lineWordsMap[firstAyahLine.lineNumber]?.isNotEmpty == true) {
      verseNum = _lineWordsMap[firstAyahLine.lineNumber]!.first.ayahNumber ?? 1;
    }

    bool isWordInRange(int wSura, int wAyah) {
      if (widget.startSuraNumber == null ||
          widget.startAyah == null ||
          widget.endSuraNumber == null ||
          widget.endAyah == null) {
        return true;
      }
      int wordIndex = wSura * 1000 + wAyah;
      int startIndex = widget.startSuraNumber! * 1000 + widget.startAyah!;
      int endIndex = widget.endSuraNumber! * 1000 + widget.endAyah!;
      return wordIndex >= startIndex && wordIndex <= endIndex;
    }

    final themeState = context.watch<ThemeCubit>().state;
    final bool? hasDarkOverride = widget.paperColorOverride != null
        ? widget.paperColorOverride!.computeLuminance() < 0.5
        : null;
    final bool isDarkInner =
        hasDarkOverride ?? (themeState.mode == ThemeMode.dark);

    final quranThemeEarly = Theme.of(context).extension<QuranThemeColors>();
    final Color effectivePaperColor =
        widget.paperColorOverride ??
        (isDarkInner
            ? (quranThemeEarly?.paperColorDark ?? Colors.white)
            : (quranThemeEarly?.paperColorLight ?? Colors.white));
    final bool isDarkPaper = effectivePaperColor.computeLuminance() < 0.5;

    Color headerTextColor =
        widget.textColorOverride ?? (isDarkPaper ? Colors.white : Colors.black);

    final int juzNum = getJuzNumber(surahNum, verseNum == 0 ? 1 : verseNum);
    final bool isTablet = context.isTablet;
    final String hizbText = QuranHizbData.labelForPage(widget.pageNumber);
    final bool showHeaderBar = widget.showHeader && !isPage1or2;

    final headerBar = showHeaderBar
        ? Container(
            width: double.infinity,
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'surah${surahNum.toString().padLeft(3, '0')}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SurahNames',
                      color: headerTextColor,
                      fontSize: isTablet ? 36 : 32,
                      height: 0.7,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    hizbText,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: AppConsts.cairo,
                      color: headerTextColor.withAlpha(200),
                      fontSize: isTablet ? 18 : 10,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    'juz${juzNum.toString().padLeft(3, '0')}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFamily: AppConsts.quranCommon,
                      color: headerTextColor,
                      fontSize: isTablet ? 36 : 26,
                      height: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final bool isExporting = context.select<QuranCubit, bool>((c) => c.state.isExporting);
    final bool isMinimized = !widget.showHeader && !isPage1or2;

    final versesColumn = LayoutBuilder(builder: (context, constraints) {
      final bool hasBoundedHeightInner = constraints.hasBoundedHeight;
      
      return Column(
        mainAxisAlignment: isPage1or2
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: isPage1or2
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: List.generate(15, (i) {
          final lineNumber = i + 1;
          final PageLine? lineRule = _pageLines!
              .where((l) => l.lineNumber == lineNumber)
              .firstOrNull;

          if (lineRule == null) {
            return (isPage1or2 || widget.isLandscape || !hasBoundedHeightInner)
                ? const SizedBox.shrink()
                : const Expanded(child: SizedBox.shrink());
          }

          if (isPage1or2 && lineRule.lineType == 'ayah') {
            final lineWords = _lineWordsMap[lineNumber] ?? [];
            if (lineWords.isEmpty) return const SizedBox.shrink();
          }

          Widget lineContent;

          if (lineRule.lineType == 'surah_name') {
            int hSura = lineRule.surahNumber ?? 1;
            bool isVisible;
            if (widget.startSuraNumber == null || widget.endSuraNumber == null) {
              isVisible = true;
            } else {
              isVisible =
                  hSura >= widget.startSuraNumber! &&
                  hSura <= widget.endSuraNumber!;
            }
            Widget header = FullHeaderWidget(
              surahNumber: hSura,
              color: headerTextColor,
            );
            if (!isVisible) {
              if (widget.isSeamlessScroll) return const SizedBox.shrink();
              header = Opacity(opacity: 0.0, child: header);
            }

            header = FittedBox(fit: BoxFit.scaleDown, child: header);

            final double headerH = isPage1or2 
                ? (isMinimized ? 60.h : 85.h) 
                : (isMinimized ? 65.h : 90.h);

            lineContent = (widget.isLandscape || isPage1or2 || !hasBoundedHeightInner)
                ? SizedBox(
                    height: headerH,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: isPage1or2 ? 0.0 : 4.0,
                        top: isPage1or2 ? 2.0 : 4.0,
                      ),
                      child: header,
                    ),
                  )
                : header;
          } else if (lineRule.lineType == 'basmallah') {
            int bSura = lineRule.surahNumber ?? surahNum;
            bool isVisible;
            if (widget.startSuraNumber == null || widget.endSuraNumber == null) {
              isVisible = true;
            } else {
              // Fix: If we are in a specific range (Wird/Kahf), and this page is within 
              // that range, we should generally show the basmallah if it's there.
              isVisible = bSura >= widget.startSuraNumber! && bSura <= widget.endSuraNumber!;
              
              // Special case: if the page is inside the range, don't hide the basmallah
              // that introduces the surah.
              if (widget.pageNumber >= 1 && widget.pageNumber <= 604) {
                 isVisible = true; // Trust the database if the page is being rendered
              }
            }
            Widget basmallah = Basmallah(
              isFull: true,
              color: headerTextColor,
              widthMultiplier: isPage1or2
                  ? 0.70
                  : null, 
            );
            if (!isVisible) {
              if (widget.isSeamlessScroll) return const SizedBox.shrink();
              basmallah = Opacity(opacity: 0.0, child: basmallah);
            }

            final double basmallahH = isPage1or2 
                ? (isMinimized ? 30.h : 50.h) 
                : (isMinimized ? 42.h : 60.h);

            lineContent = (widget.isLandscape || isPage1or2 || !hasBoundedHeightInner)
                ? SizedBox(
                    height: basmallahH,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isPage1or2 ? 0.0 : 4.0,
                      ),
                      child: FittedBox(fit: BoxFit.contain, child: basmallah),
                    ),
                  )
                : FittedBox(fit: BoxFit.contain, child: basmallah);
          } else {
            final lineWords = _lineWordsMap[lineNumber] ?? [];
            if (widget.isSeamlessScroll) {
              bool hasVisibleWord = false;
              for (var w in lineWords) {
                int currentWSura = w.suraNumber ?? surahNum;
                int currentWAyah = w.ayahNumber ?? 0;
                if (isWordInRange(currentWSura, currentWAyah)) {
                  hasVisibleWord = true;
                  break;
                }
              }
              if (!hasVisibleWord) {
                return (isPage1or2 || !hasBoundedHeightInner) ? const SizedBox.shrink() : const Expanded(child: SizedBox.shrink());
              }
            }
            final PageLine? nextLineRule = _pageLines!
                .where((l) => l.lineNumber == lineNumber + 1)
                .firstOrNull;

            final bool isLastLineOfSurah =
                nextLineRule != null &&
                (nextLineRule.lineType == 'surah_name' ||
                    (nextLineRule.surahNumber != null &&
                        lineRule.surahNumber != null &&
                        nextLineRule.surahNumber! > lineRule.surahNumber!));

          final bool shouldCenter =
              isPage1or2 || lineRule.isCentered || isLastLineOfSurah;

          final double canvasFontSize = isPage1or2
              ? (context.isTablet ? 90.0 : (isExporting ? 48.0 : 42.0))
              : (isExporting ? 110.0 : 125.0);

          bool lineHasVisibleContent = true;
          if (widget.startSuraNumber != null) {
            if (lineRule.lineType == 'surah_name') {
              final int s = lineRule.surahNumber ?? surahNum;
              lineHasVisibleContent = s >= widget.startSuraNumber! && s <= (widget.endSuraNumber ?? s);
            } else if (lineRule.lineType == 'basmallah') {
              final int s = lineRule.surahNumber ?? surahNum;
              lineHasVisibleContent = s >= widget.startSuraNumber! && s <= (widget.endSuraNumber ?? s);
            } else {
              final words = _lineWordsMap[lineNumber] ?? [];
              lineHasVisibleContent = words.any((w) => isWordInRange(w.suraNumber ?? surahNum, w.ayahNumber ?? 0));
            }
          }

          if (isExporting && !lineHasVisibleContent) {
            return const SizedBox.shrink();
          }

          Widget row = Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisSize: shouldCenter
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  mainAxisAlignment: shouldCenter
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: () {
                    final List<Widget> rowChildren = [];
                    for (int wIdx = 0; wIdx < lineWords.length; wIdx++) {
                      final word = lineWords[wIdx];

                      final bool isHighlighted =
                          (playingVerse != null &&
                              playingVerse.surahNumber == word.suraNumber &&
                              playingVerse.verseNumber == word.ayahNumber) ||
                          (_selectedWord != null &&
                              _selectedWord!.suraNumber == word.suraNumber &&
                              _selectedWord!.ayahNumber == word.ayahNumber) ||
                          (navHighlightSurah != null &&
                              navHighlightAyah != null &&
                              word.suraNumber == navHighlightSurah &&
                              word.ayahNumber == navHighlightAyah);

                      int currentWSura = word.suraNumber ?? surahNum;
                      int currentWAyah = word.ayahNumber ?? 0;
                      bool isVisible = isWordInRange(currentWSura, currentWAyah);

                      Color textColor =
                          widget.textColorOverride ??
                          (isDarkPaper ? Colors.white : Colors.black);

                      if (!isVisible) textColor = Colors.transparent;

                      bool isLastWordOfAyah = false;
                      if (currentWAyah != 0) {
                        if (wIdx < lineWords.length - 1) {
                          if (lineWords[wIdx + 1].ayahNumber != currentWAyah) {
                            isLastWordOfAyah = true;
                          }
                        } else {
                          final nextLineWords = _lineWordsMap[lineNumber + 1];
                          if (nextLineWords != null && nextLineWords.isNotEmpty) {
                            if (nextLineWords.first.ayahNumber != currentWAyah) {
                              isLastWordOfAyah = true;
                            }
                          } else {
                            isLastWordOfAyah = true;
                          }
                        }
                      }

                      if (isLastWordOfAyah) {
                        final double sizeMultiplier = isPage1or2 ? 1.20 : 2.0;
                        final double fontMultiplier = isPage1or2 ? 0.40 : 0.45;

                        final double markerSize = canvasFontSize * sizeMultiplier;
                        final double markerFontSize =
                            canvasFontSize * fontMultiplier;

                        Widget marker = Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: AyahMarkerWidget(
                            ayahNumber: currentWAyah,
                            size: markerSize,
                            fontSize: markerFontSize,
                            numberColor: isDarkPaper
                                ? const Color(0xFFFFF8E1)
                                : const Color(0xFF3E2723),
                          ),
                        );
                        if (!isVisible) {
                          marker = Opacity(opacity: 0.0, child: marker);
                        }
                        rowChildren.add(marker);
                      } else {
                        if (word.text.trim().isNotEmpty) {
                          rowChildren.add(
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onLongPress: () {
                                if (isVisible) {
                                  _onWordLongPressed(
                                    context,
                                    context.read<VersePlayerCubit>(),
                                    word,
                                  );
                                }
                              },
                              child: Container(
                                color: isHighlighted && isVisible
                                    ? AppColors.lime.withAlpha(128)
                                    : Colors.transparent,
                                child: Text(
                                  word.text,
                                  style: const TextStyle(height: 1.0).copyWith(
                                    fontFamily: _fontFamily,
                                    fontSize: canvasFontSize,
                                    color: textColor,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    }
                    return rowChildren;
                  }(),
                ),
              ),
            );

            if (isPage1or2) {
              lineContent = Padding(
                padding: EdgeInsets.symmetric(
                  vertical: widget.pageNumber == 2 ? 8.0 : 8.0,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  child: row,
                ),
              );
            } else {
              lineContent = LayoutBuilder(
                builder: (ctx, lc) {
                  final double w = lc.maxWidth.isFinite ? lc.maxWidth : 1000.0;
                  return FittedBox(
                    fit: shouldCenter ? BoxFit.scaleDown : BoxFit.fitWidth,
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: w),
                      child: row,
                    ),
                  );
                },
              );
            }
          }

          Widget result = lineContent;
          if (!isPage1or2 && hasBoundedHeightInner) {
            result = Expanded(child: result);
          }
          return result;
        }),
      );
    });

    final pageContent = LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth  = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight > 0 ? constraints.maxHeight : MediaQuery.of(context).size.height;
        final bool hasBoundedHeight = constraints.hasBoundedHeight;
        final bool isTablet = context.isTablet;

        // On tablet: use full available width; on phone: cap at 650 logical pixels
        final double maxWidthAllowed = isTablet
            ? screenWidth
            : (widget.isLandscape ? screenWidth : 650.0);
        final double baseWidth = screenWidth > maxWidthAllowed ? maxWidthAllowed : screenWidth;

        // On tablet, the margin slider is the ONLY padding — no extra sidePadding
        final double sidePadding = screenWidth > maxWidthAllowed
            ? ((screenWidth - maxWidthAllowed) / 2)
            : (widget.isLandscape ? 0.0 : (isTablet ? 0.0 : 2.0));

        final double margin = context.select<QuranCubit, double>((c) => c.state.quranPageMargin);

        Widget textColumnWithMargin = Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: versesColumn,
        );

        // On tablet: use the actual screen aspect ratio so the FittedBox doesn't
        // shrink the text trying to fit an arbitrary 1.95 multiplier that was
        // designed for phone portrait dimensions.
        final double pageAspectHeight = isTablet
            ? (hasBoundedHeight && screenHeight > 0 ? screenHeight : baseWidth * 1.42)
            : baseWidth * 1.95;

        Widget innerContentWithoutMargin = Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: hasBoundedHeight
              ? FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: baseWidth,
                    height: isPage1or2 ? null : pageAspectHeight,
                    child: isPage1or2
                        ? Center(child: textColumnWithMargin)
                        : textColumnWithMargin,
                  ),
                )
              : SizedBox(
                  width: baseWidth,
                  child: isPage1or2
                      ? Center(child: textColumnWithMargin)
                      : textColumnWithMargin,
                ),
        );

        if (isExporting) {
          final bool hasRange = widget.startSuraNumber != null;
          if (hasRange) return Center(child: innerContentWithoutMargin);
          return Center(
            child: AspectRatio(
              aspectRatio: 1 / 1.72,
              child: innerContentWithoutMargin,
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: innerContentWithoutMargin,
        );
      },
    );

    final String prefix = widget.isSeamlessScroll ? 'vertical' : (widget.showHeader ? 'mushaf' : 'min');
    final repaintKey = context.read<QuranCubit>().getPageKey(widget.pageNumber, contextPrefix: prefix);

    return RepaintBoundary(
      key: repaintKey,
      child: ColoredBox(
        color: effectivePaperColor,
        child: LayoutBuilder(
          builder: (context, outerConstraints) {
            final double screenWidth = outerConstraints.maxWidth;

            return LayoutBuilder(
              builder: (context, middleConstraints) {
                Widget topBarWidget = widget.showHeader
                    ? SafeArea(
                        top: true, // Restored to prevent camera overlap in fullscreen mode
                        bottom: false,
                        child: !isPage1or2
                            ? headerBar
                            : const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink();

                Widget fullContent;
                if (widget.isLandscape && !widget.isSeamlessScroll) {
                  fullContent = SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showHeader) topBarWidget,
                        SizedBox(
                          height: screenWidth * (isPage1or2 ? 1.95 : 1.95), // Fixed height for page 1 & 2
                          child: pageContent,
                        ),
                        if (widget.showPageNumber)
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Align(
                                alignment: widget.pageNumber.isOdd
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Container(
                                    width: 90,
                                    height: 25,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      image: DecorationImage(
                                        image: AssetImage('assets/images/page_numpers.png'),
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                    child: Text(
                                      widget.pageNumber.toArabicNums,
                                      style: const TextStyle(
                                        color: Color(0xFF3E2723),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                } else {
                  fullContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: isPage1or2 ? MainAxisAlignment.center : MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (widget.showHeader) topBarWidget,
                      Expanded(
                        child: isPage1or2 
                          ? Center(child: pageContent)
                          : pageContent,
                      ), 
                      if (widget.showPageNumber)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Align(
                              alignment: widget.pageNumber.isOdd
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Container(
                                  width: 90,
                                  height: 25,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage('assets/images/page_numpers.png'),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  child: Text(
                                    widget.pageNumber.toArabicNums,
                                    style: const TextStyle(
                                      color: Color(0xFF3E2723),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }

                return InteractiveViewer(
                  transformationController: _transformationController,
                  panEnabled: widget.isZoomEnabled && _isZoomed,
                  scaleEnabled: widget.isZoomEnabled,
                  minScale: 1.0,
                  maxScale: widget.isZoomEnabled ? 3.5 : 1.0,
                  onInteractionUpdate: (details) {
                    if (details.scale != 1.0 && !_isZoomed) {
                      setState(() => _isZoomed = true);
                    }
                  },
                  onInteractionEnd: (details) {
                    if (_transformationController.value.getMaxScaleOnAxis() <=
                        1.0) {
                      setState(() => _isZoomed = false);
                    }
                  },
                  child: fullContent,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
