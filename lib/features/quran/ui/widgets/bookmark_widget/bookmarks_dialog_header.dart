import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';

class BookmarksDialogHeader extends StatelessWidget {
  final int bookmarkCount;
  final VoidCallback onClose;

  const BookmarksDialogHeader({
    super.key,
    required this.bookmarkCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final onHeader =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Text(
        'الفواصل المحفوظة',
        style: context.headlineLarge.copyWith(color: onHeader),
      ),
    );
  }
}
