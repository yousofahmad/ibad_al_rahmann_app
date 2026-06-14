import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../screens/share_setup_screen.dart';

import './verse_details_bottom_sheet.dart';

class VerseBottomSheet extends StatefulWidget {
  final bool? isDarkOverride;
  final int pageNumber;
  const VerseBottomSheet({
    super.key,
    this.isDarkOverride,
    required this.pageNumber,
  });

  @override
  State<VerseBottomSheet> createState() => _VerseBottomSheetState();
}

class _VerseBottomSheetState extends State<VerseBottomSheet> {
  bool _isOpeningShare = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();
    final bool isDark =
        widget.isDarkOverride ??
        (Theme.of(context).brightness == Brightness.dark);

    // Background color: strictly use the solid primary color
    final Color bgColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<VersePlayerCubit, VersePlayerState>(
            builder: (context, state) {
              final isBookmarked = cubit.isCurrentVerseBookmarked();
              return IconButton(
                iconSize: 40.w,
                onPressed: _isOpeningShare
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        if (isBookmarked) {
                          await cubit.toggleBookmark();
                          if (context.mounted) {
                            AlertHelper.showSuccessAlert(
                              context,
                              message: 'تم حذف الآية من المحفوظات',
                            );
                            navigator.pop();
                          }
                        } else {
                          final label = await _showNamingDialog(context);
                          if (label != null) {
                            final wasAdded = await cubit.toggleBookmark(
                              label: label.isEmpty ? null : label,
                            );
                            if (context.mounted && wasAdded) {
                              AlertHelper.showSuccessAlert(
                                context,
                                message: 'تم حفظ الآية بنجاح',
                              );
                              navigator.pop();
                            }
                          }
                        }
                      },
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_rounded,
                  color: isBookmarked ? Colors.amber : Colors.white,
                ),
              );
            },
          ),
          IconButton(
            iconSize: 32.w,
            onPressed: _isOpeningShare
                ? null
                : () async {
                    final currentVerse = cubit.currnetVerse;
                    if (currentVerse == null) return;

                    setState(() => _isOpeningShare = true);

                    // Close the bottom sheet first
                    Navigator.of(context).pop();

                    // Show the advanced share screen
                    ShareSetupScreen.show(
                      context,
                      surahNumber: currentVerse.surahNumber,
                      initialVerse: currentVerse.verseNumber,
                    );
                  },
            icon: _isOpeningShare
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_rounded, color: Colors.white),
          ),
          IconButton(
            iconSize: 40.w,
            onPressed: _isOpeningShare
                ? null
                : () {
                    final currentVerse = cubit.currnetVerse!;

                    showModalBottomSheet(
                      barrierColor: Colors.transparent,
                      context: context,
                      builder: (_) {
                        return BlocProvider.value(
                          value: cubit,
                          child: VerseDetailsBottomSheet(
                            currentVerse: currentVerse,
                            isDarkOverride: isDark,
                          ),
                        );
                      },
                    );
                  },
            icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
          ),
          IconButton(
            iconSize: 34.w,
            onPressed: _isOpeningShare
                ? null
                : () {
                    context.pop();
                    cubit.show();
                    cubit.initVerse();
                  },
            icon: const Icon(
              Icons.play_circle_filled_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showNamingDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تسمية المحفوظة',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يمكنك كتابة اسم لهذا البوك مارك لسهولة الوصول إليه لاحقاً (مثال: مراجعة، جديد).',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'cairo', fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'أدخل الاسم هنا (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
