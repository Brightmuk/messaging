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

   // Anchor mode — true when opened from search
  bool get _isAnchorMode => targetTimestamp != null;
  bool _hasReachedTop = false;
  bool _hasReachedBottom = false;

  // Separate tracking for each direction in anchor mode
  int? _oldestLoadedDate;
  int? _newestLoadedDate;

  SingleChatCubit(this.threadId, {this.targetTimestamp}) : super(SingleChatInitial()) {
    getHideStatus();
    _setupListeners();
    getMessages();
  }
  void _setupListeners() async {
        _updateSubscription = _smsService.onMessageUpdated.listen((event) {
      Future.delayed(const Duration(milliseconds: 300)).then((_) {
        if (!isClosed) {
          handleSmsUpdates(event);
        }
      });
    });
        
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
            final idx = messages.indexWhere((m) => m.id == updatedMessage.id);
            if (idx != -1) {
              messages[idx] = messages[idx].copyWith(status: updatedMessage.status);
              emit(SingleChatMessageUpdated(
                messages: messages,
                hideStatus: hideStatus,
                updatedMessageId: updatedMessage.id!,
              ));
            }
          }
          break;
      case SmsEventType.messagePending:
      case SmsEventType.messageReceived:
        final newMessage = event.message;
         if (newMessage != null && newMessage.threadId == threadId) {
          if(messages.contains(newMessage)){
            final idx = messages.indexWhere((m) => m.id == newMessage.id);
            if (idx != -1) {
              messages[idx] = newMessage;
            }
          }else{
            messages.insert(0, newMessage); 
          }
          emit(SingleChatLoaded(messages: List.unmodifiable(messages), hideStatus: hideStatus));
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
        final deleteSet = event.messages.map((m) => m.id).toSet(); // use id not object equality
        messages = messages.where((msg) => !deleteSet.contains(msg.id)).toList();
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
    bool isDemoMode = await UserDefaults.isDemoMode();
    if (isDemoMode) {
      messages = DemoMessages.messages.where((m) => m.threadId == threadId).toList();
      emit(SingleChatLoaded(messages: messages, hideStatus: hideStatus, hasReachedMax: true));
      return;
    }

    if (_isFetching) return;
    if (!isInitialLoad && !_isAnchorMode && _hasReachedTop) return;

    _isFetching = true;

    if (isInitialLoad) {
      _currentPage = 0;
      _hasReachedTop = false;
      _hasReachedBottom = false;
      if (messages.isEmpty) emit(SingleChatLoading());
    }

    try {
      final newMessages = await _smsService.getMessagesForThread(
        threadId,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        targetTimestamp: isInitialLoad ? targetTimestamp : null,
      );

      if (isInitialLoad && _isAnchorMode) {
        messages = newMessages;
        // Track boundaries for directional pagination
        _oldestLoadedDate = messages.isNotEmpty ? messages.last.date : null;
        _newestLoadedDate = messages.isNotEmpty ? messages.first.date : null;
        _hasReachedTop = newMessages.length < 15;
        _hasReachedBottom = newMessages.length < 15;
      } else if (isInitialLoad) {
        messages = newMessages;
        _hasReachedTop = newMessages.length < _pageSize;
      } else {
        final existingIds = messages.map((m) => m.id).toSet();
        final unique = newMessages.where((m) => !existingIds.contains(m.id)).toList();
        messages.addAll(unique); // addAll appends to bottom (older msgs in reversed list)
        _hasReachedTop = unique.length < _pageSize;
      }

      _currentPage++;
      _oldestLoadedDate = messages.isNotEmpty ? messages.last.date : _oldestLoadedDate;

      emit(SingleChatLoaded(
        messages: List.from(messages),
        hideStatus: hideStatus,
        hasReachedMax: _hasReachedTop,
        anchorTimestamp: isInitialLoad ? targetTimestamp : null,
      ));
    } catch (e) {
      emit(SingleChatError(error: "Failed to get messages"));
    } finally {
      _isFetching = false;
    }
  }
    // Called when user scrolls DOWN (towards newer messages) in anchor mode
  Future<void> loadNewerMessages() async {
    if (!_isAnchorMode || _hasReachedBottom || _isFetching) return;
    if (_newestLoadedDate == null) return;

    _isFetching = true;
    try {
      final newer = await _smsService.getMessagesAfterTimestamp(
        threadId,
        afterDate: _newestLoadedDate!,
        limit: _pageSize,
      );

      if (newer.isEmpty || newer.length < _pageSize) _hasReachedBottom = true;
      if (newer.isEmpty) return;

      final existingIds = messages.map((m) => m.id).toSet();
      final unique = newer.where((m) => !existingIds.contains(m.id)).toList();
      messages.insertAll(0, unique); // prepend — newer msgs go to top of reversed list
      _newestLoadedDate = messages.first.date;

      emit(SingleChatLoaded(
        messages: List.from(messages),
        hideStatus: hideStatus,
        hasReachedMax: _hasReachedTop,
      ));
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

class DemoMessages {
  // Use getters to ensure 'now' is fresh whenever the list is accessed
  static int get _now => DateTime.now().millisecondsSinceEpoch;
  static int get _oneHourAgo => _now - (3600 * 1000);
  static int get _oneDayAgo => _now - (86400 * 1000);

  static List<AppSmsMessage> get messages => [
        // 1. M-PESA: Recent Received (Triggers the Vault Tile)
        AppSmsMessage(
          id: 101,
          address: "MPESA",
          body: "UBM487RO6P Confirmed. You have received Ksh1,500.00 from Kasongo Yeye 0700000000 on 9/3/26 at 9:15 AM. New M-PESA balance is Ksh5,420.00.",
          date: _now,
          type: 1,
          threadId: "mpesa_demo_id",
          status: MessageStatus.delivered,
          read: false,
          simId: 1,
        ),

        // 2. Airtel Money: Bundle Purchase (Triggers Red Palette)
        AppSmsMessage(
          id: 201,
          address: "AirtelMoney",
          body: "41594319234 Confirmed. You have successfully purchased a bundle of Ksh 500 via Airtel Networks Kenya Ltd on 09/03/26 at 08:03 AM. Fee: Ksh 0. Bal: Ksh 1,200.00",
          date: _oneHourAgo,
          type: 1,
          threadId: "airtel_demo_id",
          status: MessageStatus.delivered,
          read: false,
          simId: 2,
        ),

        // 3. M-PESA: Reversal
        AppSmsMessage(
          id: 102,
          address: "MPESA",
          body: "TKFL9EXWCM confirmed. Reversal of transaction TKFL9ADWCV has been successfully reversed on 8/3/26 at 10:48 PM and Ksh50.00 is debited from your M-PESA account. New M-PESA account balance is Ksh3,920.00.",
          date: _oneDayAgo,
          type: 1,
          threadId: "mpesa_demo_id",
          status: MessageStatus.delivered,
          read: true,
          simId: 1,
        ),

        // 4. M-PESA: Balance Check (Triggers "Checked balance" Privacy Rule)
        AppSmsMessage(
          id: 103,
          address: "MPESA",
          body: "TK1888V9B3 Confirmed. Your account balance was: M-PESA Account : Ksh3,870.00 on 7/3/26 at 11:41 AM. Transaction cost, Ksh0.00.",
          date: _oneDayAgo - 1000,
          type: 1,
          threadId: "mpesa_demo_id",
          status: MessageStatus.delivered,
          read: true,
          simId: 1,
        ),

        // 5. M-PESA: Failed Transaction (Triggers Tonal Error Style)
        AppSmsMessage(
          id: 104,
          address: "MPESA",
          body: "Failed. Insufficient funds in your M-PESA account to send Ksh10,000.00. Your M-PESA balance is Ksh3,870.00.",
          date: _oneDayAgo - 5000,
          type: 1,
          threadId: "mpesa_demo_id",
          status: MessageStatus.delivered,
          read: true,
          simId: 1,
        ),
      ];

}
