import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'bottom_sheet_bloc_builder.dart';
import 'quran_list_view.dart';

class QuranAudioScreenBody extends StatelessWidget {
  const QuranAudioScreenBody({super.key, required this.reciter});

  final ReciterAudioModel reciter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Colors.black : Colors.white;
    final primaryColor = Theme.of(context).primaryColor;

    return BlocListener<QuranPlayerCubit, QuranPlayerState>(
      listener: (context, state) {
        if (state is QuranPlayerFailure) {
          AlertHelper.showErrorAlert(
            context,
            message: state.errMessage ?? 'حدث خطأ ما',
          );
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text(
            reciter.name,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: primaryColor,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: QuranListView(qaree: reciter),
            ),
            Positioned.fill(
              bottom: 16.h,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SurahOverlayPlayerBuilder(qaree: reciter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
