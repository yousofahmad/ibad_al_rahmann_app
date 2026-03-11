part of 'khatma_cubit.dart';

abstract class KhatmaState {}

class KhatmaInitial extends KhatmaState {}

class KhatmaLoading extends KhatmaState {}

class KhatmaLoaded extends KhatmaState {
  final List<KhatmaModel> khatmas;

  KhatmaLoaded(this.khatmas);
}

class KhatmaEmpty extends KhatmaState {}

class KhatmaError extends KhatmaState {
  final String message;

  KhatmaError(this.message);
}
