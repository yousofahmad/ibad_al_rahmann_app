import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../../logic/quran_readers_cubit.dart';

class ReciterFilterWidget extends StatelessWidget {
  const ReciterFilterWidget({super.key});

  static const _filters = <(QuranReciterFilter, String)>[
    (QuranReciterFilter.wordByWord, 'كلمة كلمة'),
    (QuranReciterFilter.verseOnly, 'آية آية'),
    (QuranReciterFilter.surah, 'سورة كاملة'),
  ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranReadersCubit>();
    final theme = Theme.of(context);
    return BlocBuilder<QuranReadersCubit, QuranReadersState>(
      buildWhen: (previous, current) =>
          current is QuranReadersSuccess || previous is QuranReadersSuccess,
      builder: (context, state) {
        final selected = cubit.selectedFilter;
        return SizedBox(
          height: 42.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final (filter, label) = _filters[index];
              final isSelected = selected == filter;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => cubit.selectFilter(filter),
                labelStyle: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
                selectedColor: theme.primaryColor,
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: isSelected
                      ? theme.primaryColor
                      : theme.primaryColor.withValues(alpha: .3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                showCheckmark: false,
              );
            },
          ),
        );
      },
    );
  }
}
