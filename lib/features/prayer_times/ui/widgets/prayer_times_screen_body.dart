import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/features/prayer_times/data/models/prayer_times_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_images.dart';
import '../../logic/prayer_times_cubit/prayer_times_cubit.dart';
import 'prayer_times_date_widget.dart';
import 'prayer_times_grid_view.dart';
import 'prayer_times_header.dart';
import 'user_location_widget.dart';

class PrayerTimesScreenBody extends StatelessWidget {
  const PrayerTimesScreenBody({super.key, required this.nextPrayer});
  final PrayerTimeModel nextPrayer;

  @override
  Widget build(BuildContext context) {
    final prayers = context.read<PrayerTimesCubit>().prayers!;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            AppImages.imagesWhiteBackground,
            fit: BoxFit.cover,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: PrayerTimesHeader(isMorning: nextPrayer.prayerType.isMorning),
        ),
        Positioned.fill(
          top: context.isLandscape
              ? 350.h
              : context.isTablet
              ? 235.h
              : 205.h,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(child: PrayerTimesDateWidget(prayers: prayers)),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: context.isLandscape ? 16.h : 8),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.screenWidth * 0.1,
                ),
                sliver: PrayerTimesGridView(
                  prayers: prayers,
                  nextPrayer: nextPrayer,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (prayers.location.arabicAddress != null ||
                  prayers.location.address != null)
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.screenWidth * 0.1,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: UserLocationWidget(
                      location:
                          prayers.location.arabicAddress ??
                          prayers.location.address!,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ],
    );
  }
}
