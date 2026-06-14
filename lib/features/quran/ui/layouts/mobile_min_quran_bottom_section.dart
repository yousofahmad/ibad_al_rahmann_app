import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmarks_dialog.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/single_tap_menu.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MobileMinQuranBottomSection extends StatelessWidget {
  const MobileMinQuranBottomSection({super.key});

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
          content: Text(
            'لم تقم بحفظ أى آية إلى الآن',
            style: context.titleSmall,
          ),
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
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final bool isLight = bg.computeLuminance() > 0.5;
    final Color contentColor = isLight ? Colors.black : Colors.white;

    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color iconColor =
        ThemeData.estimateBrightnessForColor(primaryColor) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              _showBookmarksDialog(context);
            },
            child: Container(
              width: 50.h,
              height: 50.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
              child: Icon(Icons.bookmark, color: iconColor, size: 35.sp),
            ),
          ),
          BlocBuilder<QuranCubit, QuranState>(
            buildWhen: (previous, current) {
              return previous.juzNumber != current.juzNumber;
            },
            builder: (context, state) {
              return Text(
                state.juzNumber.toJuzName,
                style: context.headlineLarge.copyWith(
                  fontSize: 24.sp,
                  color: contentColor,
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () {
              PageActionBar.showColorPalette(context);
            },
            child: Container(
              width: 50.h,
              height: 50.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
              child: Icon(
                Icons.color_lens_rounded,
                color: iconColor,
                size: 30.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
