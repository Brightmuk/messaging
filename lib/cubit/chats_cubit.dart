import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/sms_service.dart';
part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  late SmsService _smsService;
  StreamSubscription? _smsSubscription;
  StreamSubscription? _readSubscription;
  StreamSubscription? _demoModeSubscription;
  ChatsCubit() : super(ChatsInitial()) {
    _init();
  }


  void _init() async {
    final isDefault = await SmsService.isDefaultSmsApp();
    if(!isDefault){
      emit(PermissionRevoked());
      return;
    }
    _smsService = SmsService();
    _setupListeners();
    loadChats(isInitialLoad: true);
    ContactService().init();
  }
  bool _isDemoMode = false;
  void _setupListeners() async {
  _smsSubscription = _smsService.onMessageUpdated.listen((event) {
    debugPrint("\nChats Cubit message event: ${event.type}\n");
    _handleSmsEvent(event); // replace loadChats with targeted handler
  });
  _isDemoMode = await UserDefaults.isDemoMode();
  _demoModeSubscription = eventBus.on<DemoMode>().listen((event) {
    _isDemoMode = event.isActive;
    loadChats(isInitialLoad: true);
  });
}

void _handleSmsEvent(SmsEvent event) {
  // If not loaded yet, nothing to mutate — let normal load handle it
  if (state is! ChatsLoaded) return;
  if (_isDemoMode) return;

  switch (event.type) {

    // A new message came in — update or prepend the chat
    case SmsEventType.messageReceived:
    case SmsEventType.messagePending:
      final msg = event.message;
      if (msg == null) return;
      _upsertChat(
        threadId: msg.threadId,
        address: msg.address,
        lastMessage: msg.body,
        lastMessageDate: msg.date,
        incrementUnread: event.type == SmsEventType.messageReceived,
      );
      break;

    // Status tick on outgoing message — no chat list change needed at all
    case SmsEventType.messageSent:
    case SmsEventType.messageDelivered:
    case SmsEventType.messageSendFailure:
      // Chat list doesn't show delivery status — skip the fetch entirely
      break;

    // Thread was read, pinned, archived, or deleted — mutate in place
    case SmsEventType.threadUpdated:
      _refreshThreadsFromDb(); // selective refresh, see below
      break;

    case SmsEventType.messageDeleted:
    case SmsEventType.messagesDeletedAll:
      final msg = event.message ?? event.messages.firstOrNull;
      if (msg == null) return;
      _handleMessageDeleted(msg.threadId);
      break;

    // Full sync completed on first launch — do a real load once
    case SmsEventType.syncCompleted:
      // loadChats(isInitialLoad: true);
      break;

    }
}
  

  Timer? _defaultAppTimer;
  int _count = 0;
  Future<void> requestDefaultRole() async {
    await SmsService.requestDefaultSmsRole();
    _defaultAppTimer?.cancel();
    _defaultAppTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      _count++;
      final isDefault = await SmsService.isDefaultSmsApp();
      if (isDefault) {
        debugPrint("App is now default SMS app");
        timer.cancel();
        _init();
      } else {
        debugPrint("Still waiting for default role... (${_count}s)");
      }
      if (_count >= 10) {
        timer.cancel();
      }
    });
    
  }

  List<AppChat> chats = [];
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isFetching = false;
  bool _hasReachedMax = false;
  bool get hasReachedMax => _hasReachedMax;

Future<void> loadChats({bool isInitialLoad = true}) async {

  // 1. Guard against concurrent fetches
  if (_isFetching) return;
  

  // 3. Status check for mode switching (Limited vs Full)
  final isDefault = await SmsService.isDefaultSmsApp();
  if(!isDefault){
    emit(PermissionRevoked());
    return;
  }

  if(_isDemoMode){
    return  emit(ChatsLoaded(getDemoChats(),isDefaultApp: isDefault));
  }
  
  // Determine if we need to reset the list (e.g., mode changed or initial load)
  final bool shouldReset = isInitialLoad || (state is ChatsLoaded && (state as ChatsLoaded).isDefaultApp != isDefault);

  if (!shouldReset && _hasReachedMax) return;

  _isFetching = true;

  if (shouldReset) {
    _currentPage = 0;
    _hasReachedMax = false;
    // Don't emit Loading if we already have data (prevents white flicker)
    if (chats.isEmpty) emit(ChatsLoading());
  }

  try {
    // Only sync if never done before
    if (!await UserDefaults.hasSynced()) {
      await _smsService.syncExistingMessages();
    }

    final newChats = await _smsService.getPaginatedChats(
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      isDefaultApp: isDefault
    );

    if (newChats.length < _pageSize) {
      _hasReachedMax = true;
    }

    if (shouldReset) {
      chats = newChats;
    } else {
      // Append for pagination
      final existingIds = chats.map((c) => c.threadId).toSet();
      chats.addAll(newChats.where((c) => !existingIds.contains(c.threadId)));
    }

    _currentPage++;
    emit(ChatsLoaded(List.from(chats), isDefaultApp: isDefault));
  } catch (e) {
    emit(ChatsError("Unable to retrieve chats."));
  } finally {
    _isFetching = false;
  }
}

  Future<void> deleteThreads(Iterable<String> threadIds) async {
    await _smsService.deleteThreads(threadIds);
  }

  Future<void> archiveChats(Iterable<String> threadIds) async {
    await _smsService.markThreadsAsArchived(threadIds, true);
  }

  Future<void> pinChats(Iterable<String> threadIds, bool pinned) async {
    await _smsService.markThreadsAsPinned(threadIds, pinned);
  }
  List<AppChat> getDemoChats() {
  return [
    AppChat(
      address: "MPESA",
      unreadCount: 2,
      threadId: 'mpesa_demo_id',
      lastMessageDate: DateTime.now().millisecondsSinceEpoch,
      lastMessage:  DemoMessages.messages[0].body,
    ),
    AppChat(
      address: "AirtelMoney",
      unreadCount: 0,
      threadId: 'airtel_demo_id',
      lastMessageDate: DateTime.now().millisecondsSinceEpoch,
      lastMessage: DemoMessages.messages[1].body,
    ),
  ];
}
// Moves updated/new chat to top of list without re-fetching
void _upsertChat({
  required String threadId,
  required String address,
  required String lastMessage,
  required int lastMessageDate,
  bool incrementUnread = false,
}) {
  final existing = chats.indexWhere((c) => c.threadId == threadId);

  AppChat updated;
  if (existing != -1) {
    final chat = chats[existing];
    updated = chat.copyWith(
      lastMessage: lastMessage,
      lastMessageDate: lastMessageDate,
      unreadCount: incrementUnread ? (chat.unreadCount + 1) : chat.unreadCount,
    );
    chats.removeAt(existing);
  } else {
    // Brand new thread not yet in our list
    updated = AppChat(
      threadId: threadId,
      address: address,
      lastMessage: lastMessage,
      lastMessageDate: lastMessageDate,
      unreadCount: incrementUnread ? 1 : 0,
    );
  }

  // Pinned chats stay at top, new activity inserts after pinned
  final lastPinnedIndex = chats.lastIndexWhere((c) => c.isPinned);
  chats.insert(lastPinnedIndex + 1, updated);

  emit(ChatsLoaded(List.from(chats), isDefaultApp: true));
}

// For thread state changes (read/pinned/archived) — fetch only affected threads
Future<void> _refreshThreadsFromDb() async {
  // Re-fetch just the current page worth we already have — not a full reset
  final isDefault = await SmsService.isDefaultSmsApp();
  final refreshed = await _smsService.getPaginatedChats(
    limit: _currentPage * _pageSize, 
    offset: 0,
    isDefaultApp: isDefault,
  );
  chats = refreshed;
  _hasReachedMax = refreshed.length < _currentPage * _pageSize;
  emit(ChatsLoaded(List.from(chats), isDefaultApp: isDefault));
}

// Remove or update chat when messages are deleted
Future<void> _handleMessageDeleted(String threadId) async {
  // Ask DB if thread still has messages
  final remaining = await _smsService.getMessagesForThread(threadId, limit: 1);
  if (remaining.isEmpty) {
    chats.removeWhere((c) => c.threadId == threadId);
  } else {
    final latest = remaining.first;
    final idx = chats.indexWhere((c) => c.threadId == threadId);
    if (idx != -1) {
      chats[idx] = chats[idx].copyWith(
        lastMessage: latest.body,
        lastMessageDate: latest.date,
      );
    }
  }
  emit(ChatsLoaded(List.from(chats), isDefaultApp: true));
}

  @override
  Future<void> close() {
    _smsSubscription?.cancel();
    _readSubscription?.cancel();
    _defaultAppTimer?.cancel();
    _demoModeSubscription?.cancel();
    return super.close();
  }
}
