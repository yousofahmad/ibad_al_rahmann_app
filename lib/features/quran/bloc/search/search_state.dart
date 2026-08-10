part of 'search_cubit.dart';

sealed class SearchState {}

final class SearchInitial extends SearchState {}

final class OnSearch extends SearchState {
  final List<SearchingVerseModel> verses;

  OnSearch({required this.verses});
}
