import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import '../../data/quran_word.dart';
import '../../data/models/page_line.dart';
import '../../data/db_helper.dart';
import '../../bloc/quran/quran_cubit.dart';
import '../../bloc/verse_player/verse_player_cubit.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/helpers/extensions/int_extensions.dart';
import 'verse_overlay_widget.dart';
import 'header_widget.dart';
import 'basmallah.dart';
import '../../../../core/helpers/extensions/screen_details.dart';
import '../../../../core/theme/theme_manager/theme_cubit.dart';
import '../../../../core/theme/quran_theme_extension.dart';
import '../../../../core/helpers/fonts_helper.dart';

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
  });

  @override
  State<WbwPageWidget> createState() => _WbwPageWidgetState();
}

class _WbwPageWidgetState extends State<WbwPageWidget> {
  List<PageLine>? _pageLines;
  Map<int, List<QuranWord>> _lineWordsMap = {};
  String? _error;
  QuranWord? _selectedWord;
  String? _fontFamily;
  bool _isLoading = true; // Gets overridden synchronously if cache hits
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  Timer? _bookmarkHighlightTimer;

  @override
  void initState() {
    super.initState();
    _fontFamily = FontsHelper.getFontFamily(widget.pageNumber);
    _loadLinesAndWords();
    _scrollController.addListener(_onScroll);
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
    _bookmarkHighlightTimer?.cancel();
    super.dispose();
  }

  void _loadLinesAndWords() {
    final cachedLines = QuranWbwDbHelper.instance.getPageLinesSync(widget.pageNumber);
    final cachedWords = QuranWbwDbHelper.instance.getPageWordsSync(widget.pageNumber);
    final isFontLoaded = FontsHelper.isFontLoaded(_fontFamily!);

    if (cachedLines != null && cachedWords != null && isFontLoaded) {
      // Sync fast path! Zero-latency rendering. No loading spinner.
      _pageLines = cachedLines;
      
      final Map<int, List<QuranWord>> lineMap = {};
      for (var word in cachedWords) {
        final ln = word.lineNumber ?? 1;
        lineMap.putIfAbsent(ln, () => []).add(word);
      }
      _lineWordsMap = lineMap;
      _isLoading = false;
      return; // Return immediately, no async gaps
    }

    // Async slow path
    _isLoading = true;
    _fetchAsync();
  }

  Future<void> _fetchAsync() async {
    try {
      await Future.wait([
        FontsHelper.loadFontFromFamily(_fontFamily!),
        _fetchDbData(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        final playerCubit = context.read<VersePlayerCubit>();
        // Only clear the highlight if the audio player is not explicitly shown
        if (!playerCubit.state.showed) {
          playerCubit.hide();
        }
        setState(() {
          _selectedWord = null;
        });
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

    await showModalBottomSheet(
      barrierColor: Colors.black38,
      useSafeArea: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BlocProvider.value(
          value: playerCubit,
          child: const SafeArea(child: VerseBottomSheet()),
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
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pageLines == null || _pageLines!.isEmpty) {
      return const Center(child: Text('No lines found for this page.'));
    }

    final playerCubit = context.watch<VersePlayerCubit>();
    final playingVerse = playerCubit.currnetVerse;

    if (playingVerse != null && _selectedWord == null) {
      _scheduleHighlightClear();
    }
    final isPage1or2 = widget.pageNumber <= 2;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final firstAyahLine = _pageLines!.firstWhere(
      (l) => l.lineType == 'ayah',
      orElse: () => _pageLines!.first,
    );
    int surahNum = firstAyahLine.surahNumber ?? 1;
    int verseNum = 1;

    if (_lineWordsMap.isNotEmpty &&
        _lineWordsMap[firstAyahLine.lineNumber]?.isNotEmpty == true) {
      surahNum =
          _lineWordsMap[firstAyahLine.lineNumber]!.first.suraNumber ?? surahNum;
      verseNum = _lineWordsMap[firstAyahLine.lineNumber]!.first.ayahNumber ?? 1;
    } else if (firstAyahLine.lineType == 'surah_name') {
      surahNum = firstAyahLine.surahNumber ?? 1;
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
    final isDarkInner = themeState.mode == ThemeMode.dark;
    Color headerTextColor =
        widget.textColorOverride ?? (isDarkInner ? Colors.white : Colors.black);

    final int juzNum = getJuzNumber(surahNum, verseNum == 0 ? 1 : verseNum);
    final int hizbQ = (juzNum - 1) * 2 + 1;

    final bool isTablet = context.isTablet;

    final headerBar = (widget.showHeader && !isPage1or2)
        ? Container(
            height: isTablet ? 48 : 30,
            width: double.infinity,
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 16,
              vertical: isTablet ? 4 : 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${juzNum.toJuzName} - الحزب $hizbQ',
                      style: TextStyle(
                        color: headerTextColor,
                        fontSize: isTablet ? 22 : 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppConsts.cairo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "سورة ${getSurahNameArabic(surahNum)}",
                      style: TextStyle(
                        color: headerTextColor,
                        fontSize: isTablet ? 22 : 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppConsts.cairo,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final versesColumn = Column(
      mainAxisAlignment: (isLandscape || isPage1or2)
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceEvenly,
      mainAxisSize: (isLandscape || isPage1or2)
          ? MainAxisSize.min
          : MainAxisSize.max,
      crossAxisAlignment: isPage1or2
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: List.generate(15, (i) {
        final lineNumber = i + 1;
        final PageLine? lineRule = _pageLines!
            .where((l) => l.lineNumber == lineNumber)
            .firstOrNull;

        if (lineRule == null) {
          return (isPage1or2 || isLandscape)
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
          bool isVisible = isWordInRange(hSura, 0);
          Widget header = FullHeaderWidget(
            surahNumber: hSura,
            color: headerTextColor,
          );
          if (!isVisible) header = Opacity(opacity: 0.0, child: header);

          // FIX 1: Wrap header in FittedBox to stop 85px overflow on Tablets
          header = FittedBox(fit: BoxFit.scaleDown, child: header);

          lineContent = (isLandscape || isPage1or2)
              ? SizedBox(
                  height: isPage1or2 ? 90.h : null,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: isPage1or2 ? 8.0 : 4.0,
                      top: isPage1or2 ? 10.0 : 4.0,
                    ),
                    child: header,
                  ),
                )
              : Expanded(child: header);
        } else if (lineRule.lineType == 'basmallah') {
          int bSura = lineRule.surahNumber ?? surahNum;
          bool isVisible = isWordInRange(bSura, 0);
          Widget basmallah = Basmallah(isFull: true, color: headerTextColor);
          if (!isVisible) basmallah = Opacity(opacity: 0.0, child: basmallah);

          lineContent = (isLandscape || isPage1or2)
              ? SizedBox(
                  height: isPage1or2 ? 40.h : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isPage1or2 ? 8.0 : 4.0,
                    ),
                    child: FittedBox(fit: BoxFit.contain, child: basmallah),
                  ),
                )
              : Expanded(
                  child: FittedBox(fit: BoxFit.contain, child: basmallah),
                );
        } else {
          final lineWords = _lineWordsMap[lineNumber] ?? [];
          final double canvasFontSize = isPage1or2 ? 28.0 : 82.0;

          // FIX 2: Add horizontal padding inside the row to give Arabic tails room to breathe
          Widget row = Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisSize: isPage1or2 ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: isPage1or2
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: lineWords.map<Widget>((word) {
                  final bool isHighlighted =
                      (playingVerse != null &&
                          playingVerse.surahNumber == word.suraNumber &&
                          playingVerse.verseNumber == word.ayahNumber) ||
                      (_selectedWord != null &&
                          _selectedWord!.suraNumber == word.suraNumber &&
                          _selectedWord!.ayahNumber == word.ayahNumber &&
                          _selectedWord!.wordId == word.wordId);

                  int currentWSura = word.suraNumber ?? surahNum;
                  int currentWAyah = word.ayahNumber ?? 0;
                  bool isVisible = isWordInRange(currentWSura, currentWAyah);

                  Color textColor =
                      widget.textColorOverride ??
                      (isDarkInner ? Colors.white : Colors.black);

                  if (!isVisible) textColor = Colors.transparent;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () {
                      if (isVisible) {
                        _onWordLongPressed(context, playerCubit, word);
                      }
                    },
                    child: Container(
                      color: isHighlighted && isVisible
                          ? AppColors.lime.withAlpha(120)
                          : Colors.transparent,
                      child: Text(
                        word.text,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: canvasFontSize,
                          color: textColor,
                          height: 1.0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );

          // FIX 3: Apply clipBehavior: Clip.none to all FittedBoxes to stop cutting the tails
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
          } else if (isLandscape) {
            lineContent = Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                child: row,
              ),
            );
          } else {
            lineContent = Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                child: row,
              ),
            );
          }
        }

        return lineContent;
      }),
    );

    final pageContent = LayoutBuilder(
      builder: (context, constraints) {
        final bool hasBoundedHeight = constraints.hasBoundedHeight;
        final double screenWidth = constraints.maxWidth;
        // On tablets, let content fill full width (min layout already constrains via its Container).
        // On mobile, cap at 650 to prevent over-stretching.
        final double maxWidthAllowed = context.isTablet ? screenWidth : 650.0;
        final double contentWidth = screenWidth > maxWidthAllowed ? maxWidthAllowed : screenWidth;
        final double sidePadding = screenWidth > maxWidthAllowed ? (screenWidth - maxWidthAllowed) / 2 : 6.0;

        return Container(
          width: double.infinity,
          // Add extra top padding if we're on tablet and using a custom overlay header
          padding: EdgeInsets.only(
            top: (!widget.showHeader && context.isTablet) ? 150.0 : 5.0,
            bottom: 5.0,
            left: sidePadding,
            right: sidePadding,
          ),
          child: (isPage1or2 && hasBoundedHeight)
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  child: SizedBox(width: contentWidth, child: versesColumn),
                )
              : versesColumn,
        );
      },
    );

    final bool isOddPage = widget.pageNumber.isOdd;

    final pageNumberFrameWidget = Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/Gold-Decorative-Ornamental-Round-Frame.webp',
          width: 55,
          height: 55,
          fit: BoxFit.contain,
        ),
        Text(
          widget.pageNumber.toArabicNums,
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD3AD73),
          ),
        ),
      ],
    );

    final quranTheme = Theme.of(context).extension<QuranThemeColors>();
    final paperColor =
        widget.paperColorOverride ??
        (isDarkInner
            ? (quranTheme?.paperColorDark ?? Colors.black)
            : (quranTheme?.paperColorLight ?? const Color(0xfffffdf5)));

    final bool isActuallyDark = paperColor.computeLuminance() < 0.4;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: paperColor,
        statusBarIconBrightness: isActuallyDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: paperColor,
        systemNavigationBarIconBrightness: isActuallyDark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isActuallyDark
            ? Brightness.dark
            : Brightness.light,
      ),
    );

    final repaintKey = context.read<QuranCubit>().getPageKey(widget.pageNumber);

    return RepaintBoundary(
      key: repaintKey,
      child: ColoredBox(
        color: paperColor,
        child: LayoutBuilder(
          builder: (context, outerConstraints) {
            final double screenWidth = outerConstraints.maxWidth;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(bottom: false, child: headerBar),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, middleConstraints) {
                      final double contentHeight = isLandscape
                          ? (screenWidth * 1.5)
                          : middleConstraints.maxHeight;

                      Widget middleContent = SizedBox(
                        width: middleConstraints.maxWidth,
                        height: contentHeight,
                        child: pageContent,
                      );

                      if (isLandscape) {
                        middleContent = SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          child: middleContent,
                        );
                      }

                      return InteractiveViewer(
                        panEnabled: widget.isZoomEnabled,
                        scaleEnabled: widget.isZoomEnabled,
                        minScale: 1.0,
                        maxScale: widget.isZoomEnabled ? 3.5 : 1.0,
                        child: middleContent,
                      );
                    },
                  ),
                ),
                if (widget.showPageNumber)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: isOddPage
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: pageNumberFrameWidget,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}