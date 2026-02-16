// ads_state.dart
import 'package:equatable/equatable.dart';

abstract class AdsState extends Equatable {
  const AdsState();

  @override
  List<Object?> get props => [];
}

class AdsInitial extends AdsState {}

class AdsLoading extends AdsState {}

class AdsLoaded extends AdsState {}

class AdsFailed extends AdsState {
  final String error;

  const AdsFailed(this.error);

  @override
  List<Object?> get props => [error];
}
