import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
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
import '../../../../core/theme/theme_manager/theme_cubit.dart';
import '../../../../core/helpers/fonts_helper.dart';

class WbwPageWidget extends StatefulWidget {
  final int pageNumber;
  final bool isZoomEnabled;
  final int? startSuraNumber;
  final int? startAyah;
  final int? endSuraNumber;
  final int? endAyah;
  final bool showHeader;
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
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  static const String _longPressHintKey = 'long_press_hint_shown';

  @override
  void initState() {
    super.initState();
    _fontFamily = FontsHelper.getFontFamily(widget.pageNumber);
    _loadLinesAndWords();
    _scrollController.addListener(_onScroll);
    _showLongPressHint();
  }

  void _showLongPressHint() {
    final alreadyShown =
        getIt<CacheService>().getBool(_longPressHintKey) ?? false;
    if (alreadyShown) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تلميح: اضغط مطولاً على الآية لعرض خيارات التفسير والمشاركة',
            style: TextStyle(fontFamily: 'cairo'),
          ),
          duration: Duration(seconds: 4),
        ),
      );
      getIt<CacheService>().setBool(_longPressHintKey, true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Check if user has scrolled near to the bottom
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
    super.dispose();
  }

  Future<void> _loadLinesAndWords() async {
    try {
      // Load font and data in parallel
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

    // After the bottom sheet (and any nested sheets) are closed:
    // Clear the highlight and stop playback.
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

    final isDark = context.watch<ThemeCubit>().state.mode == ThemeMode.dark;
    Color headerTextColor =
        widget.textColorOverride ?? (isDark ? Colors.white : Colors.black);

    final int juzNum = getJuzNumber(surahNum, verseNum == 0 ? 1 : verseNum);
    final int hizbQ = (juzNum - 1) * 2 + 1;

    final headerBar = (widget.showHeader && !isPage1or2)
        ? Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight, // Stick to the right edge
                    child: Text(
                      '${juzNum.toJuzName} - الحزب $hizbQ',
                      style: TextStyle(
                        color: headerTextColor,
                        fontSize: 12,
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
                    alignment: Alignment.centerLeft, // Stick to the left edge
                    child: Text(
                      "سورة ${getSurahNameArabic(surahNum)}",
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: headerTextColor,
                        fontSize: 12,
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
      mainAxisAlignment: (isLandscape)
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceEvenly,
      mainAxisSize: (isLandscape) ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(15, (i) {
        final lineNumber = i + 1;
        final PageLine? lineRule = _pageLines!
            .where((l) => l.lineNumber == lineNumber)
            .firstOrNull;

        if (lineRule == null) {
          return (isLandscape)
              ? const SizedBox.shrink()
              : const Expanded(child: SizedBox.shrink());
        }

        if (lineRule.lineType == 'surah_name') {
          int hSura = lineRule.surahNumber ?? 1;
          bool isVisible = isWordInRange(hSura, 0);
          Widget header = FullHeaderWidget(
            surahNumber: hSura,
            color: widget.textColorOverride,
          );
          if (!isVisible) header = Opacity(opacity: 0.0, child: header);

          return (isLandscape) ? header : Expanded(child: header);
        }

        if (lineRule.lineType == 'basmallah') {
          int bSura = lineRule.surahNumber ?? surahNum;
          bool isVisible = isWordInRange(bSura, 0);
          Widget basmallah = Basmallah(
            isFull: true,
            color: widget.textColorOverride,
          );
          if (!isVisible) basmallah = Opacity(opacity: 0.0, child: basmallah);

          return (isLandscape)
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: FittedBox(fit: BoxFit.scaleDown, child: basmallah),
                )
              : Expanded(
                  child: FittedBox(fit: BoxFit.scaleDown, child: basmallah),
                );
        }

        final lineWords = _lineWordsMap[lineNumber] ?? [];
        if (lineWords.isEmpty && lineRule.lineType == 'ayah') {
          return isLandscape
              ? const SizedBox.shrink()
              : const Expanded(child: SizedBox.shrink());
        }

        bool isCentered = lineRule.isCentered || isPage1or2;
        final double canvasFontSize = isPage1or2 ? 88.0 : 82.0;

        Widget lineContent = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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

                  final isDarkInner =
                      context.watch<ThemeCubit>().state.mode == ThemeMode.dark;
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
          ),
        );

        if (isLandscape) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: lineContent,
          );
        }
        return Expanded(child: lineContent);
      }),
    );

    final pageContent = LayoutBuilder(
      builder: (context, constraints) {
        final bool hasBoundedHeight = constraints.hasBoundedHeight;
        return Padding(
          padding: EdgeInsets.only(
            top: widget.pageNumber <= 2 ? 35.0 : 8.0,
            bottom: 52.0,
            left: widget.pageNumber <= 2 ? 24.0 : 12.0,
            right: widget.pageNumber <= 2 ? 24.0 : 12.0,
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: hasBoundedHeight ? constraints.maxHeight : null,
            child: versesColumn,
          ),
        );
      },
    );

    final bool isOddPage = widget.pageNumber.isOdd;

    final pageNumberFrameWidget = Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/Gold-Decorative-Ornamental-Round-Frame.webp',
          width: 55, // Smaller frame
          height: 55, // Smaller frame
          fit: BoxFit.scaleDown,
        ),
        Text(
          widget.pageNumber.toArabicNums,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 14, // Adjusted for smaller frame
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD3AD73),
          ),
        ),
      ],
    );

    // Apply status bar style based on paper color
    final isDarkState =
        context.watch<ThemeCubit>().state.mode == ThemeMode.dark;
    final paperColor =
        widget.paperColorOverride ??
        (isDarkState ? Colors.black : const Color(0xfffffdf5));

    // Determine brightness based on paperColor luminance
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

    // Get the RepaintBoundary key from the cubit for HD capture
    final repaintKey = context.read<QuranCubit>().getPageKey(widget.pageNumber);

    // Main layout logic
    if (isLandscape) {
      return RepaintBoundary(
        key: repaintKey,
        child: ColoredBox(
          color: paperColor,
          child: Container(
            color: paperColor,
            child: Column(
              children: [
                SafeArea(bottom: false, child: headerBar),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: InteractiveViewer(
                      panEnabled: widget.isZoomEnabled,
                      scaleEnabled: widget.isZoomEnabled,
                      minScale: 1.0,
                      maxScale: widget.isZoomEnabled ? 3.5 : 1.0,
                      child: pageContent,
                    ),
                  ),
                ),
                // Fixed bottom bar for page number, only visible at the bottom
                if (_isAtBottom)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: isOddPage
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [pageNumberFrameWidget],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      key: repaintKey,
      child: ColoredBox(
        color: paperColor,
        child: Container(
          color: paperColor,
          child: Stack(
            children: [
              Column(
                children: [
                  SafeArea(bottom: false, child: headerBar),
                  Expanded(
                    child: InteractiveViewer(
                      panEnabled: widget.isZoomEnabled,
                      scaleEnabled: widget.isZoomEnabled,
                      minScale: 1.0,
                      maxScale: widget.isZoomEnabled ? 3.5 : 1.0,
                      child: pageContent,
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 5,
                left: isOddPage ? null : 10,
                right: isOddPage ? 10 : null,
                child: SafeArea(child: pageNumberFrameWidget),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
