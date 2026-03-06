part of 'chats_cubit.dart';

@immutable
sealed class ChatsState extends Equatable {
  const ChatsState();

  @override
  List<Object> get props => [];
}

class ChatsInitial extends ChatsState {}
class PermissionRevoked extends ChatsState {}
class ChatsLoading extends ChatsState {}
class ChatsLoaded extends ChatsState {
  final List<AppChat> chats;
  final bool isDefaultApp; 
  
  const ChatsLoaded(this.chats, {this.isDefaultApp = true});

  @override
  List<Object> get props => [chats, isDefaultApp];
}
class ChatsError extends ChatsState {
  final String message;
  ChatsError(this.message);
}
