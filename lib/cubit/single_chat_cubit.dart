import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/app_message.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:meta/meta.dart';

part 'single_chat_state.dart';

class SingleChatCubit extends Cubit<SingleChatState> {
  final String threadId;
  final SmsService _smsService = SmsService();
  StreamSubscription? _updateSubscription;
  SingleChatCubit(this.threadId) : super(SingleChatInitial()) {
    getHideStatus();
    _updateSubscription = _smsService.onMessageUpdated.listen((event) {
      Future.delayed(const Duration(milliseconds: 300)).then((_) {
        if (!isClosed) {
          handleSmsUpdates(event);
        }
      });
    });
    getMessages();
  }
  List<AppSmsMessage> messages = [];
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isFetching = false;
  bool _hasReachedMax = false;
  bool get hasReachedMax => _hasReachedMax;


  void handleSmsUpdates(SmsEvent event) {
    switch (event.type) {
      case SmsEventType.messageSent:
      case SmsEventType.messageDelivered:
      case SmsEventType.messageSendFailure:
        final failedMessage = event.message;
        if (failedMessage != null) {
          messages = messages
              .map((msg) => msg.id == failedMessage.id
                  ? failedMessage.copyWith(status: msg.status)
                  : msg)
              .toList();
          emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus));
        }
        break;
      case SmsEventType.messagePending:
      case SmsEventType.messageReceived:
        final newMessage = event.message;
        if (newMessage != null) {
          messages = [newMessage, ...messages];
          emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus));
        }
        break;
      case SmsEventType.messageDeleted:
        if (event.message == null || event.message!.id == null) return;
        messages =
            messages.where((msg) => msg.id != event.message!.id).toList();
        if (messages.isEmpty) {
          emit(SingleChatDeleted());
        } else {
          emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus));
        }

        break;
      case SmsEventType.messagesDeletedAll:
        if (event.messages.isEmpty) return;
        messages =
            messages.where((msg) => !event.messages.contains(msg)).toList();
        emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus));
        if (messages.isEmpty) {
          emit(SingleChatDeleted());
        } else {
          emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus));
        }
        break;

      default:
        debugPrint("Update: ${event.type}");
    }
  }

  bool hideStatus = true;
  Future<void> getHideStatus() async {
    hideStatus = await UserDefaults.getHideStatus();
  }

  Future<void> toggleHide() async {
    hideStatus = !hideStatus;
    emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus));
  }

  Future<void> setAsDefaultApp() async {
    await SmsService.requestDefaultSmsRole();
  }

Future<void> getMessages({bool isInitialLoad = true}) async {
  if(!isInitialLoad) debugPrint("Loading more...");
  if (_isFetching || (_hasReachedMax && !isInitialLoad)) return;

  _isFetching = true;

  if (isInitialLoad) {
    _currentPage = 0;
    _hasReachedMax = false;
    emit(SingleChatLoading());
  }

  final newMessages = await _smsService.getMessagesForThread(
    threadId,
    limit: _pageSize,
    offset: _currentPage * _pageSize,
  );

  if (newMessages.length < _pageSize) {
    _hasReachedMax = true;
  }

  if (isInitialLoad) {
    messages = newMessages;
  } else {

    messages.addAll(newMessages);
  }

  _currentPage++;
  _isFetching = false;

  emit(SingleChatLoaded(
    messages: List.from(messages), 
    hideStatus: hideStatus,
    hasReachedMax: _hasReachedMax,
  ));
}

  Future<void> sendMessage(String address, String message) async {
    emit(SingleChatSending());
    await _smsService.sendSms(address, message, threadId);
  }

  Future<void> deleteMessages(Iterable<AppSmsMessage> messages) async {
    for (var message in messages) {
      if (message.id != null) {
        await _smsService.deleteMessage(message);
      }
    }
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

class ThreadReadEvent {}
