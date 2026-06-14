import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_audio_cubit/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

import 'widgets/quran_audio_screen_body.dart';

class QuranAudioScreen extends StatelessWidget {
  const QuranAudioScreen({super.key, required this.reciter});
  final ReciterModel reciter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider(
        create: (_) => QuranAudioCubit(reciter),
        child: QuranAudioScreenBody(reciter: reciter),
      ),
    );
  }
}
