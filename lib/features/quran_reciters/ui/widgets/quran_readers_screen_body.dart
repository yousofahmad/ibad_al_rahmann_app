import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/theme/app_assets.dart';
import '../../logic/quran_readers_cubit.dart';
import 'landscape_quran_readers_list_view.dart';
import 'quran_error_widget.dart';
import 'quran_readers_list_view.dart';

class QuranReadersScreenBody extends StatelessWidget {
  const QuranReadersScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranReadersCubit, QuranReadersState>(
      builder: (context, state) {
        if (state is QuranReadersFailure) {
          return QurraaErrorWidget(error: state.errMessage);
        } else if (state is QuranReadersSuccess) {
          if (context.isLandscape) {
            return LandscapeReadersBody(reciters: state.reciters);
          }
          return ReadersBody(reciters: state.reciters);
        } else {
          return Center(
            child: Lottie.asset(AppAssets.lottiesCircularIndicator),
          );
        }
      },
    );
  }
}
