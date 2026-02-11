part of 'single_chat_cubit.dart';

@immutable
sealed class SingleChatState {}

final class SingleChatInitial extends SingleChatState {}
final class SingleChatSending extends SingleChatState {}
final class SingleChatSendError extends SingleChatState {
  final String error;

  SingleChatSendError({required this.error});
  
}
final class SingleChatLoading extends SingleChatState {}
final class SingleChatLoaded extends SingleChatState {
  final List<AppSmsMessage> messages;
  final bool isUpdate;

  SingleChatLoaded({required this.messages, this.isUpdate = false});
}
final class SingleChatError extends SingleChatState {}