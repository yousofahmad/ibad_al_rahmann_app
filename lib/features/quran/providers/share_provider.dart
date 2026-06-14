import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import '../data/db_helper.dart';
import '../data/quran_word.dart';
import '../../../core/helpers/fonts_helper.dart';

enum ShareMode { image, text }

class ShareProvider extends ChangeNotifier {
  final int surahNumber;
  final int totalVerses;

  int _fromVerse;
  int _toVerse;
  ShareMode _shareMode = ShareMode.image;
  bool _showLogo = true;
  bool _isMushafFormat = true;

  List<List<QuranWord>>? _mushafLines;
  List<QuranWord>? _allWords;
  bool _isLoading = false;

  ShareProvider({required this.surahNumber, required int initialVerse})
    : totalVerses = getVerseCount(surahNumber),
      _fromVerse = initialVerse,
      _toVerse = initialVerse;

  int get fromVerse => _fromVerse;
  int get toVerse => _toVerse;
  ShareMode get shareMode => _shareMode;
  bool get showLogo => _showLogo;
  bool get isMushafFormat => _isMushafFormat;

  bool get isLoading => _isLoading;
  List<List<QuranWord>>? get mushafLines => _mushafLines;
  List<QuranWord>? get allWords => _allWords;

  List<int> get allVerseNumbers => List.generate(totalVerses, (i) => i + 1);

  bool isInRange(int verseNumber) =>
      verseNumber >= _fromVerse && verseNumber <= _toVerse;

  void setFromVerse(int v) {
    if (_fromVerse == v) return;
    _fromVerse = v;
    if (_toVerse < _fromVerse) _toVerse = _fromVerse;
    loadWords();
  }

  void setToVerse(int v) {
    if (_toVerse == v) return;
    _toVerse = v;
    if (_fromVerse > _toVerse) _fromVerse = _toVerse;
    loadWords();
  }

  Future<void> loadWords() async {
    _isLoading = true;
    _mushafLines = null;
    _allWords = null;
    notifyListeners();

    try {
      final pages = <int>{};
      for (int v = _fromVerse; v <= _toVerse; v++) {
        pages.add(getPageNumber(surahNumber, v));
      }

      // Load all pages and fonts in parallel
      final pageWordsResults = await Future.wait(
        pages.map((p) async {
          final family = FontsHelper.getFontFamily(p);
          await FontsHelper.loadFontFromFamily(family);
          return QuranWbwDbHelper.instance.getPageWords(p);
        }),
      );

      final List<QuranWord> allPageWords = [];
      for (final words in pageWordsResults) {
        allPageWords.addAll(words);
      }

      // 1. Identify which lines (by page and line number) intersect with our verse range
      // OR are part of the header block (Surah name, Basmallah) for the selected range.
      final Set<String> intersectingLines = {};
      final List<QuranWord> verseWords = [];

      // First, find the lines that directly contain our verses
      for (final w in allPageWords) {
        if (w.suraNumber == surahNumber) {
          final ayah = w.ayahNumber ?? 0;
          if (ayah >= _fromVerse && ayah <= _toVerse) {
            final p = w.pageNumber ?? 0;
            final ln = w.lineNumber ?? 0;
            intersectingLines.add('${p}_$ln');
            verseWords.add(w);
          }
        }
      }

      // Second, if we start from verse 1, include preceding Surah Name / Basmallah on the same page
      if (_fromVerse == 1 && verseWords.isNotEmpty) {
        final firstVersePage = verseWords.first.pageNumber;
        final firstVerseLine = verseWords.first.lineNumber;

        if (firstVersePage != null && firstVerseLine != null) {
          // Look for headers on the same page before the first verse line
          for (final w in allPageWords) {
            if (w.pageNumber == firstVersePage &&
                (w.lineNumber ?? 0) < firstVerseLine) {
              if (w.lineType == 'surah_name' || w.lineType == 'basmallah') {
                intersectingLines.add('${w.pageNumber}_${w.lineNumber}');
              }
            }
          }
        }
      }

      // 2. Build mushafLines using ALL words from those intersecting lines
      final Map<String, List<QuranWord>> byPageLine = {};
      for (final w in allPageWords) {
        final p = w.pageNumber ?? 0;
        final ln = w.lineNumber ?? 0;
        final key = '${p}_$ln';

        if (intersectingLines.contains(key)) {
          byPageLine.putIfAbsent(key, () => []).add(w);
        }
      }

      final sortedKeys = byPageLine.keys.toList()
        ..sort((a, b) {
          final partsA = a.split('_');
          final partsB = b.split('_');
          final pA = int.parse(partsA[0]);
          final pB = int.parse(partsB[0]);
          if (pA != pB) return pA.compareTo(pB);
          return int.parse(partsA[1]).compareTo(int.parse(partsB[1]));
        });

      _mushafLines = sortedKeys.map((k) => byPageLine[k]!).toList();
      _allWords = verseWords;
    } catch (e) {
      debugPrint('Error loading words: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setShareMode(ShareMode mode) {
    _shareMode = mode;
    notifyListeners();
  }

  void toggleLogo() {
    _showLogo = !_showLogo;
    notifyListeners();
  }

  void toggleMushafFormat() {
    _isMushafFormat = !_isMushafFormat;
    notifyListeners();
  }

  String buildVerseText() {
    final buf = StringBuffer();
    for (int i = _fromVerse; i <= _toVerse; i++) {
      buf.write(getVerse(surahNumber, i, verseEndSymbol: true));
      if (!_isMushafFormat) {
        buf.write(' ');
      } else {
        buf.writeln();
      }
    }
    return buf.toString().trim();
  }

  String buildShareText({bool withLogo = true}) {
    final surahArabic = getSurahNameArabic(surahNumber);
    final buf = StringBuffer();

    for (int i = _fromVerse; i <= _toVerse; i++) {
      final verseText = getVerse(surahNumber, i);
      buf.write('﴿ $verseText ﴾');
      buf.write(' (${_toArabicNumerals(i)}) ');
      if (_isMushafFormat) buf.writeln();
    }
    if (!_isMushafFormat) buf.writeln();

    if (_fromVerse == _toVerse) {
      buf.write(
        '*[ سورة $surahArabic، الآية ${_toArabicNumerals(_fromVerse)} ]*',
      );
    } else {
      buf.write(
        '*[ سورة $surahArabic، الآيات ${_toArabicNumerals(_fromVerse)} إلى ${_toArabicNumerals(_toVerse)} ]*',
      );
    }

    if (withLogo) {
      buf.writeln();
      buf.write('بواسطة تطبيق عِبَادُ الرَّحْمَٰن 📖');
    }
    return buf.toString();
  }

  static String _toArabicNumerals(int number) {
    const westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String result = number.toString();
    for (int i = 0; i < westernDigits.length; i++) {
      result = result.replaceAll(westernDigits[i], arabicDigits[i]);
    }
    return result;
  }
}
