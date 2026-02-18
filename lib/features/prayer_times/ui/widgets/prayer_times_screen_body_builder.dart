import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/helpers/time_handler.dart';
import 'package:ibad_al_rahmann/features/prayer_times/logic/prayer_times_cubit/prayer_times_cubit.dart';
import 'package:ibad_al_rahmann/features/prayer_times/ui/widgets/prayer_times_screen_body.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/theme/app_images.dart';
// Permissions are handled by the parent screen now.

class PrayerTimesScreenBodyBuilder extends StatelessWidget {
  const PrayerTimesScreenBodyBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerTimesCubit, PrayerTimesState>(
      builder: (context, state) {
        if (state is PrayerTimesLoading) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppImages.imagesFullWhiteBackground),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Lottie.asset(AppImages.lottiesCircularIndicator),
            ),
          );
        } else if (state is PrayerTimesSuccess) {
          var prayer = getCurrentPrayerTime(
            context.read<PrayerTimesCubit>().prayers!.prayerTimes,
          );

          return PrayerTimesScreenBody(nextPrayer: prayer!);
        } else if (state is PrayerTimesFailure) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تعذر جلب مواعيد الصلاة، يرجى السماح بالوصول إلى الموقع من الإعدادات',
                    style: context.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      context.read<PrayerTimesCubit>().getPrayerTimes();
                    },
                    child: Text('إعادة المحاولة', style: context.labelMedium),
                  ),
                ],
              ),
            ),
          );
        } else {
          return Center(
            child: Text(
              'عذرًا يرجى المحاولة مرة أخرى',
              style: context.headlineLarge,
            ),
          );
        }
      },
    );
  }
}
