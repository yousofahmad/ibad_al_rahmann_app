import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ReciterDropdown extends StatefulWidget {
  final VersePlayerCubit cubit;

  const ReciterDropdown({
    super.key,
    required this.cubit,
  });

  @override
  State<ReciterDropdown> createState() => _ReciterDropdownState();
}

class _ReciterDropdownState extends State<ReciterDropdown> {
  String? selectedReciter;

  @override
  void initState() {
    super.initState();
    selectedReciter = widget.cubit.reciter ?? widget.cubit.reciters.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: context.isLandscape ? 80.h : 60.h,
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withAlpha(25), // 0.1 opacity equivalent
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedReciter,
          isExpanded: false,
          icon: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black,
              size: 20.sp,
            ),
          ),
          style: AppStyles.style16.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: context.isTablet ? 12.sp : null,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: widget.cubit.reciters.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Container(
                height: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: context.isTablet ? 0 : 8.h,
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: AppStyles.style16.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: context.isTablet ? 12.sp : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != selectedReciter) {
              setState(() {
                selectedReciter = newValue;
              });
              widget.cubit.changeReciter(newValue);
            }
          },
        ),
      ),
    );
  }
}
