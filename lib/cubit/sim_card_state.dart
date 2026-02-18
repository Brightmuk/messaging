part of 'sim_card_cubit.dart';

sealed class SimCardState extends Equatable {
  const SimCardState();

  @override
  List<Object> get props => [];
}

final class SimCardInitial extends SimCardState {}
final class SimCardLoaded extends SimCardState{
  final AppSimCardState state;
  const SimCardLoaded({required this.state});
  @override
  List<Object> get props => [state];
}
final class SimCardError extends SimCardState{
  final String message;
  const SimCardError({required this.message});
  @override
  List<Object> get props => [message];
}