part of 'khatma_cubit.dart';

abstract class KhatmaState {}

class KhatmaInitial extends KhatmaState {}

class KhatmaLoading extends KhatmaState {}

class KhatmaLoaded extends KhatmaState {
  final KhatmaModel khatma;

  KhatmaLoaded(this.khatma);
}

class KhatmaEmpty extends KhatmaState {}

class KhatmaError extends KhatmaState {
  final String message;

  KhatmaError(this.message);
}
