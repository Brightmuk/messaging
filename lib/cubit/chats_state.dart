part of 'chats_cubit.dart';

@immutable
sealed class ChatsState {}

class ChatsInitial extends ChatsState {}
class ChatsLoading extends ChatsState {}
class ChatsLoaded extends ChatsState {
  final List<AppChat> chats;
  ChatsLoaded(this.chats);
}
class ChatsError extends ChatsState {
  final String message;
  ChatsError(this.message);
}
