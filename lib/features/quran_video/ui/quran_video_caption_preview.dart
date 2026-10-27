import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';

class QuranVideoCaptionPreview extends StatelessWidget {
  const QuranVideoCaptionPreview({
    super.key,
    required this.verse,
    required this.options,
    required this.fontSize,
  });

  final String verse;
  final QuranVideoExportOptions options;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final words = verse
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final visibleWords = options.displayMode == QuranVideoDisplayMode.wordReveal
        ? words.take(1).toList(growable: false)
        : words;

    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: options.textColor,
          fontFamily: AppConsts.amiri,
          fontSize: fontSize,
          fontWeight: FontWeight.normal,
          height: 1.25,
          shadows: options.showTextPanel
              ? null
              : [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: fontSize * 0.08,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        children: [
          for (var index = 0; index < visibleWords.length; index++)
            TextSpan(
              text:
                  '${visibleWords[index]}${index < visibleWords.length - 1 ? ' ' : ''}',
              style: TextStyle(
                color:
                    options.showHighlight &&
                        (options.displayMode ==
                                QuranVideoDisplayMode.ayahByAyah ||
                            index == 0)
                    ? options.highlightColor
                    : options.textColor,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      softWrap: true,
    );
  }
}
