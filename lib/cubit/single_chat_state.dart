part of 'single_chat_cubit.dart';

@immutable
sealed class SingleChatState {}

final class SingleChatInitial extends SingleChatState {}
final class SingleChatSendError extends SingleChatState {
  final String error;

  SingleChatSendError({required this.error});
  
}
final class SingleChatLoading extends SingleChatState {}
final class SingleChatLoaded extends SingleChatState {
  final List<AppSmsMessage> messages;
  final bool hasReachedMax;
  final bool hideStatus;

  SingleChatLoaded({required this.messages, this.hideStatus = false, this.hasReachedMax = false});
}
final class SingleChatError extends SingleChatState {}
final class SingleChatDeleted extends SingleChatState {}