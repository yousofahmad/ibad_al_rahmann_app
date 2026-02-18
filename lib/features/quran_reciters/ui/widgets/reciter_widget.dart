import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran_audio/ui/quran_audio_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../../../core/theme/app_assets.dart';
import '../../../../core/theme/app_styles.dart';
import '../../data/models/reciter_model.dart';

class ReciterWidget extends StatelessWidget {
  const ReciterWidget({super.key, required this.reciter});
  final ReciterModel reciter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ZoomTapAnimation(
        end: .98,
        onTap: () {
          context.read<QuranPlayerCubit>().reciter = reciter;
          context.push(
            QuranAudioScreen(reciter: reciter),
            direction: NavigationDirection.downToUp,
          );
        },
        child: Container(
          width: 340.w,
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage(AppAssets.imagesGreenColor),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  reciter.name,
                  style: AppStyles.style22expo.copyWith(
                      fontSize: (context.isTablet || context.isLandscape)
                          ? 18.sp
                          : null),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
