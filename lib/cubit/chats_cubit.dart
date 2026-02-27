import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/user_defaults.dart';
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
      debugPrint("\nChats Cubit message event: ${event.type}\n");
      loadChats(isInitialLoad: true);
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
    debugPrint("Loading chats...");
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
    return super.close();
  }
}
