import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../../../core/di/di.dart';
import '../../logic/quran_player/quran_player_cubit.dart';

class SurahPlayerControllers extends StatelessWidget {
  const SurahPlayerControllers({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 6,
      children: [
        IconButton(
          iconSize: 40,
          onPressed: () async {
            context.read<QuranPlayerCubit>().playNextSurah(context);
          },
          icon: const Icon(Icons.skip_next_rounded),
        ),
        ZoomTapAnimation(
          onTap: () async {
            context.read<QuranPlayerCubit>().handlePlayPause();
          },
          child: BlocBuilder<QuranPlayerCubit, QuranPlayerState>(
            buildWhen: (previous, current) {
              return current is! SliderValueChanged;
            },
            builder: (context, state) {
              return Icon(
                !getIt<AudioPlayer>().playing
                    ? CupertinoIcons.play_circle_fill
                    : CupertinoIcons.pause_circle_fill,
                size: 50,
              );
            },
          ),
        ),
        IconButton(
          iconSize: 40,
          onPressed: () async {
            context.read<QuranPlayerCubit>().playPreviousSurah(context);
          },
          icon: const Icon(Icons.skip_previous_rounded),
        ),
      ],
    );
  }
}
