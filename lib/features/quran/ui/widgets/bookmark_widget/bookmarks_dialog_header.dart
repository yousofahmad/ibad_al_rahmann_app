import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Text('الفواصل المحفوظة', style: context.headlineLarge),
    );
  }
}
