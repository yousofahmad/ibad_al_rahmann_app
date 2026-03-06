import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';
import 'package:share_plus/share_plus.dart';

import 'verse_details_bottom_sheet.dart';

class VerseBottomSheet extends StatelessWidget {
  const VerseBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();
    return Container(
      padding: const EdgeInsets.all(10),
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        spacing: 10,
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<VersePlayerCubit, VersePlayerState>(
            builder: (context, state) {
              final isBookmarked = cubit.isCurrentVerseBookmarked();
              return IconButton(
                iconSize: 40.w,
                onPressed: () async {
                  final wasAdded = await cubit.toggleBookmark();
                  if (context.mounted) {
                    AlertHelper.showSuccessAlert(
                      context,
                      message: wasAdded
                          ? 'تم حفظ الآية بنجاح'
                          : 'تم حذف الآية من المحفوظات',
                    );
                    context.pop();
                  }
                },
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_rounded,
                  color: isBookmarked ? Colors.amber : null,
                ),
              );
            },
          ),
          // Share verse with context button
          IconButton(
            iconSize: 40.w,
            onPressed: () {
              final currentVerse = cubit.currnetVerse;
              if (currentVerse == null) return;
              showDialog(
                context: context,
                builder: (_) => _VerseShareDialog(
                  surahNumber: currentVerse.surahNumber,
                  verseNumber: currentVerse.verseNumber,
                ),
              );
            },
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            iconSize: 40.w,
            onPressed: () {
              final currentVerse = cubit.currnetVerse!;

              showModalBottomSheet(
                barrierColor: Colors.transparent,
                context: context,
                builder: (context) {
                  return BlocProvider.value(
                    value: cubit,
                    child: VerseDetailsBottomSheet(currentVerse: currentVerse),
                  );
                },
              );
            },
            icon: const Icon(CupertinoIcons.book_circle),
          ),
          IconButton(
            iconSize: 40.w,
            onPressed: () {
              context.pop();
              cubit.show();
              cubit.initVerse();
            },
            icon: const Icon(Icons.play_circle_filled_rounded),
          ),
        ],
      ),
    );
  }
}

/// Dialog that lets the user choose how many verses before/after
/// to include, with a live preview and a share button.
class _VerseShareDialog extends StatefulWidget {
  final int surahNumber;
  final int verseNumber;

  const _VerseShareDialog({
    required this.surahNumber,
    required this.verseNumber,
  });

  @override
  State<_VerseShareDialog> createState() => _VerseShareDialogState();
}

class _VerseShareDialogState extends State<_VerseShareDialog> {
  int _beforeCount = 0;
  int _afterCount = 0;

  int get _maxBefore => widget.verseNumber - 1; // can't go below ayah 1
  int get _maxAfter =>
      getVerseCount(widget.surahNumber) -
      widget.verseNumber; // can't exceed total

  String _buildShareText() {
    final buf = StringBuffer();
    final startAyah = widget.verseNumber - _beforeCount;
    final endAyah = widget.verseNumber + _afterCount;

    for (int i = startAyah; i <= endAyah; i++) {
      buf.write(getVerse(widget.surahNumber, i));
      buf.write(' ${getVerseEndSymbol(i)} ');
    }
    buf.writeln();

    final surahName = getSurahNameArabic(widget.surahNumber);
    if (startAyah == endAyah) {
      buf.write('[ سورة $surahName، الآية $startAyah ]');
    } else {
      buf.write('[ سورة $surahName، الآيات من $startAyah إلى $endAyah ]');
    }
    buf.writeln();
    buf.write('من تطبيق عِبَادُ الرَّحْمَٰن 📖');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final shareText = _buildShareText();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مشاركة الآية',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'cairo',
                ),
              ),
              const SizedBox(height: 16),

              // Before-count selector
              _CounterRow(
                label: 'آيات قبلها',
                value: _beforeCount,
                maxValue: _maxBefore,
                onIncrement: () => setState(() => _beforeCount++),
                onDecrement: () => setState(() => _beforeCount--),
              ),
              const SizedBox(height: 8),

              // After-count selector
              _CounterRow(
                label: 'آيات بعدها',
                value: _afterCount,
                maxValue: _maxAfter,
                onIncrement: () => setState(() => _afterCount++),
                onDecrement: () => setState(() => _afterCount--),
              ),
              const SizedBox(height: 16),

              // Live preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    shareText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'uthmanic',
                      fontSize: 18,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Share button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await SharePlus.instance.share(
                      ShareParams(text: shareText),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.black87),
                  label: const Text(
                    'مشاركة',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reusable +/- counter row for selecting verse count.
class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: value > 0 ? onDecrement : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: AppColors.lime,
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: value < maxValue ? onIncrement : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: AppColors.lime,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontFamily: 'cairo', fontSize: 14)),
      ],
    );
  }
}
