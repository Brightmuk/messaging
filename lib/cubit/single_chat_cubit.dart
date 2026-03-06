import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/app_message.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:meta/meta.dart';

part 'single_chat_state.dart';

class SingleChatCubit extends Cubit<SingleChatState> {
  final String threadId;
  final SmsService _smsService = SmsService();
  int? targetTimestamp;
  StreamSubscription? _updateSubscription;
  SingleChatCubit(this.threadId, {this.targetTimestamp}) : super(SingleChatInitial()) {
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
    debugPrint("Handling event: ${event.type}");
    switch (event.type) {
      case SmsEventType.messageSent:
      case SmsEventType.messageDelivered:
      case SmsEventType.messageSendFailure:
        final updatedMessage = event.message;
        if (updatedMessage != null) {
          debugPrint("To update message: ${updatedMessage.id} body: ${updatedMessage.body}");
          messages = messages.map((msg) {
            if (msg.id == updatedMessage.id) {
              debugPrint("Updating message: ${msg.id}");
              return msg.copyWith(status: updatedMessage.status);
            }
            return msg;
          }).toList();
          emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus));
        }
        break;
      case SmsEventType.messagePending:
      case SmsEventType.messageReceived:
        final newMessage = event.message;
        if (newMessage != null && newMessage.threadId == threadId) {
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
        debugPrint("Fallen through: ${event.type}");
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
  if (_isFetching) return;
  if (!isInitialLoad && _hasReachedMax) return;

  _isFetching = true;

  if (isInitialLoad) {
    _currentPage = 0;
    _hasReachedMax = false;
   
    if (messages.isEmpty) emit(SingleChatLoading());
  }

  try {
    final newMessages = await _smsService.getMessagesForThread(
      threadId,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      targetTimestamp: targetTimestamp
    );

    if (newMessages.isEmpty || newMessages.length < _pageSize) {
      _hasReachedMax = true;
    }

    if (isInitialLoad) {
      messages = newMessages;
    } else {
      // Prevent duplicates if the scroll listener fired too fast
      final existingIds = messages.map((m) => m.id).toSet();
      final uniqueNewMessages = newMessages.where((m) => !existingIds.contains(m.id));
      messages.addAll(uniqueNewMessages);
    }

    _currentPage++;
    
    emit(SingleChatLoaded(
      messages: List.from(messages),
      hideStatus: hideStatus,
      hasReachedMax: _hasReachedMax,
    ));
  } catch (e) {
    emit(SingleChatError(error: "Failed to get messages"));
  } finally {
    _isFetching = false;
  }
}


  Future<void> sendMessage(String address, String message) async {
    final isDefault = await SmsService.isDefaultSmsApp();
    if (!isDefault) {
      SmsService.requestDefaultSmsRole();
      return;
    }
    await _smsService.sendSms(address, message, threadId);
  }
  Future<void> retrySend(AppSmsMessage message) async {
    await _smsService.retrySending(message);
  }

  Future<void> deleteMessages(List<AppSmsMessage> messages) async {
    await _smsService.deleteMessages(messages);
  }

  Future<void> markThreadAsRead() async {
    await _smsService.markThreadAsRead(threadId);
  }

  @override
  Future<void> close() {
    _updateSubscription?.cancel();
    return super.close();
  }
}

// class ThreadReadEvent {}
