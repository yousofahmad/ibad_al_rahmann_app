import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:ibad_al_rahmann/features/quran/data/db_helper.dart';
import 'package:quran/quran.dart' as quran;

class DbMushafText extends StatefulWidget {
  final int surahNumber;
  final int verseNumber;
  final TextStyle style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;

  const DbMushafText({
    super.key,
    required this.surahNumber,
    required this.verseNumber,
    required this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
  });

  @override
  State<DbMushafText> createState() => _DbMushafTextState();
}

class _DbMushafTextState extends State<DbMushafText> {
  String? _glyphText;
  int? _pageNumber;
  String? _fontFamily;
  bool _isFontLoaded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGlyphs();
  }

  @override
  void didUpdateWidget(DbMushafText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber ||
        oldWidget.verseNumber != widget.verseNumber) {
      _loadGlyphs();
    }
  }

  Future<void> _loadGlyphs() async {
    if (!mounted) return;

    // Phase 1: FAST PATH (Memory Cache)
    final cached = QuranWbwDbHelper.instance.getVerseGlyphsSync(
      widget.surahNumber,
      widget.verseNumber,
    );
    _pageNumber = quran.getPageNumber(widget.surahNumber, widget.verseNumber);
    _fontFamily = FontsHelper.getFontFamily(_pageNumber!);

    if (cached != null && FontsHelper.isFontLoaded(_fontFamily!)) {
      if (mounted) {
        setState(() {
          _glyphText = cached;
          _isFontLoaded = true;
          _isLoading = false;
        });
      }
      return;
    }

    // Phase 2: SLOW PATH (Database + Font Loading)
    if (mounted) setState(() => _isLoading = true);

    try {
      // Fetch if not in cache (or font not loaded)
      String? text = cached;
      if (text == null) {
        final words = await QuranWbwDbHelper.instance.getWordsForVerse(
          widget.surahNumber,
          widget.verseNumber,
        );
        text = words.map((w) => w.text).join(' ');
      }

      _glyphText = text;

      if (!FontsHelper.isFontLoaded(_fontFamily!)) {
        await FontsHelper.loadFontFromFamily(_fontFamily!);
        // Small delay to ensure engine registration
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (mounted) {
        setState(() {
          _isFontLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _glyphText = '';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading ||
        !_isFontLoaded ||
        _glyphText == null ||
        _glyphText!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      _glyphText!,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection ?? TextDirection.rtl,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: widget.style.copyWith(fontFamily: _fontFamily),
    );
  }
}
