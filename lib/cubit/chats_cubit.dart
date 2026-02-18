import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/sms_message.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/sms_service.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  final SmsService _smsService = SmsService();
  StreamSubscription? _smsSubscription;
  StreamSubscription? _readSubscription;
  ChatsCubit() : super(ChatsInitial()) {
    _setupListeners();
    loadChats(showLoading: true);
    ContactService().init();
  }
  void _setupListeners() {
    _smsSubscription = _smsService.onMessageUpdated.listen((event) {
      loadChats(showLoading: false);
    });
    _readSubscription = eventBus.on<ThreadReadEvent>().listen((event) {
      loadChats(showLoading: false);
    });
  }

  List<AppChat> chats = [];
  Future<void> loadChats({bool showLoading = true}) async {
    if (showLoading) emit(ChatsLoading());
    
    try {
      final hasSynced = await UserDefaults.hasSynced();
      
      if (!hasSynced) {
        _smsService.syncExistingMessages();
      }

      chats = await _smsService.getAllChats();
      emit(ChatsLoaded(List.from(chats)));
    } catch (e) {
      debugPrint("Cubit Error: $e");
      emit(ChatsError("Unable to retrieve chats. Check permissions."));
    }
  }


  Future<void> deleteChat(String threadId) async {
    await _smsService.deleteThread(threadId);
    loadChats();
  }
  Future<void> deleteMultipleChats(Iterable<String> threadIds) async {
  // Option: emit(ChatsLoading()) if you want a full-screen spinner
  for (var id in threadIds) {
    await _smsService.deleteThread(id);
  }
  await loadChats(showLoading: false);
}

Future<void> archiveMultipleChats(Iterable<String> threadIds) async {
  for (var id in threadIds) {
    // Ensure your SmsService has an archiveThread method
    // await _smsService.archiveThread(id); 
  }
  await loadChats(showLoading: false);
}

Future<void> pinMultipleChats(Iterable<String> threadIds) async {
  for (var id in threadIds) {
    // Ensure your SmsService has a pinThread method
    // await _smsService.pinThread(id);
  }
  await loadChats(showLoading: false);
}

  @override
  Future<void> close() {
    _smsSubscription?.cancel();
    _readSubscription?.cancel();
    return super.close();
  }
}
