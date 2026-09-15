part of 'verse_player_cubit.dart';

sealed class VersePlayerState {
  final bool showed;
  final bool loading;
  final VerseModel? currentVerse;
  final int? activeWordIndex;

  VersePlayerState({
    required this.showed,
    this.loading = false,
    this.currentVerse,
    this.activeWordIndex,
  });
}

final class VersePlayerInitial extends VersePlayerState {
  VersePlayerInitial({
    required super.showed,
    super.loading = false,
    super.currentVerse,
    super.activeWordIndex,
  });
}
