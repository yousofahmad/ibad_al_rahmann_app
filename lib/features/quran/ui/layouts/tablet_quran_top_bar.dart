import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';

import '../../../../core/helpers/extensions/app_navigator.dart';
import '../widgets/mobile_quran_search_widget.dart';
import '../widgets/quran_fehres_dialog.dart';
import '../widgets/quran_surah_list.dart';
import '../widgets/theme_changer_dialog.dart';

class TabletQuranTopBar extends StatelessWidget {
  const TabletQuranTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranCubit>();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => showFehresDialog(context, cubit),
                  icon: SvgPicture.asset(AppAssets.svgsMenu, height: 45),
                ),
                const MobileQuranSearch(),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => showThemeDialog(context),
                      icon: SvgPicture.asset(AppAssets.svgsSettings),
                    ),
                    IconButton(
                      onPressed: () => IntroService.showQuranIntro(context),
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(child: QuranSurahList()),
        ],
      ),
    );
  }

  void showFehresDialog(BuildContext context, QuranCubit cubit) {
    showDialog(
      context: context,
      builder: (context) {
        return BlocProvider.value(
          value: cubit,
          child: const QuranFehresDialog(),
        );
      },
    );
  }

  void showThemeDialog(BuildContext context) {
    final localThemeCubit = context.read<ThemeCubit>();
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: localThemeCubit,
        child: const ThemeChangerDialog(),
      ),
    );
  }
}
