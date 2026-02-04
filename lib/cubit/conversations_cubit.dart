import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:messaging/models/sms_message.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:meta/meta.dart';

part 'conversations_state.dart';

class ConversationsCubit extends Cubit<ConversationsState> {
  final SmsService _smsService;
  StreamSubscription? _updateSubscription;

  ConversationsCubit(this._smsService) : super(ConversationsInitial()) {
    // Real-time listener: whenever the service says "new message", reload
    _updateSubscription = _smsService.onMessageUpdated.listen((_) {
      loadConversations(showLoading: false);
    });
  }

  Future<void> loadConversations({bool showLoading = true}) async {
    if (showLoading) emit(ConversationsLoading());
    try {
      var conversations = await _smsService.getAllConversations();
      if (conversations.isEmpty) {
        await _smsService.syncExistingMessages();
        conversations = await _smsService.getAllConversations();
      }
      emit(ConversationsLoaded(conversations));
    } catch (e) {
      emit(ConversationsError("Failed to load messages"));
    }
  }

  @override
  Future<void> close() {
    _updateSubscription?.cancel();
    return super.close();
  }
}