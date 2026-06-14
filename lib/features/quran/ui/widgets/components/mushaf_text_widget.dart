import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';

class MushafText extends StatefulWidget {
  final String text;
  final int pageNumber;
  final TextStyle style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;

  const MushafText({
    super.key,
    required this.text,
    required this.pageNumber,
    required this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
  });

  @override
  State<MushafText> createState() => _MushafTextState();
}

class _MushafTextState extends State<MushafText> {
  late String _fontFamily;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _fontFamily = FontsHelper.getFontFamily(widget.pageNumber);
    if (FontsHelper.isFontLoaded(_fontFamily)) {
      _isLoaded = true;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(MushafText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _fontFamily = FontsHelper.getFontFamily(widget.pageNumber);
      if (FontsHelper.isFontLoaded(_fontFamily)) {
        _isLoaded = true;
      } else {
        _isLoaded = false;
        _load();
      }
    }
  }

  Future<void> _load() async {
    await FontsHelper.loadFontFromFamily(_fontFamily);
    if (mounted) setState(() => _isLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.text,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: widget.style.copyWith(
        fontFamily: _isLoaded ? _fontFamily : 'uthmanic',
      ),
    );
  }
}
