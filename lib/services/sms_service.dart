import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_telephony/telephony.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sim_card_info/sim_card_info.dart';
import 'package:sim_card_info/sim_info.dart';
import 'package:uuid/uuid.dart';
import '../models/sms_message.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'dart:async';

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

  // Streams for UI updates
  final _messageUpdateController = StreamController<SmsEvent>.broadcast();
  Stream<SmsEvent> get onMessageUpdated => _messageUpdateController.stream;

  // --- 1. Role & Permissions Management ---

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

  // --- 2. Lifecycle & Initialization ---

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

    return AppSimCardState(defaultCard: id == -1 ? null : id, allCards: simcards);
  }

  // --- 3. Message Synchronization (Optimized) ---

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

    // Use a batch transaction in the DatabaseHelper to avoid UI jank
    // This is 100x faster than inserting one by one
    await _dbHelper.batchSyncMessages(messages);

    UserDefaults.setHasSynced(); // Mark as synced
    _messageUpdateController.add(SmsEvent(isSync: true));
  }

  // --- 4. Sending & Receiving ---

  Future<bool> sendSms(String address, String message, String threadId) async {
    int? defaultSim = await getDefaultSim();
    print("Sedining with card: $defaultSim");
    try {
      await telephony.sendSms(
        to: address,
        message: message,
        subscriptionId: defaultSim,
        statusListener: (status) {
          if (status == SendStatus.SENT)
            _messageUpdateController.add(SmsEvent(threadId: threadId));
        },
      );

      final date = DateTime.now().millisecondsSinceEpoch;
      final smsMessage = AppSmsMessage(
        address: address,
        body: message,
        date: date,
        type: 2, // Sent
        threadId: threadId,
        read: true,
      );

      await _dbHelper.insertMessage(smsMessage);
      await _updateChat(threadId, address, message, date);

      _messageUpdateController.add(SmsEvent(threadId: threadId));
      return true;
    } catch (e) {
      debugPrint('Send error: $e');
      return false;
    }
  }

  void _onMessageReceived(SmsMessage message) async {
    final threadId = await getThreadId(message.address);
    await _saveIncomingMessage(message, threadId);
    _messageUpdateController
        .add(SmsEvent(threadId: message.threadId.toString()));
  }

  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(SmsMessage message) async {
    final service = SmsService();
    final threadId = await _getThreadIdSt(message.address);
    await service._saveIncomingMessage(message, threadId);
  }

  Future<void> _saveIncomingMessage(SmsMessage msg, String threadId) async {
    final appMsg = AppSmsMessage(
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

    await _notificationService.showNotification(
      title: appMsg.address,
      body: appMsg.body,
      payload: threadId,
    );
  }

  Future<String> getThreadId(String? address) async {
    if (address == null) return const Uuid().v4();
    final chats = await _dbHelper.getAllChats();
    AppChat? chat = chats.where((chat) => chat.address == address).firstOrNull;
    return chat?.threadId ?? const Uuid().v4();
  }

  static Future<String> _getThreadIdSt(String? address) async {
    if (address == null) return const Uuid().v4();
    final chats = await DatabaseHelper.instance.getAllChats();
    AppChat? chat =
        chats.where((chat) => chat.isSameThread(null, address)).firstOrNull;
    return chat?.threadId ?? const Uuid().v4();
  }

  // --- 5. Database Operations ---

  Future<void> _updateChat(String tId, String addr, String msg, int date,
      {bool incrementUnread = false}) async {
    await _dbHelper.upsertChat(
        AppChat(
          threadId: tId,
          address: addr,
          lastMessage: msg,
          lastMessageDate: date,
          unreadCount:
              0, // DatabaseHelper will handle the actual count increment
        ),
        incrementUnread: incrementUnread);
  }

  Future<List<AppChat>> getAllChats() => _dbHelper.getAllChats();

  Future<List<AppSmsMessage>> getMessagesForThread(String threadId) =>
      _dbHelper.getMessagesForThread(threadId);

  Future<void> markThreadAsRead(String threadId) async {
    await _dbHelper.markThreadAsRead(threadId);
    _messageUpdateController.add(SmsEvent(threadId: threadId));
  }

  Future<void> deleteThread(String threadId) async {
    await _dbHelper.deleteThread(threadId);
    _messageUpdateController.add(SmsEvent());
  }

  Future<void> deleteMessage(int messageId) async {
    await _dbHelper.deleteMessage(messageId);
    _messageUpdateController.add(SmsEvent());
  }

  Future<String> getContactName(String phoneNumber) async => phoneNumber;
}

// Helper class for Stream events
class SmsEvent {
  final String? threadId;
  final bool isSync;
  SmsEvent({this.threadId, this.isSync = false});
}
