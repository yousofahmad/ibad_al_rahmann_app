import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/widgets/adaptive_layout.dart';

import '../../layouts/mobile_full_page_rich_text.dart';
import '../../layouts/tablet_full_page_rich_text.dart';

class FullPageRichText extends StatefulWidget {
  const FullPageRichText({
    super.key,
    required this.pageNumber,
    this.paperColorOverride,
  });
  final int pageNumber;
  final Color? paperColorOverride;

  @override
  State<FullPageRichText> createState() => _FullPageRichTextState();
}

class _FullPageRichTextState extends State<FullPageRichText> {
  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      mobileLayout: (_) => MobileFullPageRichText(
        pageNumber: widget.pageNumber,
        paperColorOverride: widget.paperColorOverride,
      ),
      tabletLayout: (_) => TabletFullPageRichText(
        pageNumber: widget.pageNumber,
        paperColorOverride: widget.paperColorOverride,
      ),
    );
  }
}
