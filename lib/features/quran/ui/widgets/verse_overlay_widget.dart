import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'verse_details_bottom_sheet.dart';

class VerseBottomSheet extends StatelessWidget {
  const VerseBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();
    return Container(
      padding: const EdgeInsets.all(10),
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        spacing: 10,
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<VersePlayerCubit, VersePlayerState>(
            builder: (context, state) {
              final isBookmarked = cubit.isCurrentVerseBookmarked();
              return IconButton(
                iconSize: 40.w,
                onPressed: () async {
                  final wasAdded = await cubit.toggleBookmark();
                  if (context.mounted) {
                    AlertHelper.showSuccessAlert(
                      context,
                      message: wasAdded
                          ? 'تم حفظ الآية بنجاح'
                          : 'تم حذف الآية من المحفوظات',
                    );
                    context.pop();
                  }
                },
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_rounded,
                  color: isBookmarked ? Colors.amber : null,
                ),
              );
            },
          ),
          IconButton(
            iconSize: 40.w,
            onPressed: () {
              final currentVerse = cubit.currnetVerse!;

              showModalBottomSheet(
                barrierColor: Colors.transparent,
                context: context,
                builder: (context) {
                  return BlocProvider.value(
                    value: cubit,
                    child: VerseDetailsBottomSheet(currentVerse: currentVerse),
                  );
                },
              );
            },
            icon: const Icon(CupertinoIcons.book_circle),
          ),
          IconButton(
            iconSize: 40.w,
            onPressed: () {
              context.pop();
              cubit.show();
              cubit.initVerse();
            },
            icon: const Icon(
              Icons.play_circle_filled_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
