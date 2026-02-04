part of 'conversations_cubit.dart';

@immutable
sealed class ConversationsState {}

class ConversationsInitial extends ConversationsState {}
class ConversationsLoading extends ConversationsState {}
class ConversationsLoaded extends ConversationsState {
  final List<AppConversation> conversations;
  ConversationsLoaded(this.conversations);
}
class ConversationsError extends ConversationsState {
  final String message;
  ConversationsError(this.message);
}
