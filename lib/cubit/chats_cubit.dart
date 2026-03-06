import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:permission_handler/permission_handler.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  late SmsService _smsService;
  StreamSubscription? _smsSubscription;
  StreamSubscription? _readSubscription;
  ChatsCubit() : super(ChatsInitial()) {
    _init();
  }
  Future<bool> areRequiredPermissionsGiven() async {
    bool allPermissionsGranted = true;
    for (var p in [
      Permission.sms,
      Permission.contacts,
      Permission.phone,
    ]) {
      final status = await p.status;
      if (!status.isGranted) {
        allPermissionsGranted = false;
        break;
      }
    }
    return allPermissionsGranted;
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

  void _setupListeners() {
    _smsSubscription = _smsService.onMessageUpdated.listen((event) {
      debugPrint("\nChats Cubit message event: ${event.type}\n");
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
        _init();
      } else {
        debugPrint("Still waiting for default role... (${_count}s)");
      }
      if (_count >= 10) {
        timer.cancel();
      }
    });
    emit(PermissionRevoked());
  }

  List<AppChat> chats = [];
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isFetching = false;
  bool _hasReachedMax = false;
  bool get hasReachedMax => _hasReachedMax;

  Future<void> loadChats({bool isInitialLoad = true}) async {
    final permitted = await areRequiredPermissionsGiven();
    if (!permitted) {
      emit(PermissionRevoked());
      return;
    }

    if (_isFetching || (!isInitialLoad && _hasReachedMax)) return;
    _isFetching = true;

    if (isInitialLoad) {
      _currentPage = 0;
      _hasReachedMax = false;
      // Only show full screen loading if we have no data yet
      if (chats.isEmpty) emit(ChatsLoading());
    }

    try {
      final hasSynced = await UserDefaults.hasSynced();
      if (!hasSynced) {
        await _smsService.syncExistingMessages();
      }

      final newChats = await _smsService.getPaginatedChats(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      if (newChats.length < _pageSize) {
        _hasReachedMax = true;
      }

      if (isInitialLoad) {
        chats = newChats;
      } else {
        final existingIds = chats.map((c) => c.threadId).toSet();
        final uniqueNewChats =
            newChats.where((c) => !existingIds.contains(c.threadId));
        chats.addAll(uniqueNewChats);
      }

      _currentPage++;

      emit(ChatsLoaded(List.from(chats)));
    } catch (e) {
      debugPrint("Cubit Error: $e");
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

  @override
  Future<void> close() {
    _smsSubscription?.cancel();
    _readSubscription?.cancel();
    _defaultAppTimer?.cancel();
    return super.close();
  }
}
