import 'package:bloc/bloc.dart';
import 'package:messaging/models/sms_message.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:meta/meta.dart';

part 'single_chat_state.dart';

class SingleChatCubit extends Cubit<SingleChatState> {
  final String threadId;
    final SmsService _smsService = SmsService();
  SingleChatCubit(this.threadId) : super(SingleChatInitial()){
    getMessages();
  }

    Future<void> setAsDefaultApp() async {
    await _smsService.requestDefaultSmsApp();
  }
  List<AppSmsMessage> messages = [];
  Future<void> getMessages() async {
    emit(SingleChatLoading());
    final messages = await _smsService.getMessagesForThread(threadId);
    this.messages = messages;
    emit(SingleChatLoaded(messages));
  }
  Future<void> sendMessage(String address, String message) async {
    emit(SingleChatSending());
    final success = await _smsService.sendSms(address, message, threadId);
    if (success) {
      getMessages();
    } else {
      emit(SingleChatError());
    }
  }


  Future<void> deleteMessage(int messageId) async {
    await _smsService.deleteMessage(messageId);
    getMessages();
  }

  Future<void> markThreadAsRead() async {
    await _smsService.markThreadAsRead(threadId);
  }
}
