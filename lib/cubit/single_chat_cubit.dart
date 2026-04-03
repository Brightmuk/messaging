import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/app_message.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:messaging/services/sound_service.dart';
import 'package:meta/meta.dart';

part 'single_chat_state.dart';

const anchorWindow = 20;

class SingleChatCubit extends Cubit<SingleChatState> {
  final String threadId;
  final String address;
  final SmsService _smsService = SmsService();
  int? targetTimestamp;
  StreamSubscription? _updateSubscription;

  // Anchor mode — true when opened from search
  bool get isAnchorMode => targetTimestamp != null;
  bool _hasReachedTop = false;
  bool _hasReachedBottom = false;
  bool get hasReachedBottom => _hasReachedBottom;
  bool get hasReachedTop => _hasReachedTop;

  // Separate tracking for each direction in anchor mode
  int? _oldestLoadedDate;
  int? _newestLoadedDate;

  SingleChatCubit(this.threadId, this.address, {this.targetTimestamp})
      : super(SingleChatInitial()) {
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
  final int _pageSize = 45;
  bool _isFetching = false;
  bool _hasReachedMax = false;
  bool get hasReachedMax => _hasReachedMax || _hasReachedTop;

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
            messages[idx] =
                messages[idx].copyWith(status: updatedMessage.status);
            emit(SingleChatMessageUpdated(
              messages: messages,
              hideStatus: hideStatus,
              updatedMessageId: updatedMessage.id!,
            ));
          } 
        }
        break;
      case SmsEventType.messageReceived:
        SoundService().playReceived();
        continue pending;
      pending:
      case SmsEventType.messagePending:
        final newMessage = event.message;
        if (newMessage != null && newMessage.threadId == threadId) {
          if (messages.contains(newMessage)) {
            final idx = messages.indexWhere((m) => m.id == newMessage.id);
            if (idx != -1) {
              messages[idx] = newMessage;
            }
          } else {
            messages.insert(0, newMessage);
          }
          emit(SingleChatLoaded(
              messages: List.unmodifiable(messages), hideStatus: hideStatus));
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
        final deleteSet = event.messages
            .map((m) => m.id)
            .toSet(); // use id not object equality
        messages =
            messages.where((msg) => !deleteSet.contains(msg.id)).toList();
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
    if (await _handleDemoMode()) return;
    if (_shouldSkipFetch(isInitialLoad)) return;

    _isFetching = true;
    _prepareInitialLoad(isInitialLoad);

    try {
      final newMessages = await _smsService.getMessagesForThread(
        threadId,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        targetTimestamp: isInitialLoad ? targetTimestamp : null,
      );

      _applyMessages(newMessages, isInitialLoad);

      _currentPage++;
      _oldestLoadedDate =
          messages.isNotEmpty ? messages.last.date : _oldestLoadedDate;

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

// Returns true if demo mode handled the emission — caller should return early
  Future<bool> _handleDemoMode() async {
    final isDemoMode = await UserDefaults.isDemoMode();
    if (!isDemoMode) return false;

    messages =
        DemoMessages.messages.where((m) => m.threadId == threadId).toList();

    emit(SingleChatLoaded(
      messages: messages,
      hideStatus: hideStatus,
      hasReachedMax: true,
    ));

    return true;
  }

// Returns true if the fetch should be skipped entirely
  bool _shouldSkipFetch(bool isInitialLoad) {
    if (_isFetching) return true;
    if (!isInitialLoad && !isAnchorMode && _hasReachedTop) return true;
    return false;
  }

// Resets pagination state and emits loading if this is a fresh load
  void _prepareInitialLoad(bool isInitialLoad) {
    if (!isInitialLoad) return;

    _currentPage = 0;
    _hasReachedTop = false;
    _hasReachedBottom = false;

    if (messages.isEmpty) emit(SingleChatLoading());
  }

  void _applyMessages(List<AppSmsMessage> newMessages, bool isInitialLoad) {
    if (isInitialLoad && isAnchorMode) {
      // First time on search
      _applyAnchorInitialLoad(newMessages);
    } else if (isInitialLoad) {
      //Normal conversation load
      _applyNormalInitialLoad(newMessages);
    } else {
      //Paginated history load

      _applyPaginatedLoad(newMessages);
    }
  }

  void _applyAnchorInitialLoad(List<AppSmsMessage> newMessages) {
    messages = newMessages;
    _oldestLoadedDate = messages.isNotEmpty ? messages.last.date : null;
    _newestLoadedDate = messages.isNotEmpty ? messages.first.date : null;
    _hasReachedTop = newMessages.length < anchorWindow;
    _hasReachedBottom = newMessages.length < anchorWindow;
  }

  void _applyNormalInitialLoad(List<AppSmsMessage> newMessages) {
    messages = newMessages;
    _hasReachedTop = newMessages.length < _pageSize;
  }

  void _applyPaginatedLoad(List<AppSmsMessage> newMessages) {
    messages.addAll(newMessages);
    _hasReachedTop = newMessages.length < _pageSize;
  }

  // Called when user scrolls DOWN (towards newer messages) in anchor mode
  Future<void> loadNewerMessages() async {
    if (!isAnchorMode || _hasReachedBottom || _isFetching) return;
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

      messages.insertAll(0, newer);
      _newestLoadedDate = newer.first.date;
      _hasReachedBottom = newer.length < _pageSize;

      emit(SingleChatLoaded(
        messages: List.from(messages),
        hideStatus: hideStatus,
        hasReachedMax: _hasReachedBottom,
      ));
    } finally {
      _isFetching = false;
    }
  }

  Future<void> loadOlderMessages() async {
    if (!isAnchorMode || _hasReachedTop || _isFetching) return;
    if (_oldestLoadedDate == null) return;

    _isFetching = true;
    try {
      final older = await _smsService.getMessagesBeforeTimestamp(
        threadId,
        beforeDate: _oldestLoadedDate!,
        limit: _pageSize,
      );

      if (older.isEmpty || older.length < _pageSize) _hasReachedBottom = true;
      if (older.isEmpty) return;

      messages.addAll(older.reversed.toList());
      _oldestLoadedDate = older.first.date;
      _hasReachedBottom = older.length < _pageSize;

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
    if(await UserDefaults.isDemoMode()) return;
    await _smsService.markThreadAsRead(threadId,address );
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
          body:
              "UBM487RO6P Confirmed. You have received Ksh1,500.00 from Kasongo Yeye 0700000000 on 9/3/26 at 9:15 AM. New M-PESA balance is Ksh5,420.00.",
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
          body:
              "41594319234 Confirmed. You have successfully purchased a bundle of Ksh 500 via Airtel Networks Kenya Ltd on 09/03/26 at 08:03 AM. Fee: Ksh 0. Bal: Ksh 1,200.00",
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
          body:
              "TKFL9EXWCM confirmed. Reversal of transaction TKFL9ADWCV has been successfully reversed on 8/3/26 at 10:48 PM and Ksh50.00 is debited from your M-PESA account. New M-PESA account balance is Ksh3,920.00.",
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
          body:
              "TK1888V9B3 Confirmed. Your account balance was: M-PESA Account : Ksh3,870.00 on 7/3/26 at 11:41 AM. Transaction cost, Ksh0.00.",
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
          body:
              "Failed. Insufficient funds in your M-PESA account to send Ksh10,000.00. Your M-PESA balance is Ksh3,870.00.",
          date: _oneDayAgo - 5000,
          type: 1,
          threadId: "mpesa_demo_id",
          status: MessageStatus.delivered,
          read: true,
          simId: 1,
        ),
      ];
}
