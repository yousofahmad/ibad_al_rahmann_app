part of 'prayer_times_cubit.dart';

sealed class PrayerTimesState {}

final class PrayerTimesInitial extends PrayerTimesState {}

final class PrayerTimesLoading extends PrayerTimesState {}

final class PrayerTimesSuccess extends PrayerTimesState {}

final class PrayerTimesFailure extends PrayerTimesState {
  final String errMessage;

  PrayerTimesFailure({required this.errMessage});
}
