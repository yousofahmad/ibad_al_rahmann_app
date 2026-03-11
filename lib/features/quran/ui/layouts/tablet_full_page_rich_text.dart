import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/fonts_helper.dart';
import '../widgets/wbw_page_widget.dart';

/// Tablet-optimized layout for full-screen Quran page display.
/// Uses WbwPageWidget which handles its own header, page number,
/// and content width adaptation for tablets internally.
class TabletFullPageRichText extends StatefulWidget {
  const TabletFullPageRichText({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<TabletFullPageRichText> createState() => _TabletFullPageRichTextState();
}

class _TabletFullPageRichTextState extends State<TabletFullPageRichText> {
  String? currentFontFamily;

  Future<void> _changeFont() async {
    String family = FontsHelper.getFontFamily(widget.pageNumber);
    await FontsHelper.loadFont(
      family,
      FontsHelper.getFontPath(widget.pageNumber),
    );
    setState(() {
      currentFontFamily = family;
    });
  }

  @override
  void initState() {
    _changeFont();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (currentFontFamily == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Column(
        children: [
          Expanded(
            child: WbwPageWidget(pageNumber: widget.pageNumber),
          ),
        ],
      ),
    );
  }
}
