import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

import '../../data/surah_list.dart';
import '../../logic/quran_player/quran_player_cubit.dart';
import 'custom_audio_slider.dart';
import 'surah_player_controllers.dart';

class SurahOverlayPlayer extends StatelessWidget {
  const SurahOverlayPlayer({super.key, required this.reciter});
  final ReciterAudioModel reciter;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranPlayerCubit>();
    final primaryColor = Theme.of(context).primaryColor;
    return IntrinsicHeight(
      child: Container(
        width: context.screenWidth * .85,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(80)),
          color: primaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'سورة ${quranSurahs[cubit.selectedSurah! - 1]}',
              style: AppStyles.style26expo,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              reciter.hasSegments
                  ? '${cubit.currentReciterName!} • أصوات متقسمة آيات'
                  : '${cubit.currentReciterName!} • سورة كاملة فقط (تظليل الآيات: لا يوجد)',
              style: AppStyles.style20harmattan.copyWith(
                color: Colors.grey.shade200,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const CustomAudioSlider(),
            const SurahPlayerControllers(),
          ],
        ),
      ),
    );
  }
}
