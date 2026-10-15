import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';

void main() {
  group('Tafsir download URL validation', () {
    test('resolves a repository-relative tafsir file', () {
      expect(
        TafsirHelper.normalizeDownloadUrl('tafseer/book.json'),
        'https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/tafseer/book.json',
      );
    });

    test('converts a blob URL only from the trusted repository', () {
      expect(
        TafsirHelper.normalizeDownloadUrl(
          'https://github.com/yousofahmad/ibad-alrahman-features/blob/main/tafseer/book.json',
        ),
        'https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/tafseer/book.json',
      );
    });

    test('accepts a Google Drive file URL on the exact HTTPS host', () {
      expect(
        TafsirHelper.normalizeDownloadUrl(
          'https://drive.google.com/file/d/abc_123/view?usp=sharing',
        ),
        'https://drive.google.com/uc?export=download&id=abc_123&confirm=t',
      );
    });

    test('rejects traversal paths and unsupported external hosts', () {
      expect(
        () => TafsirHelper.normalizeDownloadUrl('tafseer/../../private.json'),
        throwsFormatException,
      );
      expect(
        () => TafsirHelper.normalizeDownloadUrl('https://example.com/book.json'),
        throwsFormatException,
      );
      expect(
        () => TafsirHelper.normalizeDownloadUrl(
          'http://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/tafseer/book.json',
        ),
        throwsFormatException,
      );
    });
  });
}
