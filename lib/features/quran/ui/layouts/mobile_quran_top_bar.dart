import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';

import '../../../../core/helpers/extensions/app_navigator.dart';
import '../widgets/search/mobile_quran_search_widget.dart';
import '../widgets/fehres/quran_fehres_dialog.dart';
import '../widgets/fehres/quran_surah_list.dart';
import '../widgets/themes/quran_theme_selection_dialog.dart';

class MobileQuranTopBar extends StatelessWidget {
  final VoidCallback? onToggleAutoScroll;
  final bool isAutoScrolling;

  const MobileQuranTopBar({
    super.key,
    this.onToggleAutoScroll,
    this.isAutoScrolling = false,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranCubit>();
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final bool isLight = bg.computeLuminance() > 0.5;
    final Color contentColor = isLight ? Colors.black : Colors.white;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => showFehresDialog(context, cubit),
                icon: SvgPicture.asset(
                  AppAssets.svgsMenu,
                  height: 30.h,
                  colorFilter: ColorFilter.mode(contentColor, BlendMode.srcIn),
                ),
              ),
              const MobileQuranSearch(),
              if (onToggleAutoScroll != null)
                IconButton(
                  onPressed: onToggleAutoScroll,
                  icon: Icon(
                    isAutoScrolling
                        ? Icons.stop_circle_outlined
                        : Icons.keyboard_double_arrow_down,
                    color: isAutoScrolling ? Colors.red : contentColor,
                    size: 28.w,
                  ),
                ),
              IconButton(
                onPressed: () => showThemeDialog(context),
                icon: SvgPicture.asset(
                  AppAssets.svgsSettings,
                  colorFilter: ColorFilter.mode(contentColor, BlendMode.srcIn),
                ),
              ),
              IconButton(
                onPressed: () => IntroService.showQuranIntro(context),
                icon: Icon(Icons.info_outline, color: contentColor),
              ),
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: contentColor,
                  size: 26.w,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Builder(
            builder: (context) {
              final state = context.watch<QuranThemeCubit>().state;
              return Theme(
                data: state.mode == ThemeMode.dark
                    ? state.theme.dark
                    : state.theme.light,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: state.mode == ThemeMode.dark
                        ? Brightness.light
                        : Brightness.dark,
                    systemNavigationBarColor: Colors.transparent,
                  ),
                  child: const QuranSurahList(),
                ),
              );
            },
          ),
        ),
      ],
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
    final themeCubit = context.read<ThemeCubit>() as QuranThemeCubit;
    showDialog(
      context: context,
      builder: (context) => BlocProvider<QuranThemeCubit>.value(
        value: themeCubit,
        child: const QuranThemeSelectionDialog(),
      ),
    );
  }
}
