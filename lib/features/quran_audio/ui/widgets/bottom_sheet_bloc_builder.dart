import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

import '../../logic/quran_player/quran_player_cubit.dart';
import 'quran_screen_bottom_sheet.dart';

class SurahOverlayPlayerBuilder extends StatelessWidget {
  const SurahOverlayPlayerBuilder({super.key, required this.qaree});

  final ReciterModel qaree;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranPlayerCubit, QuranPlayerState>(
      buildWhen: (previous, current) {
        return current is! SliderValueChanged;
      },
      builder: (context, state) {
        if (state is QuranBottomSheetShowed || state is SliderValueChanged) {
          if (qaree == (context.read<QuranPlayerCubit>().reciter ?? qaree)) {
            return SurahOverlayPlayer(reciter: qaree);
          }
        }
        return const SizedBox();
      },
    );
  }
}
