import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmarks_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TabletMinQuranBottomSection extends StatelessWidget {
  const TabletMinQuranBottomSection({super.key});

  void _showBookmarksDialog(BuildContext context) {
    final bookmarks = BookmarkService.getAllBookmarks();
    final versePlayerCubit = context.read<VersePlayerCubit>();
    final quranCubit = context.read<QuranCubit>();

    if (bookmarks.isEmpty) {
      // Show a simple dialog if no bookmarks
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.onPrimary,
          title: const Text('الآيات المحفوظة'),
          content:
              Text('لم تقم بحفظ أى آية إلى الآن', style: context.titleSmall),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسنًا', style: context.titleSmall),
            ),
          ],
        ),
      );
    } else {
      // Show the full bookmarks dialog
      showDialog(
        context: context,
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: versePlayerCubit),
            BlocProvider.value(value: quranCubit),
          ],
          child: const BookmarksDialog(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            _showBookmarksDialog(context);
          },
          child: Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.surfaceColor,
            ),
            child: const Icon(
              Icons.bookmark,
              color: Colors.white,
              size: 45,
            ),
          ),
        ),
        BlocBuilder<QuranCubit, QuranState>(
          buildWhen: (previous, current) {
            return previous.juzNumber != current.juzNumber;
          },
          builder: (context, state) {
            return Text(
              state.juzNumber.toJuzName,
              style: context.headlineLarge.copyWith(fontSize: 20.sp),
            );
          },
        ),
        GestureDetector(
          onTap: () {
            context.read<ThemeCubit>().switchTheme();
          },
          child: Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.surfaceColor,
            ),
            child: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
                return Icon(
                  state.mode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: Colors.white,
                  size: 45,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
