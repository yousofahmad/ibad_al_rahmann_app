part of 'quran_player_cubit.dart';

sealed class QuranPlayerState {}

final class QuranPlayerInitial extends QuranPlayerState {}

final class QuranBottomSheetShowed extends QuranPlayerState {}

final class QuranBottomSheetUnshowed extends QuranPlayerState {}

final class NoInternetConnection extends QuranPlayerState {}

final class SliderValueChanged extends QuranPlayerState {}

final class QuranPlayerFailure extends QuranPlayerState {
  final String? errMessage;

  QuranPlayerFailure({required this.errMessage});
}
