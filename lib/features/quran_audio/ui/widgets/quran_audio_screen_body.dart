import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/widgets/adaptive_layout.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/widgets/custom_text_widget.dart';
import 'bottom_sheet_bloc_builder.dart';
import 'quran_list_view.dart';

class QuranAudioScreenBody extends StatelessWidget {
  const QuranAudioScreenBody({super.key, required this.reciter});

  final ReciterModel reciter;

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuranPlayerCubit, QuranPlayerState>(
      listener: (context, state) {
        if (state is QuranPlayerFailure) {
          AlertHelper.showErrorAlert(
            context,
            message: state.errMessage ?? 'حدث خطأ ما',
          );
        }
      },
      child: AdaptiveLayout(
        mobileLayout: (_) => MobileQuranAudioLayout(reciter: reciter),
        tabletLayout: (_) => TabletQuranAudioLayout(reciter: reciter),
      ),
    );
  }
}

class TabletQuranAudioLayout extends StatelessWidget {
  const TabletQuranAudioLayout({super.key, required this.reciter});

  final ReciterModel reciter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.screenWidth,
      height: context.screenHeight,
      decoration: const BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(AppAssets.imagesFullWhiteBackground),
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    color: Colors.black,
                    icon: const Icon(Icons.arrow_forward_ios_outlined),
                    iconSize: context.isTablet ? 20.w : null,
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    top: 40.h,
                    child: QuranListView(qaree: reciter),
                  ),
                  Positioned.fill(
                    top: 20.h,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: CustomTextWidget(
                          text: reciter.name,
                          fontSize: context.isLandscape ? 14.sp : 18.sp),
                    ),
                  ),
                  Positioned.fill(
                    bottom: 40,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SurahOverlayPlayerBuilder(qaree: reciter),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileQuranAudioLayout extends StatelessWidget {
  const MobileQuranAudioLayout({super.key, required this.reciter});

  final ReciterModel reciter;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.screenWidth,
      height: context.screenHeight,
      decoration: const BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(AppAssets.imagesFullWhiteBackground),
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    color: Colors.black,
                    icon: const Icon(Icons.arrow_forward_ios_outlined),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    top: 15.h,
                    child: QuranListView(qaree: reciter),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: CustomTextWidget(text: reciter.name),
                  ),
                  Positioned.fill(
                    bottom: 10,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SurahOverlayPlayerBuilder(qaree: reciter),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
