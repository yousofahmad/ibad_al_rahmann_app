import 'package:ibad_al_rahmann/features/quran_reciters/services/quran_audio_download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/surah_list.dart';

class SurahWidget extends StatelessWidget {
  const SurahWidget({
    super.key,
    required this.index,
    // required this.surah,
    required this.selected,
  });

  final int index;
  // final SurahAudioModel surah;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        width: 320.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 8),
              width: context.isLandscape ? 80.h : 40.w,
              height: context.isLandscape ? 80.h : 40.w,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(AppAssets.imagesVerseFrame),
                ),
              ),
              child: Center(
                child: Text(
                  index.toArabicNums,
                  style: AppStyles.style16BFantezy.copyWith(
                    color: const Color(0xff606060),
                    fontSize: !context.isTablet ? 20.sp : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              quranSurahs[index - 1],
              style: AppStyles.style24harmattan.copyWith(
                color: const Color(0xff606060),
              ),
            ),
            const Spacer(),
            _DownloadButton(reciterId: context.read<QuranPlayerCubit>().reciter?.folderName ?? '', surahNumber: index),
              IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                context.read<QuranPlayerCubit>().playSurah(index);
              },
              color: AppColors.green,
              iconSize: 30.w,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: selected
                    ? Icon(Icons.pause_circle_filled_rounded, size: 42.w)
                    : Image.asset(
                        AppAssets.imagesPlayIcon,
                        width: 35.w,
                        fit: BoxFit.scaleDown,
                      ),
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
