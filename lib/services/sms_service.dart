import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_telephony/telephony.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/services/contact_db.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/redact_service.dart';
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
  SmsService._internal() {
    initialize();
  }
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;

  final Telephony telephony = Telephony.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final NotificationService _notificationService = NotificationService();

  static const _channel = MethodChannel('com.brimukon.messaging.defaultRole');

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

  Future<void> requestSmsRole() async {
    try {
      await _channel.invokeMethod('requestSmsPermissions');
    } catch (_) {
      debugPrint('[SmsService] error requesting default SMS role');
    }
  }



  Future<void> initialize() async {
    try {
      telephony.listenIncomingSms(
        onNewMessage: _onMessageReceived,
        onBackgroundMessage: _onBackgroundMessage,
      );
    } catch (_) {
      debugPrint('[SmsService] error initializing');
    }
  }

  Future<List<SimInfo>> getSimcards() async {
    try {
      final plugin = SimCardInfo();
      return await plugin.getSimInfo() ?? [];
    } catch (_) {
      debugPrint('[SmsService] error getting simcards');
      return [];
    }
  }

  Future<void> setDefaultSim(int id) async {
    try {
      await UserDefaults.setDefaultSim(id);
    } catch (_) {
      debugPrint('[SmsService] error setting default sim');
    }
  }

  Future<int> getDefaultSim() async {
    try {
      return await UserDefaults.getDefaultSim();
    } catch (_) {
      debugPrint('[SmsService] error getting default sim');
      return -1;
    }
  }

  Future<AppSimCardState> getSimState() async {
    try {
      final id = await getDefaultSim();
      final simcards = await getSimcards();
      return AppSimCardState(
        defaultCard: id == -1 ? null : id,
        allCards: simcards,
      );
    } catch (_) {
      debugPrint('[SmsService] error getting sim state');
      return AppSimCardState(defaultCard: null, allCards: []);
    }
  }


  Future<void> syncExistingMessages() async {
    try {
      debugPrint("Syncing history from system provider...");

      final List<SmsMessage> inboxMessages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE,
          SmsColumn.THREAD_ID, SmsColumn.READ, SmsColumn.TYPE, SmsColumn.ID,
        ],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
      );

      final List<SmsMessage> sentMessages = await telephony.getSentSms(
        columns: [
          SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE,
          SmsColumn.THREAD_ID, SmsColumn.READ, SmsColumn.TYPE, SmsColumn.ID,
        ],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
      );

      final allMessages = [...inboxMessages, ...sentMessages];
      if (allMessages.isEmpty) return;

      allMessages.sort((a, b) => (a.date ?? 0).compareTo(b.date ?? 0));
      await _dbHelper.batchSyncMessages(allMessages);
      UserDefaults.setHasSynced();
      _messageUpdateController.add(SmsEvent(type: SmsEventType.syncCompleted));
    } catch (_) {
      debugPrint('[SmsService] error syncing existing messages');
    }
  }

  Future<void> startSendTimeout(AppSmsMessage smsMessage) async {
    try {
      if (smsMessage.id == null) return;
      final messageId = smsMessage.id!;
      _activeTimeouts[messageId] = Timer(const Duration(seconds: 15), () async {
        await markMessageAsFailed(smsMessage.copyWith(id: messageId));
        _activeTimeouts.remove(messageId);
      });
    } catch (_) {
      debugPrint('[SmsService] error starting send timeout');
    }
  }

  Future<void> cancelSendTimeout(int messageId) async {
    try {
      _activeTimeouts[messageId]?.cancel();
      _activeTimeouts.remove(messageId);
    } catch (_) {
      debugPrint('[SmsService] error canceling send timeout');
    }
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
    int? messageId;
    try {
      messageId = await _dbHelper.insertMessage(smsMessage);
      await _updateChat(threadId, address, message, date);
    await startSendTimeout(smsMessage.copyWith(id: messageId));
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
            await cancelSendTimeout(messageId!);
            await markMessageAsDelivered(smsMessage.copyWith(id: messageId));
          }
        },
      );

      _messageUpdateController.add(SmsEvent(
          type: SmsEventType.messagePending,
          message: smsMessage.copyWith(id: messageId)));
      return true;
    } catch (e) {
      await cancelSendTimeout(messageId!);
      await markMessageAsFailed(smsMessage.copyWith(id: messageId));
      debugPrint("[SmsService] error sending sms: $e");
      
      return false;
    }
  }

  Future<void> retrySending(AppSmsMessage message) async {
    try {
      final defaultSim = await getDefaultSim();
      if (message.id == null) return;

      await startSendTimeout(message);

      await telephony.sendSms(
        to: message.address,
        message: message.body,
        subscriptionId: defaultSim + 1,
        statusListener: (status) async {
          try {
            if (status == SendStatus.DELIVERED) {
              await markMessageAsDelivered(message);
            }
          } catch (_) {
            debugPrint('[SmsService] error marking message as delivered');
          
          }
        },
      );

      _messageUpdateController.add(SmsEvent(
        type: SmsEventType.messagePending,
        message: message.copyWith(status: MessageStatus.pending),
      ));
    } catch (_) {
      try {
        await cancelSendTimeout(message.id!);
        await markMessageAsFailed(message);
      } catch (_) {
        debugPrint('[SmsService] error retrying sending message');
      }
    }
  }

  Future<List<AppChat>> getArchivedChats() async {
    try {
      return await _dbHelper.getArchivedChats();
    } catch (_) {
      debugPrint("[SmsService] error getting archived chats");
      return [];
    }
  }

  Future<int> getArchivedCount() async {
    try {
      return await _dbHelper.getArchivedCount();
    } catch (_) {
      debugPrint("[SmsService] error getting archived count");
      return 0;
    }
  }

  Future<List<AppSmsMessage>> searchGlobal(String query) async {
    try {
      final isDefault = await SmsService.isDefaultSmsApp();
      return await _dbHelper.searchGlobal(query, isDefault);
    } catch (_) {
      debugPrint("[SmsService] error searching global");
      return [];
    }
  }



  Future<void> _saveIncomingMessage(SmsMessage msg, String threadId) async {
    try {
      final appMsg = AppSmsMessage(
        status: MessageStatus.unknown,
        address: msg.address ?? '',
        body: msg.body ?? '',
        date: msg.date ?? DateTime.now().millisecondsSinceEpoch,
        type: 1,
        threadId: threadId,
        read: false,
        simId: msg.subscriptionId ?? -1,
      );

      await _dbHelper.insertMessage(appMsg);
      await _updateChat(threadId, appMsg.address, appMsg.body, appMsg.date,
          incrementUnread: true);
      _messageUpdateController
          .add(SmsEvent(type: SmsEventType.messageReceived, message: appMsg));
    } catch (_) {
      debugPrint("[SmsService] error saving incoming message");
    }
  }

  Future<String> getThreadId(String? address) async {
    try {
      if (address == null) return const Uuid().v4();
      final chats = await _dbHelper.getAllChats();
      final chat =
          chats.where((c) => c.isSameThread(null, address)).firstOrNull;
      return chat?.threadId ?? const Uuid().v4();
    } catch (_) {

      return const Uuid().v4();
    }
  }

  static Future<String> _getThreadIdSt(String? address) async {
    try {
      if (address == null) return const Uuid().v4();
      final chats = await DatabaseHelper.instance.getAllChats();
      final chat =
          chats.where((c) => c.isSameThread(null, address)).firstOrNull;
      return chat?.threadId ?? const Uuid().v4();
    } catch (_) {
      return const Uuid().v4();
    }
  }

  Future<void> _updateChat(
    String tId,
    String addr,
    String msg,
    int date, {
    bool incrementUnread = false,
  }) async {
    try {
      await _dbHelper.upsertChat(
        AppChat(
          threadId: tId,
          address: addr,
          lastMessage: msg,
          lastMessageDate: date,
          unreadCount: 0,
        ),
        incrementUnread: incrementUnread,
      );
    } catch (_) {
      debugPrint("[SmsService] error updating chat");

    }
  }

   Future<List<AppChat>> getPaginatedChats({
    required int limit,
    required int offset,
    bool isDefaultApp = true,
  }) async {
    try {
      return await _dbHelper.getPaginatedChats(
        limit: limit,
        offset: offset,
        isDefaultApp: isDefaultApp,
      );
    } catch (_) {
      debugPrint("[SmsService] error getting paginated chats");
      return [];
    }
  }

  Future<List<AppSmsMessage>> getMessagesAfterTimestamp(
    String threadId, {
    required int afterDate,
    int limit = 20,
  }) async {
    try {
      return await _dbHelper.getMessagesAfterTimestamp(
        threadId,
        afterDate: afterDate,
        limit: limit,
      );
    } catch (_) {
      debugPrint("[SmsService] error getting messages after timestamp");
      return [];
    }
  }

  Future<List<AppSmsMessage>> getMessagesForThread(
    String threadId, {
    int limit = 20,
    int offset = 0,
    int? targetTimestamp,
  }) async {
    try {
      return await _dbHelper.getMessagesForThread(
        threadId,
        limit: limit,
        offset: offset,
        targetTimestamp: targetTimestamp,
      );
    } catch (_) {
      debugPrint("[SmsService] error getting messages for thread");
      return [];
    }
  }


  Future<void> markMessageAsSent(AppSmsMessage message) async {
    try {
      if (message.id == null) return;
      await _dbHelper.markMessageAsSent(message.id!);
      _messageUpdateController.add(SmsEvent(
        type: SmsEventType.messageSent,
        message: message.copyWith(status: MessageStatus.sent),
      ));
    } catch (_) {
      debugPrint("[SmsService] error marking message as sent");
    }
  }

  Future<void> markMessageAsDelivered(AppSmsMessage message) async {
    try {
      if (message.id == null) return;
      await _dbHelper.markMessageAsDelivered(message.id!);
      _messageUpdateController.add(SmsEvent(
        type: SmsEventType.messageDelivered,
        message: message.copyWith(status: MessageStatus.delivered),
      ));
    } catch (_) {
      debugPrint("[SmsService] error marking message as delivered");
    }
  }

  Future<void> markMessageAsFailed(AppSmsMessage message) async {
    try {
      if (message.id == null) return;
      await _dbHelper.markMessageAsFailed(message.id!);
      _messageUpdateController.add(SmsEvent(
        type: SmsEventType.messageSendFailure,
        message: message.copyWith(status: MessageStatus.failed),
      ));
    } catch (_) {
      debugPrint("[SmsService] error marking message as failed");
    }
  }

  Future<void> markThreadsAsPinned(
      Iterable<String> threadIds, bool isPinned) async {
    try {
      for (final threadId in threadIds) {
        await _dbHelper.markThreadAsPinned(threadId, isPinned);
      }
      _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
    } catch (_) {
      debugPrint("[SmsService] error marking threads as pinned");
    }
  }

  Future<void> markThreadsAsArchived(
      Iterable<String> threadIds, bool isArchived) async {
    try {
      for (final threadId in threadIds) {
        await _dbHelper.markThreadAsArchived(threadId, isArchived);
      }
      _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
    } catch (_) {
      debugPrint("[SmsService] error marking threads as archived");

    }
  }

  void _onMessageReceived(SmsMessage message) async {
    try {
      final threadId = await getThreadId(message.address);
      final contactName = ContactService().getName(message.address ?? '');
      await _saveIncomingMessage(message, threadId);
      if (message.body == null || message.address == null) return;

      await _notificationService.showNotification(
        title: contactName,
        body: RedactService.redactAfterBalance(
                message.body!, message.address!)
            .message,
        actions: true,
        payload:
            json.encode({'threadId': threadId, 'address': message.address}),
      );
    } catch (_) {
      debugPrint("[SmsService] error on message received");
    }
  }
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(SmsMessage message) async {
    try {
      if (message.body == null || message.address == null) return;

      final smsService = SmsService();
      final notificationService = NotificationService();
      await notificationService.initialize();

      final threadId = await _getThreadIdSt(message.address);
      final db = ContactDb();
      final contactName = await db.getName(message.address ?? '');
      final title = contactName ?? message.address ?? 'New Message';

      await smsService._saveIncomingMessage(message, threadId);

      final payload =
          json.encode({'threadId': threadId, 'address': message.address});
      final redactResult =
          RedactService.redactAfterBalance(message.body!, message.address!);
      final showOverlay = const {RedactType.paid, RedactType.sent}
          .contains(redactResult.redactType);

      if (showOverlay) {
        NotificationService.showOverlay(
            text: message.body!, address: message.address!);
      }

      notificationService.showNotification(
        title: title,
        body: redactResult.message,
        actions: true,
        lowPriority: RedactService.isMonitored(message.address!),
        payload: payload,
      );
    } catch (_) {
      debugPrint("[SmsService] error on background message");
    }
  }

  Future<void> markThreadAsRead(String threadId) async {
    try {
      await _dbHelper.markThreadAsRead(threadId);
      _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
    } catch (_) {
      debugPrint("[SmsService] error marking thread as read");
    }
  }

  Future<void> deleteThreads(Iterable<String> threadIds) async {
    try {
      for (final threadId in threadIds) {
        await _dbHelper.deleteThread(threadId);
      }
      _messageUpdateController.add(SmsEvent(type: SmsEventType.threadUpdated));
    } catch (_) {
      debugPrint("[SmsService] error deleting threads");
    }
  }

   Future<void> deleteMessages(List<AppSmsMessage> messages) async {
    try {
      final ids = messages.map((m) => m.id!).toList();
      await _dbHelper.deleteMessages(ids);

      final previousMessage = await _dbHelper
          .getMessagesForThread(messages.first.threadId)
          .then((v) => v.firstOrNull);

      if (previousMessage != null) {
        await _updateChat(
          previousMessage.threadId,
          previousMessage.address,
          previousMessage.body,
          previousMessage.date,
        );
      } else {
        await deleteThreads([messages.first.threadId]);
      }

      _messageUpdateController.add(SmsEvent(
        type: SmsEventType.messagesDeletedAll,
        messages: messages,
      ));
    } catch (_) {
      debugPrint("[SmsService] error deleting messages");
    }
  }
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

  SmsEvent({this.message, required this.type, this.messages = const []});
}

enum ChatEventType { newMessage, deletedMessage, deletedChat, threadUpdated }

class ChatEvent {
  final AppChat? chat;
  final ChatEventType type;

  ChatEvent({this.chat, required this.type});
}
