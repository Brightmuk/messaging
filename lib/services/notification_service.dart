import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as fo;
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/main.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/services/database_helper.dart';
import 'package:messaging/services/sms_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  int _notificationId = 0;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  String? _pendingPayload;  
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    final NotificationAppLaunchDetails? launchDetails =
        await _notifications.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) {
        Future.delayed(const Duration(seconds: 1), () {
          _onNotificationResponse(response);
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
    const AndroidNotificationChannel lowPriorityChannel = AndroidNotificationChannel(
      'low_priority_sms_channel',
      'SMS Messages[low priority]',
      description: 'Notifications for low priority incoming SMS messages',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(lowPriorityChannel);
  }

void _onNotificationResponse(NotificationResponse response) {
  if (response.actionId != null) {
    _handleNotificationAction(response);
    return;
  }
  
  // If navigator is not ready, save the payload for later
  if (navigatorKey.currentState == null) {
    _pendingPayload = response.payload;
    debugPrint("Navigator not ready, stashing payload");
    return;
  }

  _navigateToChat(response.payload);
}

// Call this from your ChatScreen's initState or after a small delay in main
void processPendingNotification() {
  if (_pendingPayload != null) {
    _navigateToChat(_pendingPayload);
    _pendingPayload = null;
  }
}
void _navigateToChat(String? payload) {
  if (payload == null) return;
  try {
    final Map<String, dynamic> data = json.decode(payload);
    final String? address = data['address'];
    final String? threadId = data['threadId'];

    if (address != null && threadId != null) {
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
    debugPrint("Navigation Error: $e");
  }
}

  void _handleNotificationAction(NotificationResponse response) {
    if (response.actionId == 'mark_as_read') {
      final payload = response.payload;
      if (payload == null) return;
      try {
        final data = json.decode(payload) as Map<String, dynamic>;
        final threadId = data['threadId'] as String?;
        if (threadId != null) {
          SmsService().markThreadAsRead(threadId);
        }
      } catch (e) {
        debugPrint('Failed to parse notification payload: $e');
      }
    }
    // null actionId = user tapped the notification body (open app)
    // handle deep link navigation here if needed
  }

  Future<void> showNotification(
      {required String title,
      required String body,
      String? payload,
      bool lowPriority = false,
      bool actions = false}) async {
    AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(lowPriority? 'low_priority_sms_channel' :'sms_channel', 'SMS Messages',
            priority: lowPriority ? Priority.defaultPriority : Priority.high,
            showWhen: true,
            actions: actions
                ? [
                    const AndroidNotificationAction(
                      'mark_as_read',
                      'Mark as Read',
                      cancelNotification: true,
                      showsUserInterface: true,
                    ),
                    
                  ]
                : []);

    NotificationDetails notificationDetails = NotificationDetails(
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

  static Future<void> showOverlay(
      {required String address, required String text}) async {
    if (await canShowOverlay()) {
      fo.FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        flag: fo.OverlayFlag.defaultFlag,
        visibility: fo.NotificationVisibility.visibilityPublic,
        positionGravity: fo.PositionGravity.auto,
        height: 600,
        width: fo.WindowSize.matchParent,
        startPosition: const fo.OverlayPosition(0, -259),
      ).then((v)async {
        await Future.delayed(const Duration(milliseconds: 100));
        fo.FlutterOverlayWindow.shareData(
            {'address': address, 'redactedText': text});
      });
    }
  }

  static Future<bool> canShowOverlay() async {
    return (await UserDefaults.canShowOverlay() &&
        await fo.FlutterOverlayWindow.isPermissionGranted());
  }

  static Future<void> setShowOverlay(bool showOverlay) async {
    if (showOverlay) {
      bool granted = await fo.FlutterOverlayWindow.isPermissionGranted();
      if (granted) {
        await UserDefaults.setShowOverlay(true);
      } else {
        await fo.FlutterOverlayWindow.requestPermission();
      }
    } else {
      await UserDefaults.setShowOverlay(false);
    }
  }

  void removeNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint("Background notification response actionId: ${response.actionId}");
  final int? notificationId = response.id;
  if (response.actionId == 'mark_as_read') {
    final payload = response.payload;
    if (notificationId != null) {
      FlutterLocalNotificationsPlugin().cancel(notificationId);
    }
    if (payload == null) return;
    try {
      final data = json.decode(payload) as Map<String, dynamic>;
      final threadId = data['threadId'] as String?;
      if (threadId != null) {
        DatabaseHelper.instance.markThreadAsRead(threadId);
      }
    } catch (e) {
      debugPrint('Failed to parse notification payload: $e');
    }
  }
}
