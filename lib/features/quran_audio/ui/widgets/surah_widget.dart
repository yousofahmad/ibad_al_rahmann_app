import 'package:ibad_al_rahmann/features/quran_reciters/services/quran_audio_download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/surah_list.dart';

class SurahWidget extends StatelessWidget {
  const SurahWidget({
    super.key,
    required this.index,
    required this.selected,
  });

  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        width: 330.w,
        decoration: BoxDecoration(
          color: selected
              ? gold.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected
                ? gold
                : gold.withValues(alpha: isDark ? 0.25 : 0.3),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : gold.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 6),
              width: context.isLandscape ? 50.h : 38.w,
              height: context.isLandscape ? 50.h : 38.w,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(AppAssets.imagesVerseFrame),
                ),
              ),
              child: Center(
                child: Text(
                  index.toArabicNums,
                  style: AppStyles.style16BFantezy.copyWith(
                    color: isDark ? Colors.white70 : const Color(0xff606060),
                    fontSize: !context.isTablet ? 18.sp : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              quranSurahs[index - 1],
              style: AppStyles.style24harmattan.copyWith(
                color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            _DownloadButton(
              reciterId: context.read<QuranPlayerCubit>().reciter?.folderName ?? '',
              surahNumber: index,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                context.read<QuranPlayerCubit>().playSurah(index);
              },
              iconSize: 32.w,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: selected
                    ? const Icon(Icons.pause_circle_filled_rounded, size: 36, color: gold)
                    : const Icon(Icons.play_circle_fill_rounded, size: 36, color: gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final String reciterId;
  final int surahNumber;
  const _DownloadButton({required this.reciterId, required this.surahNumber});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  @override
  void initState() {
    super.initState();
    QuranAudioDownloadService().checkState(widget.reciterId, widget.surahNumber);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reciterId.isEmpty) return const SizedBox();

    return AnimatedBuilder(
      animation: QuranAudioDownloadService(),
      builder: (context, child) {
        final state = QuranAudioDownloadService().getState(widget.reciterId, widget.surahNumber);
        final progress = QuranAudioDownloadService().getProgress(widget.reciterId, widget.surahNumber);

        if (state == AudioDownloadState.downloaded) {
          return IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () {
              QuranAudioDownloadService().deleteSurah(widget.reciterId, widget.surahNumber);
            },
          );
        } else if (state == AudioDownloadState.downloading) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 2),
            ),
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.download, color: Colors.grey),
            onPressed: () {
              QuranAudioDownloadService().downloadSurah(widget.reciterId, widget.surahNumber);
            },
          );
        }
      },
    );
  }
}
