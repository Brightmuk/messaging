import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/models/sms_message.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:meta/meta.dart';

part 'single_chat_state.dart';

class SingleChatCubit extends Cubit<SingleChatState> {
  final String threadId;
    final SmsService _smsService = SmsService();
     StreamSubscription? _updateSubscription;
  SingleChatCubit(this.threadId) : super(SingleChatInitial()){
        _updateSubscription = _smsService.onMessageUpdated.listen((_) {
     
      Future.delayed(const Duration(milliseconds: 500), () => getMessages(showLoading: false));
    });
    getMessages();
  }

    Future<void> setAsDefaultApp() async {
    await SmsService.requestDefaultSmsRole();
  }
  List<AppSmsMessage> messages = [];
  Future<void> getMessages({bool showLoading = true}) async {
    if (showLoading) {
      emit(SingleChatLoading());
    }

    final messages = await _smsService.getMessagesForThread(threadId);
    this.messages = messages;
    emit(SingleChatLoaded(messages: messages, isUpdate: !showLoading));
  }
  Future<void> sendMessage(String address, String message) async {
    emit(SingleChatSending());
    final success = await _smsService.sendSms(address, message, threadId);
    if (success) {
      getMessages();
    } else {
      emit(SingleChatSendError(error: 'Error sending sms'));
    }
  }


  Future<void> deleteMessage(int messageId) async {
    await _smsService.deleteMessage(messageId);
    getMessages();
  }

  Future<void> markThreadAsRead() async {
    await _smsService.markThreadAsRead(threadId);
    eventBus.fire(ThreadReadEvent());
  }
  @override
  Future<void> close() {
    _updateSubscription?.cancel();
    return super.close();
  }
}
class ThreadReadEvent{}
