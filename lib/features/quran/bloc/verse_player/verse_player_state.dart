part of 'verse_player_cubit.dart';

sealed class VersePlayerState {
  final bool showed, loading;
  VersePlayerState({required this.showed, this.loading = false});
}

final class VersePlayerInitial extends VersePlayerState {
  VersePlayerInitial({required super.showed, super.loading = false});
}
