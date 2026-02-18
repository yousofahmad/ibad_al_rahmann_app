import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

import '../../data/surah_list.dart';
import '../../logic/quran_player/quran_player_cubit.dart';
import 'custom_audio_slider.dart';
import 'surah_player_controllers.dart';

class SurahOverlayPlayer extends StatelessWidget {
  const SurahOverlayPlayer({super.key, required this.reciter});
  final ReciterModel reciter;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranPlayerCubit>();
    return IntrinsicHeight(
      child: Container(
        width: context.screenWidth * .85,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(80)),
          image: DecorationImage(
            opacity: .8,
            image: AssetImage(AppAssets.imagesGreenColor),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Text(
              'سورة ${quranSurahs[cubit.selectedSurah! - 1]}',
              style: AppStyles.style26expo,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              cubit.currentReciterName!,
              style: AppStyles.style20harmattan.copyWith(
                color: Colors.grey.shade200,
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
