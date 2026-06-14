import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';

import '../../../../core/helpers/extensions/int_extensions.dart';
import '../widgets/components/basmallah.dart';
import '../widgets/components/header_widget.dart';
import '../widgets/menus/verse_overlay_widget.dart';
import '../../bloc/verse_player/verse_player_cubit.dart';
import '../../data/quran_word.dart';
import '../../data/db_helper.dart';

class TabletSurahVersesWidget extends StatefulWidget {
  final int pageNumber;
  final String? highlightedVerse;
  final String family;
  final double fontSize;
  final bool isFullPage;

  const TabletSurahVersesWidget({
    super.key,
    required this.pageNumber,
    required this.family,
    required this.fontSize,
    this.isFullPage = false,
    this.highlightedVerse,
  });

  @override
  State<TabletSurahVersesWidget> createState() =>
      _TabletSurahVersesWidgetState();
}

class _TabletSurahVersesWidgetState extends State<TabletSurahVersesWidget> {
  late VersePlayerCubit cubit;
  Timer? _initialHighlightTimer;
  bool _highlightSetByLongPress = false;
  bool _usePropHighlight = false;
  late Future<List<QuranWord>> _wordsFuture;

  @override
  void initState() {
    cubit = context.read<VersePlayerCubit>();
    super.initState();
    _wordsFuture = QuranWbwDbHelper.instance.getPageWords(widget.pageNumber);
    // Initialize the selected verse from highlightedVerse if provided
    selectedVerse = widget.highlightedVerse ?? '';
    // Auto-clear only the initial highlight after 1 second
    _usePropHighlight = (widget.highlightedVerse ?? '').isNotEmpty;
    if (selectedVerse.isNotEmpty) {
      _initialHighlightTimer?.cancel();
      _initialHighlightTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_highlightSetByLongPress) {
          return; // do not clear if user long-pressed
        }
        setState(() {
          selectedVerse = '';
          _usePropHighlight = false;
        });
      });
    }
  }

  late String selectedVerse = widget.highlightedVerse ?? '';

  bool _isHighlighted(QuranWord word) {
    if (selectedVerse.isEmpty &&
        (!_usePropHighlight || (widget.highlightedVerse ?? '').isEmpty)) {
      return false;
    }

    final playingVerse = cubit.state.currentVerse;
    if (playingVerse != null &&
        playingVerse.surahNumber == word.suraNumber &&
        playingVerse.verseNumber == word.ayahNumber) {
      return true;
    }

    if (selectedVerse.isNotEmpty && word.text.contains(selectedVerse)) {
      return true;
    }

    return false;
  }

  @override
  void didUpdateWidget(covariant TabletSurahVersesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _wordsFuture = QuranWbwDbHelper.instance.getPageWords(widget.pageNumber);
    }
    if (oldWidget.highlightedVerse != widget.highlightedVerse &&
        widget.highlightedVerse != null &&
        widget.highlightedVerse!.isNotEmpty) {
      setState(() {
        selectedVerse = widget.highlightedVerse!;
        _usePropHighlight = true;
      });
      // Restart the auto-clear timer for new incoming highlight
      _initialHighlightTimer?.cancel();
      _initialHighlightTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_highlightSetByLongPress) return;
        setState(() {
          selectedVerse = '';
          _usePropHighlight = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _initialHighlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return FutureBuilder<List<QuranWord>>(
      future: _wordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final words = snapshot.data!;
        final Map<int, List<QuranWord>> lineMap = {};
        for (var word in words) {
          final ln = word.lineNumber ?? 1;
          lineMap.putIfAbsent(ln, () => []).add(word);
        }

        final double height = (widget.pageNumber == 1 || widget.pageNumber == 2)
            ? 2
            : widget.isFullPage
            ? 1.768
            : 1.78;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 25),
            ...List.generate(15, (index) {
              final lineNumber = index + 1;
              final lineWords = lineMap[lineNumber];
              if (lineWords == null || lineWords.isEmpty) {
                return const SizedBox.shrink();
              }

              final firstWord = lineWords.first;
              if (firstWord.lineType == 'surah_name') {
                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: widget.isFullPage
                        ? FullHeaderWidget(
                            surahNumber: firstWord.headerSurah ?? 1,
                          )
                        : MinHeaderWidget(
                            surahNumber: firstWord.headerSurah ?? 1,
                          ),
                  ),
                );
              } else if (firstWord.lineType == 'basmallah') {
                return Center(
                  child: TabletBasmallah(isFull: widget.isFullPage),
                );
              }

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisAlignment:
                      (firstWord.isCentered ?? false || widget.pageNumber <= 2)
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: lineWords.map((word) {
                    final isHighlighted = _isHighlighted(word);
                    return GestureDetector(
                      onLongPress: () {
                        if (word.suraNumber == null || word.ayahNumber == null) {
                          return;
                        }
                        _highlightSetByLongPress = true;
                        _initialHighlightTimer?.cancel();
                        setState(() {
                          _usePropHighlight = false;
                        });

                        cubit.setVerse(
                          surahNumber: word.suraNumber!,
                          verseNumber: word.ayahNumber!,
                          fontFamily: widget.family,
                          verse: getVerseQCF(
                            word.suraNumber!,
                            word.ayahNumber!,
                          ),
                        );

                        showDialog(
                          barrierColor: Colors.black38,
                          context: context,
                          builder: (context) {
                            return BlocProvider.value(
                              value: cubit,
                              child: Center(
                                child: Material(
                                  color: Colors.transparent,
                                  child: VerseBottomSheet(
                                    isDarkOverride: isDark,
                                    pageNumber: widget.pageNumber,
                                  ),
                                ),
                              ),
                            );
                          },
                        ).then((_) {
                          if (mounted) setState(() => selectedVerse = '');
                        });
                      },
                      child: Container(
                        color: isHighlighted
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.3)
                            : Colors.transparent,
                        child: Text(
                          word.text,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: widget.family,
                            fontSize: widget.fontSize,
                            height: height,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
            if (widget.pageNumber > 2)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/page_numpers.png',
                        width: 85,
                        fit: BoxFit.contain,
                      ),
                      Text(
                        widget.pageNumber.toArabicNums,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: widget.isFullPage ? 15 : 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3E2723),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
