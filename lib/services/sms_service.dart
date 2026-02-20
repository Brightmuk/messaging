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

  Future<void> startSendTimeout(int messageId) async {
    _activeTimeouts[messageId] = Timer(const Duration(seconds: 15), () async {
      await markMessageAsFailed(messageId);
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
    );
    int messageId = await _dbHelper.insertMessage(smsMessage);
    await _updateChat(threadId, address, message, date);
    await startSendTimeout(messageId);

    try {
      await telephony.sendSms(
        to: address,
        message: message,
        subscriptionId: defaultSim + 1,
        statusListener: (status) async {
          if (status == SendStatus.SENT) {
            await cancelSendTimeout(messageId);
            await markMessageAsSent(messageId);
          }

          if (status == SendStatus.DELIVERED) {
            await markMessageAsDelivered(messageId);
          }
        },
      );

      _messageUpdateController.add(
          SmsEvent(type: SmsEventType.messagePending, message: smsMessage));
      return true;
    } catch (e) {
      await cancelSendTimeout(messageId);
      await markMessageAsFailed(messageId);
      debugPrint('Send error: $e');
      return false;
    }
  }

  Future<void> markMessageAsSent(int messageId) async {
    await _dbHelper.markMessageAsSent(messageId);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.messageSent));
  }

  Future<void> markMessageAsDelivered(int messageId) async {
    await _dbHelper.markMessageAsDelivered(messageId);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.messageDelivered));
  }

  Future<void> markMessageAsFailed(int messageId) async {
    await _dbHelper.markMessageAsFailed(messageId);
    _messageUpdateController
        .add(SmsEvent(type: SmsEventType.messageSendFailure));
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

  Future<List<AppChat>> getAllChats() => _dbHelper.getAllChats();

  Future<List<AppSmsMessage>> getMessagesForThread(String threadId) =>
      _dbHelper.getMessagesForThread(threadId);

  Future<void> markThreadAsRead(String threadId) async {
    await _dbHelper.markThreadAsRead(threadId);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
  }

  Future<void> deleteThread(String threadId) async {
    await _dbHelper.deleteThread(threadId);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
  }

  Future<void> deleteMessage(int messageId) async {
    await _dbHelper.deleteMessage(messageId);
    _messageUpdateController.add(SmsEvent(type: SmsEventType.messageDeleted));
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
  threadUpdated,
  syncCompleted
}

class SmsEvent {
  final AppSmsMessage? message;
  final SmsEventType type;
  SmsEvent({this.message, required this.type});
}
