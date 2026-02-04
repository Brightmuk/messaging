import 'package:flutter/services.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sms_message.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'dart:async';

class SmsService {
  final Telephony telephony = Telephony.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _messageUpdateController = StreamController<void>.broadcast();
  Stream<void> get onMessageUpdated => _messageUpdateController.stream;
  final NotificationService _notificationService = NotificationService();
  static const _channel = MethodChannel('com.example.messaging.sms_role');

  static Future<bool> isDefaultSmsApp() async {
    try {
      final bool isDefault = await _channel.invokeMethod('isDefaultSmsApp');
      return isDefault;
    } on PlatformException catch (e) {
      print("Failed to check SMS role: ${e.message}");
      return false;
    }
  }


  /// Triggers the Android system dialog to ask the user to make this app default.
  static Future<void> requestDefaultSmsRole() async {
    try {
      await _channel.invokeMethod('requestDefaultSmsRole');
    } on PlatformException catch (e) {
      print("Failed to request SMS role: ${e.message}");
    }
  }

  // Initialize SMS service
  Future<void> initialize() async {
    await _notificationService.initialize();
    
    // Listen for incoming SMS
    telephony.listenIncomingSms(
      onNewMessage: _onMessageReceived,
      onBackgroundMessage: _onBackgroundMessage,
    );
  }

  // Request necessary permissions
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.phone,
      Permission.contacts,
      Permission.notification,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

Future<void> syncExistingMessages() async {
  // 1. Fetch messages from the system provider
  // You can filter by inbox, or get all. 
  List<SmsMessage> messages = await telephony.getInboxSms(
    columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.THREAD_ID, SmsColumn.READ],
    sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)]
  );

  for (var msg in messages) {
    // 2. Convert to your AppSmsMessage model
    final appMsg = AppSmsMessage(
      address: msg.address ?? 'Unknown',
      body: msg.body ?? '',
      date: msg.date ?? DateTime.now().millisecondsSinceEpoch,
      type: 1, // Inbox
      threadId: msg.threadId.toString(),
      read: msg.read ?? true,
    );

    // 3. Insert into local DB (using insert ignore/replace)
    await _dbHelper.insertMessage(appMsg);
    
    // 4. Update the conversation summary table
    // We do this without incrementing unread since they are old messages
    await _updateConversation(
      appMsg.threadId, 
      appMsg.address, 
      appMsg.body, 
      incrementUnread: false
    );
  }
}


  // Request to become default SMS app
  Future<void> requestDefaultSmsApp() async {
    await telephony.requestPhoneAndSmsPermissions;
    await telephony.requestSmsPermissions;
  }

  // Send SMS
  Future<bool> sendSms(String address, String message, String threadId) async {
    try {
      await telephony.sendSms(
        to: address,
        message: message,
      );

      // Save to database
      final smsMessage = AppSmsMessage(
        address: address,
        body: message,
        date: DateTime.now().millisecondsSinceEpoch,
        type: 2, // Sent message
        threadId: threadId,
        read: true,
      );

      await _dbHelper.insertMessage(smsMessage);
      
      // Update conversation
      await _updateConversation(threadId,address, message);
      _messageUpdateController.add(null);
      return true;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  // Handle incoming message
  void _onMessageReceived(SmsMessage message) async {
    _messageUpdateController.add(null);
    await _saveIncomingMessage(message);
  }

  // Handle background message
  static Future<void> _onBackgroundMessage(SmsMessage message) async {
    final smsService = SmsService();
    await smsService._saveIncomingMessage(message);
  }

  // Save incoming message
  Future<void> _saveIncomingMessage(SmsMessage telephonyMessage) async {
    final smsMessage = AppSmsMessage(
      address: telephonyMessage.address ?? '',
      body: telephonyMessage.body ?? '',
      date: telephonyMessage.date ?? DateTime.now().millisecondsSinceEpoch,
      type: 1, // Received message
      threadId: telephonyMessage.threadId.toString(),
      read: false,
    );

    await _dbHelper.insertMessage(smsMessage);
    await _updateConversation(
      smsMessage.threadId,
      smsMessage.address,
      smsMessage.body,
      incrementUnread: true,
    );

    // Show notification
    await _notificationService.showNotification(
      title: smsMessage.address,
      body: smsMessage.body,
      payload: smsMessage.threadId,
    );
  }

  // Update conversation
  Future<void> _updateConversation(
    String threadId,
    String address,
    String lastMessage, {
    bool incrementUnread = false,
  }) async {
    final conversations = await _dbHelper.getAllConversations();
    final existingConversation = conversations.firstWhere(
      (c) => c.threadId == threadId,
      orElse: () => AppConversation(
        threadId: threadId,
        address: address,
        unreadCount: 0,
      ),
    );

    final updatedConversation = AppConversation(
      threadId: threadId,
      address: address,
      lastMessage: lastMessage,
      lastMessageDate: DateTime.now().millisecondsSinceEpoch,
      unreadCount: incrementUnread
          ? existingConversation.unreadCount + 1
          : existingConversation.unreadCount,
    );

    await _dbHelper.updateConversation(updatedConversation);
  }

  // Get messages for a thread
  Future<List<AppSmsMessage>> getMessagesForThread(String threadId) async {
    return await _dbHelper.getMessagesForThread(threadId);
  }

  // Get all conversations
  Future<List<AppConversation>> getAllConversations() async {
    return await _dbHelper.getAllConversations();
  }

  // Mark thread as read
  Future<void> markThreadAsRead(String threadId) async {
    await _dbHelper.markThreadAsRead(threadId);
  }

  // Delete message
  Future<void> deleteMessage(int messageId) async {
    await _dbHelper.deleteMessage(messageId);
  }

  // Delete thread
  Future<void> deleteThread(String threadId) async {
    await _dbHelper.deleteThread(threadId);
  }

  // Get contact name
  Future<String> getContactName(String phoneNumber) async {
    // This would integrate with contacts_service
    // For now, return the phone number
    return phoneNumber;
  }
}
