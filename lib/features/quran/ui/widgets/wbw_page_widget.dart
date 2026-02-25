import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import '../../data/db_helper.dart';
import '../../data/quran_word.dart';
import '../../bloc/quran/quran_cubit.dart';
import '../../bloc/verse_player/verse_player_cubit.dart';
import 'verse_overlay_widget.dart';
import 'header_widget.dart';
import 'basmallah.dart';

class WbwPageWidget extends StatefulWidget {
  final int pageNumber;

  const WbwPageWidget({Key? key, required this.pageNumber}) : super(key: key);

  @override
  State<WbwPageWidget> createState() => _WbwPageWidgetState();
}

class _WbwPageWidgetState extends State<WbwPageWidget> {
  List<QuranWord>? _words;
  String? _error;

  // Track long-pressed verse for Tafsir bottom sheet selection highlight
  QuranWord? _selectedWord;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final words = await QuranWbwDbHelper.instance.getPageWords(
        widget.pageNumber,
      );
      if (mounted) {
        setState(() {
          _words = words;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _onWordLongPressed(
    BuildContext context,
    VersePlayerCubit playerCubit,
    QuranWord word,
  ) {
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
      // Pass the whole text for this word so Tafsir bottom sheet has a reference if needed
      verse: word.text,
    );

    showModalBottomSheet(
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
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _selectedWord = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error: \$_error'));
    }
    if (_words == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words!.isEmpty) {
      return const Center(child: Text('No lines found for this page.'));
    }

    final quranCubit = context.watch<QuranCubit>();
    final playerCubit = context.watch<VersePlayerCubit>();

    final playingVerse = playerCubit.currnetVerse;
    final isAudioPlaying = playerCubit.player.playing;
    final bookmarkHighlightText = quranCubit.state.highligthedVerse ?? '';

    // Group words by lineNumber
    final Map<int, List<QuranWord>> linesMap = {};
    for (var word in _words!) {
      final line = word.lineNumber ?? 1;
      if (!linesMap.containsKey(line)) {
        linesMap[line] = [];
      }
      linesMap[line]!.add(word);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(15, (i) {
          final lineNumber = i + 1;
          final lineWords = linesMap[lineNumber] ?? [];

          if (lineWords.isEmpty) {
            return const Expanded(child: SizedBox.shrink());
          }

          final firstWord = lineWords.first;

          // 1. Check for Surah Name Headings
          if (firstWord.lineType == 'surah_name') {
            return Expanded(
              child: FullHeaderWidget(surahNumber: firstWord.headerSurah ?? 1),
            );
          }

          // 2. Check for Basmallah Graphics
          if (firstWord.lineType == 'basmallah') {
            return const Expanded(child: Basmallah(isFull: true));
          }

          // 3. Render traditional Ayah strings directly via strict Word rows
          bool isCentered = firstWord.isCentered ?? false;

          return Expanded(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: isCentered ? null : 1000,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: isCentered
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: lineWords.map((word) {
                    final bool isAudioHighlighted =
                        isAudioPlaying &&
                        playingVerse != null &&
                        playingVerse.surahNumber == word.suraNumber &&
                        playingVerse.verseNumber == word.ayahNumber;

                    final bool isSelected =
                        _selectedWord != null &&
                        _selectedWord!.suraNumber == word.suraNumber &&
                        _selectedWord!.ayahNumber == word.ayahNumber;

                    final bool isBookmarkHighlighted =
                        bookmarkHighlightText.isNotEmpty &&
                        bookmarkHighlightText.contains(
                          word.text.replaceAll('\u200A', ''),
                        );

                    final bool isHighlighted =
                        isAudioHighlighted ||
                        isSelected ||
                        isBookmarkHighlighted;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () =>
                          _onWordLongPressed(context, playerCubit, word),
                      onDoubleTap: () =>
                          _onWordLongPressed(context, playerCubit, word),
                      child: Text(
                        word.text,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 48,
                          color: Theme.of(context).colorScheme.onSecondary,
                          height: 1.2,
                          backgroundColor: isHighlighted
                              ? AppColors.lime.withAlpha(120)
                              : Colors.transparent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
