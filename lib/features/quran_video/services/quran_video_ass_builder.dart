import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';

class QuranVideoSubtitleCue {
  const QuranVideoSubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.words,
    this.highlightedWordIndex,
  });

  final int startMs;
  final int endMs;
  final List<String> words;

  /// One-based index, matching the reciter timing metadata.
  final int? highlightedWordIndex;
}

class QuranVideoAssBuilder {
  const QuranVideoAssBuilder._();

  static String build({
    required List<QuranVideoSubtitleCue> cues,
    required QuranVideoExportOptions options,
  }) {
    final shortSide = options.width < options.height
        ? options.width
        : options.height;
    final fontSize = (options.fontSize * shortSide / 1080).round();
    final positionY = (options.height * options.position).round().clamp(
      1,
      options.height - 1,
    );
    final textColor = _assColor(options.textColor);
    final highlightColor = _assColor(options.highlightColor);
    final panelColor = _assColor(
      const Color(0xFF000000),
      transparency: 1 - options.panelOpacity.clamp(0, 1),
    );
    final borderStyle = options.showTextPanel ? 3 : 1;
    final outline = options.showTextPanel ? 0 : 2;
    final shadow = options.showTextPanel ? 0 : 1;

    final output = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('ScriptType: v4.00+')
      ..writeln('WrapStyle: 0')
      ..writeln('ScaledBorderAndShadow: yes')
      ..writeln('PlayResX: ${options.width}')
      ..writeln('PlayResY: ${options.height}')
      ..writeln('YCbCr Matrix: TV.709')
      ..writeln()
      ..writeln('[V4+ Styles]')
      ..writeln(
        'Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding',
      )
      ..writeln(
        'Style: Default,Amiri Quran,$fontSize,$textColor,$highlightColor,&H99000000,$panelColor,0,0,0,0,100,100,0,0,$borderStyle,$outline,$shadow,5,56,56,48,1',
      )
      ..writeln()
      ..writeln('[Events]')
      ..writeln(
        'Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text',
      );

    for (final cue in cues) {
      if (cue.endMs <= cue.startMs || cue.words.isEmpty) continue;
      final words = cue.words.map(_escapeAssText).toList(growable: false);
      final renderedText = _renderCueText(
        words: words,
        highlightedWordIndex: cue.highlightedWordIndex,
        displayMode: options.displayMode,
        textColor: textColor,
        highlightColor: highlightColor,
        showHighlight: options.showHighlight,
      );
      if (renderedText.isEmpty) continue;
      final start = _formatTime(cue.startMs);
      final end = _formatTime(cue.endMs);
      final positionedText =
          '{\\an5\\pos(${options.width ~/ 2},$positionY)}$renderedText';
      output.writeln('Dialogue: 0,$start,$end,Default,,0,0,0,,$positionedText');
    }
    return output.toString();
  }

  static String _renderCueText({
    required List<String> words,
    required int? highlightedWordIndex,
    required QuranVideoDisplayMode displayMode,
    required String textColor,
    required String highlightColor,
    required bool showHighlight,
  }) {
    if (displayMode == QuranVideoDisplayMode.wordReveal) {
      if (highlightedWordIndex == null ||
          highlightedWordIndex < 1 ||
          highlightedWordIndex > words.length) {
        return '';
      }
      final word = words[highlightedWordIndex - 1];
      return showHighlight ? _colored(word, highlightColor) : word;
    }

    if (displayMode == QuranVideoDisplayMode.ayahByAyah) {
      final wholeVerseColor = showHighlight ? highlightColor : textColor;
      return _colored(words.join(' '), wholeVerseColor);
    }

    final output = StringBuffer();
    for (var index = 0; index < words.length; index++) {
      if (index > 0) output.write(' ');
      final oneBasedIndex = index + 1;
      if (showHighlight && oneBasedIndex == highlightedWordIndex) {
        output.write(_colored(words[index], highlightColor));
      } else {
        output.write(_colored(words[index], textColor));
      }
    }
    return output.toString();
  }

  static String _colored(String text, String color) =>
      '{\\1c$color}$text{\\1c&H00FFFFFF&}';

  static String _escapeAssText(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}');

  static String _assColor(Color color, {double transparency = 0}) {
    final alpha = (transparency.clamp(0, 1) * 255).round();
    final red = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final green = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final blue = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '&H${alpha.toRadixString(16).padLeft(2, '0')}${blue.toUpperCase()}${green.toUpperCase()}${red.toUpperCase()}&';
  }

  static String _formatTime(int milliseconds) {
    final safeMs = milliseconds < 0 ? 0 : milliseconds;
    final totalCentiseconds = safeMs ~/ 10;
    final centiseconds = totalCentiseconds % 100;
    final totalSeconds = totalCentiseconds ~/ 100;
    final seconds = totalSeconds % 60;
    final minutes = (totalSeconds ~/ 60) % 60;
    final hours = totalSeconds ~/ 3600;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }
}
