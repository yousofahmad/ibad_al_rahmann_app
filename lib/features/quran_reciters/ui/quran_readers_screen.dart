import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/widgets_ext.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/logic/quran_readers_cubit.dart';

import 'widgets/quran_readers_screen_body.dart';

class QuranReadersScreen extends StatelessWidget {
  const QuranReadersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BlocProvider(
        create: (context) => QuranReadersCubit(),
        child: const QuranReadersScreenBody(),
      ).withSafeArea(),
    );
  }
}
