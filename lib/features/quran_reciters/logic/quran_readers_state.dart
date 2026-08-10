part of 'quran_readers_cubit.dart';

sealed class QuranReadersState {}

final class QuranReadersInitial extends QuranReadersState {}

final class QuranReadersLoading extends QuranReadersState {}

final class QuranReadersSuccess extends QuranReadersState {
  final List<ReciterModel> reciters;

  QuranReadersSuccess({required this.reciters});
}

final class QuranReadersFailure extends QuranReadersState {
  final String errMessage;

  QuranReadersFailure({required this.errMessage});
}
