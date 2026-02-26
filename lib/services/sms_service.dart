import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_telephony/telephony.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/services/contact_db.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sim_card_info/sim_card_info.dart';
import 'package:sim_card_info/sim_info.dart';
import 'package:uuid/uuid.dart';
import '../models/app_message.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'dart:async';

@pragma('vm:entry-point')
class SmsService {
  // Singleton pattern
  SmsService._internal() {
    initialize();
  }
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;

  final Telephony telephony = Telephony.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final NotificationService _notificationService = NotificationService();

  static const _channel = MethodChannel('com.brimukon.messaging.sms_role');

  final _messageUpdateController = StreamController<SmsEvent>.broadcast();
  Stream<SmsEvent> get onMessageUpdated => _messageUpdateController.stream;

  final Map<int, Timer> _activeTimeouts = {};

  static Future<bool> isDefaultSmsApp() async {
    try {
      return await _channel.invokeMethod('isDefaultSmsApp');
    } on PlatformException catch (e) {
      debugPrint("Failed to check SMS role: ${e.message}");
      return false;
    }
  }

  static Future<void> requestDefaultSmsRole() async {
    try {
      await _channel.invokeMethod('requestDefaultSmsRole');
    } on PlatformException catch (e) {
      debugPrint("Failed to request SMS role: ${e.message}");
    }
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.phone,
      Permission.contacts,
      Permission.notification,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }


  Future<void> initialize() async {
    await _notificationService.initialize();
    telephony.listenIncomingSms(
      onNewMessage: _onMessageReceived,
      onBackgroundMessage: _onBackgroundMessage,
    );
  }

  Future<List<SimInfo>> getSimcards() async {
    final simCardInfoPlugin = SimCardInfo();
    try {
      return await simCardInfoPlugin.getSimInfo() ?? [];
    } on PlatformException {
      return [];
    }
  }

  Future<void> setDefaultSim(int id) {
    return UserDefaults.setDefaultSim(id);
  }

  Future<int> getDefaultSim() {
    return UserDefaults.getDefaultSim();
  }

  Future<AppSimCardState> getSimState() async {
    int id = await getDefaultSim();
    List<SimInfo> simcards = await getSimcards();

    return AppSimCardState(
        defaultCard: id == -1 ? null : id, allCards: simcards);
  }


  Future<void> syncExistingMessages() async {
    debugPrint("Syncing history from system provider...");

    // Fetch all inbox messages
    List<SmsMessage> messages = await telephony.getInboxSms(columns: [
      SmsColumn.ADDRESS,
      SmsColumn.BODY,
      SmsColumn.DATE,
      SmsColumn.THREAD_ID,
      SmsColumn.READ
    ], sortOrder: [
      OrderBy(SmsColumn.DATE, sort: Sort.ASC)
    ]);

    if (messages.isEmpty) return;

    await _dbHelper.batchSyncMessages(messages);

    UserDefaults.setHasSynced();
    _messageUpdateController.add(SmsEvent(type: SmsEventType.syncCompleted));
  }

  Future<void> startSendTimeout(AppSmsMessage smsMessage) async {
    if (smsMessage.id == null) return;
    final messageId = smsMessage.id!;
    _activeTimeouts[messageId] = Timer(const Duration(seconds: 15), () async {
      await markMessageAsFailed(smsMessage.copyWith(id: messageId));
      _activeTimeouts.remove(messageId);
    });
  }

  Future<void> cancelSendTimeout(int messageId) async {
    _activeTimeouts[messageId]?.cancel();
    _activeTimeouts.remove(messageId);
  }

  Future<bool> sendSms(String address, String message, String threadId) async {
    int? defaultSim = await getDefaultSim();
    final date = DateTime.now().millisecondsSinceEpoch;
    final smsMessage = AppSmsMessage(
      status: MessageStatus.pending,
      address: address,
      body: message,
      date: date,
      type: 2, // Sent
      threadId: threadId,
      read: true,
      simId: defaultSim,
    );
    int messageId = await _dbHelper.insertMessage(smsMessage);
    await _updateChat(threadId, address, message, date);
    await startSendTimeout(smsMessage.copyWith(id: messageId));

    try {
      await telephony.sendSms(
        to: address,
        message: message,
        subscriptionId: defaultSim + 1,
        statusListener: (status) async {
          debugPrint("\nSend Status: $status\n");
          //Seems like sent doesnt always guarantee the message left the device
          // if (status == SendStatus.SENT) {
          //   await cancelSendTimeout(messageId);
          //   await markMessageAsSent(smsMessage.copyWith(id: messageId));
          // }

          if (status == SendStatus.DELIVERED) {
             await cancelSendTimeout(messageId);
            await markMessageAsDelivered(smsMessage.copyWith(id: messageId));
          }
        },
      );

      _messageUpdateController.add(
          SmsEvent(type: SmsEventType.messagePending, message: smsMessage.copyWith(id: messageId)));
      return true;
    } catch (e) {
      await cancelSendTimeout(messageId);
      await markMessageAsFailed(smsMessage.copyWith(id: messageId));
      debugPrint('Send error: $e');
      return false;
    }
  }
  Future<void> retrySending(AppSmsMessage message) async {
    int? defaultSim = await getDefaultSim();
    if(message.id == null) return;
    await startSendTimeout(message);

    try {
      await telephony.sendSms(
        to: message.address,
        message: message.body,
        subscriptionId: defaultSim + 1,
        statusListener: (status) async {
          debugPrint("\nSend Status: $status\n");
          //Seems like sent doesnt always guarantee the message left the device
          // if (status == SendStatus.SENT) {
          //   await cancelSendTimeout(messageId);
          //   await markMessageAsSent(smsMessage.copyWith(id: messageId));
          // }

          if (status == SendStatus.DELIVERED) {
            await markMessageAsDelivered(message);
          }
        },
      );

      _messageUpdateController.add(
          SmsEvent(type: SmsEventType.messagePending, message: message));
     
    } catch (e) {
      await cancelSendTimeout(message.id!);
      await markMessageAsFailed(message);
      debugPrint('Send error: $e');
    }
  }
  Future<List<AppChat>> getArchivedChats(){
    return _dbHelper.getArchivedChats();
  }
  Future<int> getArchivedCount(){
    return _dbHelper.getArchivedCount();
  }


  Future<void> markMessageAsSent(AppSmsMessage message) async {
    if(message.id == null) return;
    await _dbHelper.markMessageAsSent(message.id!);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.messageSent, message: message.copyWith(status: MessageStatus.sent)));
  }

  Future<void> markMessageAsDelivered(AppSmsMessage message) async {
    if(message.id == null) return;
    await _dbHelper.markMessageAsDelivered(message.id!);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.messageDelivered, message: message.copyWith(status: MessageStatus.delivered)));
  }

  Future<void> markMessageAsFailed(AppSmsMessage message) async {
    if(message.id == null) return;
    await _dbHelper.markMessageAsFailed(message.id!);
    _messageUpdateController
        .add(SmsEvent(type: SmsEventType.messageSendFailure, message: message.copyWith(status: MessageStatus.failed)));
  }

  Future<void> markThreadAsPinned(String threadId, bool isPinned) async {
    await _dbHelper.markThreadAsPinned(threadId, isPinned);
  }

  Future<void> markThreadAsArchived(String threadId, bool isArchived) async {
    await _dbHelper.markThreadAsArchived(threadId, isArchived);
  }

  void _onMessageReceived(SmsMessage message) async {
    final threadId = await getThreadId(message.address);
    await _saveIncomingMessage(
        message, threadId, await getContactName(message.address ?? ''));
  }

  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(SmsMessage message) async {
    final service = SmsService();
    final threadId = await _getThreadIdSt(message.address);
    final db = ContactDb();
    final String? contactName = await db.getName(message.address ?? "");

    final String title = contactName ?? message.address ?? "New Message";
    await service._saveIncomingMessage(message, threadId, title);
  }

  Future<void> _saveIncomingMessage(
      SmsMessage msg, String threadId, String name) async {
    final appMsg = AppSmsMessage(
      status: MessageStatus.unknown,
      address: msg.address ?? '',
      body: msg.body ?? '',
      date: msg.date ?? DateTime.now().millisecondsSinceEpoch,
      type: 1, // Received
      threadId: threadId,
      read: false,
      simId: msg.subscriptionId ?? -1,
    );

    await _dbHelper.insertMessage(appMsg);
    await _updateChat(threadId, appMsg.address, appMsg.body, appMsg.date,
        incrementUnread: true);
    _messageUpdateController
        .add(SmsEvent(type: SmsEventType.messageReceived, message: appMsg));

    await _notificationService.showNotification(
      title: name,
      body: appMsg.body,
      payload: json.encode({'threadId': threadId, "address": appMsg.address}),
    );
  }

  Future<String> getThreadId(String? address) async {
    if (address == null) return const Uuid().v4();
    final chats = await _dbHelper.getAllChats();
    AppChat? chat = chats.where((chat) {
      return chat.isSameThread(null, address);
    }).firstOrNull;
    return chat?.threadId ?? const Uuid().v4();
  }

  static Future<String> _getThreadIdSt(String? address) async {
    if (address == null) return const Uuid().v4();
    final chats = await DatabaseHelper.instance.getAllChats();
    AppChat? chat =
        chats.where((chat) => chat.isSameThread(null, address)).firstOrNull;
    return chat?.threadId ?? const Uuid().v4();
  }


  Future<void> _updateChat(String tId, String addr, String msg, int date,
      {bool incrementUnread = false}) async {
    await _dbHelper.upsertChat(
        AppChat(
          threadId: tId,
          address: addr,
          lastMessage: msg,
          lastMessageDate: date,
          unreadCount:
              0, 
        ),
        incrementUnread: incrementUnread);
  }

 Future<List<AppChat>> getPaginatedChats({required int limit, required int offset}) {
  return _dbHelper.getPaginatedChats(limit: limit, offset: offset);
}

Future<List<AppSmsMessage>> getMessagesForThread(
  String threadId, {
  int limit = 20, 
  int offset = 0,
}) => _dbHelper.getMessagesForThread(threadId, limit: limit, offset: offset);

  Future<void> markThreadAsRead(String threadId) async {
    await _dbHelper.markThreadAsRead(threadId);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
  }

  Future<void> deleteThread(String threadId) async {
    await _dbHelper.deleteThread(threadId);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
  }

  Future<void> deleteMessage(AppSmsMessage message) async {
    if(message.id == null) return;
    await _dbHelper.deleteMessage(message.id!);
    AppSmsMessage? previousMessage = await _dbHelper.getMessagesForThread(message.threadId).then((value) => value.firstOrNull);
    if(previousMessage != null){
      await _updateChat(previousMessage.threadId, previousMessage.address, previousMessage.body, previousMessage.date);
    }else{
      await deleteThread(message.threadId);
    }
    
    _messageUpdateController.add(SmsEvent(type: SmsEventType.messageDeleted, message: message));
  }
  Future<void>  deleteMessages(List<AppSmsMessage> messages) async {
    List<int> ids = messages.map((m) => m.id!).toList();
    await _dbHelper.deleteMessages(ids);
    AppSmsMessage? previousMessage = await _dbHelper.getMessagesForThread(messages.first.threadId).then((value) => value.firstOrNull);
    if(previousMessage != null){
      await _updateChat(previousMessage.threadId, previousMessage.address, previousMessage.body, previousMessage.date);
    }else{
      await deleteThread(messages.first.threadId);
    }
    
    _messageUpdateController.add(SmsEvent(type: SmsEventType.messagesDeletedAll, messages: messages));
  }


  Future<String> getContactName(String phoneNumber) async =>
      ContactService().getName(phoneNumber);
}

enum SmsEventType {
  messageSent,
  messageSendFailure,
  messagePending,
  messageDelivered,
  messageReceived,
  messageDeleted,
  messagesDeletedAll,
  threadUpdated,
  syncCompleted
}

class SmsEvent {
  final AppSmsMessage? message;
  final SmsEventType type;
  final List<AppSmsMessage> messages;

  SmsEvent({this.message, required this.type,  this.messages = const []});
}

enum ChatEventType {
  newMessage,
  deletedMessage,
  deletedChat,
  threadUpdated
}

class ChatEvent {
  final AppChat? chat;
  final ChatEventType type;

  ChatEvent({this.chat, required this.type});

}
