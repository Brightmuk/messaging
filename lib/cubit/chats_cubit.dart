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
  final SmsService _smsService = SmsService();
  StreamSubscription? _smsSubscription;
  StreamSubscription? _readSubscription;
  ChatsCubit() : super(ChatsInitial()) {
    _setupListeners();
    loadChats(isInitialLoad: true);
    ContactService().init();
  }
  void _setupListeners() {
    _smsSubscription = _smsService.onMessageUpdated.listen((event) {
      loadChats(isInitialLoad: false);
    });
    _readSubscription = eventBus.on<ThreadReadEvent>().listen((event) {
      loadChats(isInitialLoad: false);
    });
  }

  List<AppChat> chats = [];
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isFetching = false;
  bool _hasReachedMax = false;
  bool get hasReachedMax => _hasReachedMax;

  Future<void> loadChats({bool isInitialLoad = true}) async {
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

  Future<void> deleteChat(String threadId) async {
    await _smsService.deleteThread(threadId);
    loadChats(isInitialLoad: true);
  }

  Future<void> deleteMultipleChats(Iterable<String> threadIds) async {
    // Option: emit(ChatsLoading()) if you want a full-screen spinner
    for (var id in threadIds) {
      await _smsService.deleteThread(id);
    }
    await loadChats(isInitialLoad: true);
  }

  Future<void> archiveChats(Iterable<String> threadIds) async {
    for (var id in threadIds) {
      _smsService.markThreadAsArchived(id, true);
    }
    await loadChats(isInitialLoad: true);
  }

  Future<void> unArchiveChats(Iterable<String> threadIds) async {
    for (var id in threadIds) {
      await _smsService.markThreadAsArchived(id, false);
    }
    await loadChats(isInitialLoad: true);
  }

  Future<void> pinChats(Iterable<String> threadIds) async {
    for (var id in threadIds) {
      await _smsService.markThreadAsPinned(id, true);
    }
    await loadChats(isInitialLoad: true);
  }

  Future<void> unpinChats(Iterable<String> threadIds) async {
    for (var id in threadIds) {
      await _smsService.markThreadAsPinned(id, false);
    }
    await loadChats(isInitialLoad: true);
  }

  @override
  Future<void> close() {
    _smsSubscription?.cancel();
    _readSubscription?.cancel();
    return super.close();
  }
}
