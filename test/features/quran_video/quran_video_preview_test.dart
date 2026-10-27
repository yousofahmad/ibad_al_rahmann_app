import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_background_preview_service.dart';
import 'package:ibad_al_rahmann/features/quran_video/ui/quran_video_caption_preview.dart';

void main() {
  group('QuranVideoCaptionPreview', () {
    const verse = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

    Future<RichText> renderCaption(
      WidgetTester tester,
      QuranVideoExportOptions options,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuranVideoCaptionPreview(
                verse: verse,
                options: options,
                fontSize: 24,
              ),
            ),
          ),
        ),
      );
      return tester.widget<RichText>(find.byType(RichText));
    }

    TextSpan captionStyle(RichText richText) =>
        ((richText.text as TextSpan).children!.single as TextSpan);

    List<TextSpan> captionWords(RichText richText) =>
        captionStyle(richText).children!.cast<TextSpan>();

    testWidgets('keeps the complete Arabic verse and export Quran font', (
      tester,
    ) async {
      final richText = await renderCaption(
        tester,
        const QuranVideoExportOptions(),
      );

      expect(richText.text.toPlainText(), verse);
      expect(captionStyle(richText).style?.fontFamily, 'AmiriQuran');
      expect(captionStyle(richText).style?.fontWeight, FontWeight.normal);
      for (final word in captionWords(richText)) {
        expect(word.style?.color, const Color(0xFFFFD54F));
      }
    });

    testWidgets('word reveal previews one word and word highlight keeps all', (
      tester,
    ) async {
      final revealed = await renderCaption(
        tester,
        const QuranVideoExportOptions(
          displayMode: QuranVideoDisplayMode.wordReveal,
        ),
      );
      expect(revealed.text.toPlainText(), 'بِسْمِ');
      expect(
        captionWords(revealed).first.style?.color,
        const Color(0xFFFFD54F),
      );

      final highlighted = await renderCaption(
        tester,
        const QuranVideoExportOptions(
          displayMode: QuranVideoDisplayMode.wordHighlight,
        ),
      );
      expect(highlighted.text.toPlainText(), verse);
      expect(
        captionWords(highlighted).first.style?.color,
        const Color(0xFFFFD54F),
      );
      expect(captionWords(highlighted).last.style?.color, Colors.white);
    });

    testWidgets('disabling highlight uses the selected text color', (
      tester,
    ) async {
      const textColor = Color(0xFF20A0C0);
      final richText = await renderCaption(
        tester,
        const QuranVideoExportOptions(
          textColor: textColor,
          showHighlight: false,
        ),
      );

      expect(richText.text.toPlainText(), verse);
      for (final word in captionWords(richText)) {
        expect(word.style?.color, textColor);
      }
    });
  });

  group('QuranVideoBackgroundPreviewService', () {
    test('passes video and thumbnail paths as separate FFmpeg arguments', () {
      final arguments =
          QuranVideoBackgroundPreviewService.buildThumbnailArguments(
            videoPath: '/tmp/background with spaces;name.mp4',
            thumbnailPath: '/tmp/preview image.jpg',
          );

      expect(
        arguments,
        containsAllInOrder(['-i', '/tmp/background with spaces;name.mp4']),
      );
      expect(arguments.last, '/tmp/preview image.jpg');
      expect(arguments, containsAllInOrder(['-frames:v', '1', '-vf']));
      expect(
        arguments.join(' '),
        contains('force_original_aspect_ratio=decrease'),
      );
      expect(arguments, isNot(contains('1:a:0')));
    });
  });
}
