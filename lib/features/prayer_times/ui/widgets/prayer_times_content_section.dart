// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
// import 'package:ibad_al_rahmann/core/helpers/extensions/date_time_ext.dart';
// import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
// import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
// import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:google_fonts/google_fonts.dart';

// import '../../data/models/prayer_times_model.dart';
// import 'prayer_times_grid_view.dart';

// class PrayerTimesContentSection extends StatelessWidget {
//   const PrayerTimesContentSection({super.key, required this.prayer});
//   final PrayerTimesResponseModel prayer;

//   @override
//   Widget build(BuildContext context) {
//     return CustomScrollView(
//       slivers: [
//         const SliverToBoxAdapter(child: SizedBox(height: 20)),
//         SliverToBoxAdapter(
//           child: Container(
//             width: context.screenWidth,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12),
//               color: const Color.fromRGBO(0, 0, 0, .4),
//             ),
//             child: Row(
//               children: [
//                 IconButton(
//                   onPressed: () {
//                     context.pop();
//                   },
//                   icon: const Icon(Icons.arrow_back_ios_new_rounded),
//                 )
//               ],
//             ),
//           ),
//         ),
//         const SliverToBoxAdapter(child: SizedBox(height: 20)),
//         SliverToBoxAdapter(
//           child: Container(
//             width: context.screenWidth,
//             padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(16),
//               color: const Color.fromRGBO(0, 0, 0, .4),
//             ),
//             child: Column(
//               spacing: 20,
//               children: [
//                 NextPrayerProgressBar(prayer: prayer),
//                 Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 0.h),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     spacing: 20,
//                     children: [
//                       Expanded(
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 16.w,
//                             vertical: 24.h,
//                           ),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(16),
//                             color: const Color.fromRGBO(0, 0, 0, .4),
//                           ),
//                           child: Text(
//                             prayer.hijriMonth,
//                             textAlign: TextAlign.center,
//                             style: GoogleFonts.amiri(
//                               fontSize: 30.sp,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 16.w,
//                             vertical: 24.h,
//                           ),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(16),
//                             color: const Color.fromRGBO(0, 0, 0, .4),
//                           ),
//                           child: Text(
//                             DateTime.now().toArabicWeekdayName,
//                             textAlign: TextAlign.center,
//                             style: GoogleFonts.amiri(
//                               fontSize: 30.sp,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   width: double.infinity,
//                   padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(16),
//                     color: const Color.fromRGBO(0, 0, 0, .4),
//                   ),
//                   child: Row(
//                     spacing: 20,
//                     children: [
//                       Expanded(
//                         child: Text(
//                           prayer.hijriDate,
//                           textAlign: TextAlign.center,
//                           style: AppStyles.style16,
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           prayer.normalDate,
//                           textAlign: TextAlign.center,
//                           style: AppStyles.style16,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Row(
//                   spacing: 20,
//                   children: [
//                     const Icon(Icons.location_pin),
//                     Expanded(
//                       child: Text(
//                         prayer.location.arabicAddress,
//                         style: AppStyles.style16,
//                       ),
//                     ),
//                   ],
//                 )
//               ],
//             ),
//           ),
//         ),
//         const SliverToBoxAdapter(child: SizedBox(height: 20)),
//         PrayerTimesGridView(prayers: prayer, nextPrayer: ,),
//         const SliverToBoxAdapter(child: SizedBox(height: 20)),
//       ],
//     );
//   }
// }

// class NextPrayerProgressBar extends StatefulWidget {
//   const NextPrayerProgressBar({super.key, required this.prayer});
//   final PrayerTimesResponseModel prayer;

//   @override
//   State<NextPrayerProgressBar> createState() => _NextPrayerProgressBarState();
// }

// class _NextPrayerProgressBarState extends State<NextPrayerProgressBar> {
//   Timer? _timer;
//   double _progress = 0;
//   String _label = '';

//   @override
//   void initState() {
//     super.initState();
//     _recalculate();
//     _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recalculate());
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   void _recalculate() {
//     final now = DateTime.now();
//     final prayers = widget.prayer.prayerTimes;

//     // Check if we are inside a current prayer window: [adhan(date), iqamaDate)
//     int activeIndex = -1;
//     for (int i = 0; i < prayers.length; i++) {
//       final p = prayers[i];
//       final started = p.date.isBefore(now) || p.date.isAtSameMomentAs(now);
//       final notIqamaYet = p.iqamaDate.isAfter(now);
//       if (started && notIqamaYet) {
//         activeIndex = i;
//         break;
//       }
//     }

//     DateTime start;
//     DateTime end;
//     String label;

//     if (activeIndex != -1) {
//       // Inside a prayer window: progress from adhan to iqama
//       final current = prayers[activeIndex];
//       start = current.date;
//       end = current.iqamaDate;
//       label = 'الوقت المتبقي لإقامة صلاة ${current.title}';
//     } else {
//       // Outside a window: countdown to the next prayer start
//       int nextIndex = -1;
//       for (int i = 0; i < prayers.length; i++) {
//         if (prayers[i].date.isAfter(now)) {
//           nextIndex = i;
//           break;
//         }
//       }

//       if (nextIndex == -1) {
//         // All today's prayers passed -> next is tomorrow's first (Fajr)
//         nextIndex = 0;
//         end = prayers[nextIndex].date.add(const Duration(days: 1));
//         // Start from last prayer's iqama today for a meaningful interval
//         start =
//             prayers.last.iqamaDate.isBefore(end) ? prayers.last.iqamaDate : now;
//       } else {
//         end = prayers[nextIndex].date;
//         if (nextIndex > 0) {
//           // Start from previous prayer's iqama
//           start = prayers[nextIndex - 1].iqamaDate;
//         } else {
//           // Before Fajr: previous day iqama not available here; start now
//           start = now;
//         }
//       }
//       label = 'الوقت المتبقي حتى ${prayers[nextIndex].title}';
//     }

//     final total = end.difference(start).inSeconds;
//     final left = end.difference(now).inSeconds;
//     final clampedTotal = total <= 0 ? 1 : total;
//     final clampedLeft = left.clamp(0, clampedTotal);
//     final progress = 1 - (clampedLeft / clampedTotal);

//     final remaining = Duration(seconds: clampedLeft);
//     final remainingText = _formatDuration(remaining);

//     if (!mounted) return;
//     setState(() {
//       _progress = progress;
//       _label = '$label: $remainingText';
//     });
//   }

//   String _formatDuration(Duration d) {
//     final hours = d.inHours;
//     final minutes = d.inMinutes % 60;
//     final seconds = d.inSeconds % 60;
//     if (hours > 0) {
//       return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
//     }
//     return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       spacing: 8,
//       children: [
//         Text(
//           _label,
//           textAlign: TextAlign.center,
//           style: AppStyles.style16,
//         ),
//         ClipRRect(
//           borderRadius: BorderRadius.circular(8),
//           child: LinearProgressIndicator(
//             value: _progress.clamp(0.0, 1.0),
//             minHeight: 8,
//             backgroundColor: Colors.white24,
//             valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
//           ),
//         ),
//       ],
//     );
//   }
// }
