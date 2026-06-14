import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

import '../../../../core/helpers/extensions/app_navigator.dart';
import '../../../../core/helpers/extensions/screen_details.dart';
import '../widgets/components/basmallah.dart';
import '../widgets/components/header_widget.dart';
import '../widgets/menus/verse_overlay_widget.dart';
import '../../data/quran_word.dart';
import '../../data/db_helper.dart';

class MobileSurahVersesWidget extends StatefulWidget {
  final int pageNumber;
  final String? highlightedVerse;
  final String family;
  final double fontSize;
  final bool isFullPage;

  const MobileSurahVersesWidget({
    super.key,
    required this.pageNumber,
    required this.family,
    required this.fontSize,
    this.isFullPage = false,
    this.highlightedVerse,
  });

  @override
  State<MobileSurahVersesWidget> createState() =>
      _MobileSurahVersesWidgetState();
}

class _MobileSurahVersesWidgetState extends State<MobileSurahVersesWidget> {
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

    // If the word represents the verse being played or highlighted, return true.
    // In the new word-based logic, we check surah/ayah match.
    final playingVerse = cubit.state.currentVerse;
    if (playingVerse != null &&
        playingVerse.surahNumber == word.suraNumber &&
        playingVerse.verseNumber == word.ayahNumber) {
      return true;
    }

    // fallback to original string-based highlight logic if needed for search highlights
    if (selectedVerse.isNotEmpty && word.text.contains(selectedVerse)) {
      return true;
    }

    return false;
  }

  @override
  void didUpdateWidget(covariant MobileSurahVersesWidget oldWidget) {
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

        return Column(
          children: [
            if (context.isLandscape)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16.w,
                        color: context.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ...List.generate(15, (index) {
              final lineNumber = index + 1;
              final lineWords = lineMap[lineNumber];
              if (lineWords == null || lineWords.isEmpty) {
                return const SizedBox.shrink();
              }

              // Check if it's a special line (surah name or basmallah)
              final firstWord = lineWords.first;
              if (firstWord.lineType == 'surah_name') {
                return widget.isFullPage
                    ? FullHeaderWidget(surahNumber: firstWord.headerSurah ?? 1)
                    : MinHeaderWidget(surahNumber: firstWord.headerSurah ?? 1);
              } else if (firstWord.lineType == 'basmallah') {
                return Basmallah(isFull: widget.isFullPage);
              }

              // Normal ayah line
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisAlignment:
                      (firstWord.isCentered ?? false || widget.pageNumber <= 2)
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: lineWords.map((word) {
                    final isHighlighted = _isHighlighted(word);
                    return GestureDetector(
                      onLongPress: () {
                        if (word.suraNumber == null ||
                            word.ayahNumber == null) {
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
                            height:
                                (widget.pageNumber == 1 ||
                                    widget.pageNumber == 2)
                                ? 2
                                : 1.95,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

String handleFirstPageVerses(int pageNumber, int i, String text) {
  if (pageNumber == 1) {
    if (i == 1 || i == 2 || i == 4) {
      text = '$text\n';
    } else if (i == 6) {
      text = text.replaceFirst('ﱗ', 'ﱗ\n');
    } else if (i == 7) {
      text = text.replaceFirst('ﱝ', 'ﱝ\n');
      text = text.replaceFirst('ﱢ', 'ﱢ\n');
    }
  } else if (pageNumber == 2) {
    if (i == 2) {
      text = text.replaceFirst('ﱉﱊ', 'ﱉﱊ\n');
    } else if (i == 3) {
      text = text.replaceFirst('ﱑ', 'ﱑ\n');
    } else if (i == 4) {
      text = text.replaceFirst('ﱙ', 'ﱙ\n');
      text = '$text\n';
    } else if (i == 5) {
      text = text.replaceFirst('ﱩ', 'ﱩ\n');
    }
  }
  return text;
}
