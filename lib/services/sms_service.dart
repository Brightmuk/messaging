import 'package:flutter/services.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sms_message.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'dart:async';

class SmsService {
  SmsService._internal();
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;

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


Future<void> syncExistingMessages() async {
  // 1. Fetch messages from the system provider
  // You can filter by inbox, or get all. 
  List<SmsMessage> messages = await telephony.getInboxSms(
    columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.THREAD_ID, SmsColumn.READ],
    sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)]
  );
  
  for (int i = 0; i < messages.length; i++) {
    final msg = messages[i];
    
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

    //Update only with the last message
    // if( i == messages.length - 1){
      await _updateChat(
      appMsg.threadId, 
      appMsg.address, 
      appMsg.body, 
      appMsg.date,
      incrementUnread: false
    );
    // }
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
      int date = DateTime.now().millisecondsSinceEpoch;

      // Save to database
      final smsMessage = AppSmsMessage(
        address: address,
        body: message,
        date: date,
        type: 2, // Sent message
        threadId: threadId,
        read: true,
      );

      await _dbHelper.insertMessage(smsMessage);
      
      // Update chat
      await _updateChat(threadId, address, message, date);
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
    await _updateChat(
      smsMessage.threadId,
      smsMessage.address,
      smsMessage.body,
      smsMessage.date,
      incrementUnread: true,
    );

    // Show notification
    await _notificationService.showNotification(
      title: smsMessage.address,
      body: smsMessage.body,
      payload: smsMessage.threadId,
    );
  }

  // Update chat
  Future<void> _updateChat(
    String threadId,
    String address,
    String lastMessage, 
    int lastMessageDate,
    {
    bool incrementUnread = false,
  }) async {
    final chats = await _dbHelper.getAllChats();
    final existingChat = chats.firstWhere(
      (c) => c.threadId == threadId,
      orElse: () => AppChat(
        threadId: threadId,
        address: address,
        lastMessage: lastMessage,
        lastMessageDate: lastMessageDate,
        unreadCount: 0,
      ),
    );

    final updatedChat = AppChat(
      threadId: threadId,
      address: address,
      lastMessage: lastMessage,
      lastMessageDate: lastMessageDate,
      unreadCount: incrementUnread
          ? existingChat.unreadCount + 1
          : existingChat.unreadCount,
    );

    await _dbHelper.updateChat(updatedChat);
  }

  // Get messages for a thread
  Future<List<AppSmsMessage>> getMessagesForThread(String threadId) async {
    return await _dbHelper.getMessagesForThread(threadId);
  }

  // Get all chats
  Future<List<AppChat>> getAllChats() async {
    return await _dbHelper.getAllChats();
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
