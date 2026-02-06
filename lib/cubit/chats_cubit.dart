import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:messaging/models/sms_message.dart';
import 'package:messaging/services/sms_service.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  final SmsService _smsService = SmsService();
  StreamSubscription? _updateSubscription;

  ChatsCubit() : super(ChatsInitial()) {
    _updateSubscription = _smsService.onMessageUpdated.listen((_) {
      loadChats(showLoading: false);
    });
    loadChats(showLoading: true);
  }

  Future<void> loadChats({bool showLoading = true}) async {
    if (showLoading) emit(ChatsLoading());
    try {
        await _smsService.syncExistingMessages();
        final chats = await _smsService.getAllChats();
      emit(ChatsLoaded(chats));
    } catch (e) {
      emit(ChatsError("Failed to load messages"));
    }
  }
  Future<void> deleteChat(String threadId) async {
    await _smsService.deleteThread(threadId);
    loadChats();
  }



  @override
  Future<void> close() {
    _updateSubscription?.cancel();
    return super.close();
  }
}