import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:messaging/main.dart';
import 'package:messaging/screens/single_chat_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  int _notificationId = 0;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    final NotificationAppLaunchDetails? launchDetails = 
        await _notifications.getNotificationAppLaunchDetails();
    
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) {
        // Delay slightly to ensure the Navigator is ready
        Future.delayed(const Duration(seconds: 1), () {
          _onNotificationTapped(response);
        });
      }
    }

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sms_channel',
      'SMS Messages',
      description: 'Notifications for incoming SMS messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'sms_channel',
      'SMS Messages',
      channelDescription: 'Notifications for incoming SMS messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      ++_notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  void removeNotifications() async {
    await _notifications.cancelAll();
  }

void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final Map<String, dynamic> data = json.decode(response.payload!);
      final String? address = data['address'];
      final String? threadId = data['threadId'];

      if(address != null && threadId != null){
        navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => SingleChatScreen(
            address: address,
            threadId: threadId,
          ),
        ),
      );
      }

    } catch (e) {
      print("Error parsing notification payload: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

