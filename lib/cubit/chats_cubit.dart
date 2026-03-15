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
 Future<bool> areRequiredPermissionsGiven() async {
  // final bool isDefault = await SmsService.isDefaultSmsApp();

  // final List<Permission> essentialPermissions = isDefault
  //     ? [Permission.sms, Permission.contacts, Permission.phone]
  //     : [Permission.sms];

  // // 3. Verify the relevant set
  // for (var p in essentialPermissions) {
  //   final status = await p.status;
  //   if (!status.isGranted) {
  //     return false; 
  //   }
  // }

  return true; 
}

  void _init() async {
    final permitted = await areRequiredPermissionsGiven();
    if (!permitted) {
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
      loadChats(isInitialLoad: true);
    });
    _isDemoMode = await UserDefaults.isDemoMode();
    _demoModeSubscription = eventBus.on<DemoMode>().listen((event) {
        _isDemoMode = event.isActive;
        loadChats(isInitialLoad: true);
      });
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
        loadChats(isInitialLoad: true);
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
  
  // 2. Permission Check
  final permitted = await areRequiredPermissionsGiven();
  if (!permitted) {
    emit(PermissionRevoked());
    return;
  }

  // 3. Status check for mode switching (Limited vs Full)
  final isDefault = await SmsService.isDefaultSmsApp();

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

  @override
  Future<void> close() {
    _smsSubscription?.cancel();
    _readSubscription?.cancel();
    _defaultAppTimer?.cancel();
    _demoModeSubscription?.cancel();
    return super.close();
  }
}
