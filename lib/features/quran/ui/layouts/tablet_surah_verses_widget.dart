import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

import '../widgets/basmallah.dart';
import '../widgets/header_widget.dart';
import '../widgets/page_details.dart';
import '../widgets/verse_overlay_widget.dart';
import 'mobile_surah_verses_widget.dart';

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
  @override
  void initState() {
    cubit = context.read<VersePlayerCubit>();

    super.initState();
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
  // Normalize text for reliable comparison (remove spaces and thin space \u200A)
  String _normalize(String value) =>
      value.replaceAll(' ', '').replaceAll('\u200A', '');

  bool _isHighlighted(String candidateText) {
    final String normalizedCandidate = _normalize(candidateText);
    final String normalizedSelected = _normalize(selectedVerse);
    final String normalizedProp = _normalize(widget.highlightedVerse ?? '');
    return normalizedCandidate == normalizedSelected ||
        (_usePropHighlight && normalizedCandidate == normalizedProp);
  }

  @override
  void didUpdateWidget(covariant TabletSurahVersesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  List<InlineSpan> _buildSpans(BuildContext context) {
    bool detailsAdded = false;
    bool addDetails = true;
    // final data = getPageData(widget.pageNumber);
    // int surahNumber = data.first['surah'];

    final double height = (widget.pageNumber == 1 || widget.pageNumber == 2)
        ? 2
        : widget.isFullPage
        ? 1.768
        : 1.78;

    return getPageData(widget.pageNumber).expand((e) {
      final List<InlineSpan> spans = [];

      for (var i = e["start"]; i <= e["end"]; i++) {
        if (i == 1) {
          addDetails = false;
          spans.add(
            WidgetSpan(
              child: widget.isFullPage
                  ? FullHeaderWidget(surahNumber: e["surah"])
                  : MinHeaderWidget(surahNumber: e["surah"]),
            ),
          );

          if (widget.pageNumber != 187 && widget.pageNumber != 1) {
            spans.add(
              WidgetSpan(child: TabletBasmallah(isFull: widget.isFullPage)),
            );
          }
          if (widget.pageNumber == 187) {
            spans.add(const WidgetSpan(child: SizedBox(height: 10)));
          }
        }

        // Cache the verse text with spaces removed
        final String verse = getVerseQCF(e["surah"], i).replaceAll(' ', '');
        String text = (i == e["start"] && verse.isNotEmpty)
            ? "${verse.substring(0, 1)}\u200A${verse.substring(1)}"
            : verse;

        text = handleFirstPageVerses(widget.pageNumber, i, text);

        spans.add(
          TextSpan(
            text: text,
            recognizer: LongPressGestureRecognizer()
              ..onLongPressStart = (v) {
                _highlightSetByLongPress = true;
                _initialHighlightTimer?.cancel();
                setState(() {
                  selectedVerse = text;
                  _usePropHighlight = false;
                });
                final future = showModalBottomSheet(
                  barrierColor: Colors.black38,
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return BlocProvider.value(
                      value: cubit,
                      child: const VerseBottomSheet(),
                    );
                  },
                );
                future.whenComplete(() {
                  if (!mounted) return;
                  setState(() => selectedVerse = '');
                });

                cubit.setVerse(
                  surahNumber: e["surah"],
                  verseNumber: i,
                  fontFamily: widget.family,
                  verse: text,
                );
              },
            style: TextStyle(
              color: context.onSecondary,
              height: height,
              fontFamily: widget.family,
              fontSize: widget.fontSize,
              letterSpacing: 0,
              wordSpacing: 0,
              backgroundColor: _isHighlighted(text)
                  ? AppColors.lime.withAlpha(120)
                  : Colors.transparent,
            ),
          ),
        );
      }
      if (widget.isFullPage &&
          widget.pageNumber > 2 &&
          !detailsAdded &&
          addDetails) {
        spans.insert(
          0,
          WidgetSpan(
            child: Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: FullPageDetails(
                surahNumber: e["surah"],
                firstVerse: e["start"],
              ),
            ),
          ),
        );
        detailsAdded = true;
      }

      return spans;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      softWrap: true,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: [
          WidgetSpan(child: SizedBox(height: 25.h)),
          ..._buildSpans(context),
          if (widget.pageNumber > 2)
            TextSpan(
              text: '\n${widget.pageNumber.toArabicNums}',
              style: context.titleSmall.copyWith(
                fontSize: widget.isFullPage ? 18.sp : 12.sp,
              ),
            ),
        ],
      ),
    );
  }
}
