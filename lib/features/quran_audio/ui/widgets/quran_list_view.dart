import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/theme/app_styles.dart';
import '../../logic/quran_audio_cubit/quran_cubit.dart';
import '../../logic/quran_player/quran_player_cubit.dart';
import 'surah_widget.dart';

class QuranListView extends StatelessWidget {
  const QuranListView({super.key, required this.qaree});
  final ReciterAudioModel qaree;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranAudioCubit, QuranState>(
      builder: (context, quranState) {
        final cubit = context.read<QuranAudioCubit>();
        if (quranState is QuranFailure) {
          return Center(
            child: Text(
              quranState.errMessage,
              style: AppStyles.style20.copyWith(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          );
        } else if (cubit.quran.isNotEmpty || quranState is QuranSuccess) {
          return ListView.separated(
            padding: const EdgeInsets.only(top: 12, bottom: 120),
            itemCount: cubit.quran.length,
            itemBuilder: (context, index) {
              final surahItem = cubit.quran[index];
              return BlocBuilder<QuranPlayerCubit, QuranPlayerState>(
                buildWhen: (previous, current) {
                  return current is! SliderValueChanged;
                },
                builder: (context, state) {
                  return SurahWidget(
                    index: surahItem.surahNumber,
                    selected: isSelected(context, surahItem.surahNumber),
                  );
                },
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 12),
          );
        } else {
          return Center(
            child: Lottie.asset(AppAssets.lottiesCircularIndicator),
          );
        }
      },
    );
  }

  bool isSelected(BuildContext context, int surahNumber) {
    final cubit = context.read<QuranPlayerCubit>();
    return cubit.selectedSurah == surahNumber && cubit.player.playing;
  }
}
