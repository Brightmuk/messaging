part of 'chats_cubit.dart';

@immutable
sealed class ChatsState extends Equatable {
  const ChatsState();

  @override
  List<Object> get props => [];
}

class ChatsInitial extends ChatsState {}
class ChatsLoading extends ChatsState {}
class ChatsLoaded extends ChatsState {
  final List<AppChat> chats;
  ChatsLoaded(this.chats);
  @override
  List<Object> get props => [chats];
}
class ChatsError extends ChatsState {
  final String message;
  ChatsError(this.message);
}
