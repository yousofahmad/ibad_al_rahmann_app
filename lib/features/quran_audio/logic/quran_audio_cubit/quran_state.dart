part of 'quran_cubit.dart';

sealed class QuranState {}

final class QuranInitial extends QuranState {}

final class QuranLoading extends QuranState {}

final class QuranSuccess extends QuranState {}

final class QuranFailure extends QuranState {
  final String errMessage;

  QuranFailure({required this.errMessage});
}
