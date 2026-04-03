import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:messaging/models/app_message.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/services/database_helper.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class MchangoService {
  static final MchangoService _instance = MchangoService._internal();
  factory MchangoService() => _instance;
  MchangoService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final notificationService = NotificationService();

  // M-Pesa received money pattern:
  // "BG27XY1Z2A Confirmed. You have received Ksh1,500.00 from JOHN DOE 0712345678..."
  static final RegExp _mpesaReceivedPattern = RegExp(
    r'received\s+Ksh([\d,]+\.?\d*)\s+from\s+([A-Z\s]+?)\s+([\d]+)',
    caseSensitive: false,
  );
  static Future<String?> getThreadIdForMchango() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return null;
    await Permission.notification.request();
    final chats = await DatabaseHelper.instance.getAllChats();
    final chat = chats.where((c) => c.isSameThread(null, "MPESA")).firstOrNull;
    return chat?.threadId;
  }

  /// Returns a contribution if the message matches a received M-Pesa payment
  Contribution? parseContribution(AppSmsMessage message, int campaignId) {
    debugPrint("Parsing: ${message.body}");
    final match = _mpesaReceivedPattern.firstMatch(message.body);
    if (match == null) return null;

    final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
    final amount = double.tryParse(amountStr) ?? 0;
    final senderName = match.group(2)?.trim();
    final senderPhone = match.group(3) ?? '';
    debugPrint(
        "Amount is: $amount senderName: $senderName senderPhone: $senderPhone");

    if (amount <= 0) return null;

    return Contribution(
      campaignId: campaignId,
      senderName: senderName,
      senderPhone: senderPhone,
      amount: amount,
      date: message.date,
      messageId: message.id,
    );
  }

  Future<Campaign?> getActiveCampaign(String threadId) =>
      _db.getActiveCampaign(threadId);

  Future<Campaign> startCampaign({
    required String name,
    required String threadId,
    double? targetAmount,
    int? endDate,
    required double openingBalance,
  }) async {
    // Enforce one active campaign at a time
    final existing = await _db.getActiveCampaign(threadId);
    if (existing != null) throw Exception('A campaign is already active');

    final campaign = Campaign(
      name: name,
      threadId: threadId,
      startDate: DateTime.now().millisecondsSinceEpoch,
      endDate: endDate,
      targetAmount: targetAmount,
      openingBalance: openingBalance,
    );
    final id = await _db.insertCampaign(campaign);
    return campaign.copyWith(id: id);
  }

  Future<void> stopCampaign(int campaignId) => _db.stopCampaign(campaignId);

  Future<List<Campaign>> getCampaigns(String threadId) =>
      _db.getCampaigns(threadId);

  Future<List<Contribution>> getContributions(int campaignId) =>
      _db.getContributions(campaignId);

  /// Call this from SmsService when a new M-Pesa message arrives
  Future<void> processMessage(AppSmsMessage message) async {
    try {
      final campaign = await _db.getActiveCampaign(message.threadId);
      if (campaign == null || campaign.id == null) return;

      // Check expiry
      if (campaign.endDate != null && message.date > campaign.endDate!) {
        await _db.stopCampaign(campaign.id!);
        return;
      }

      // Skip if already processed
      if (message.id != null &&
          await _db.contributionExists(campaign.id!, message.id!)) {
        return;
      }

      final contribution = parseContribution(message, campaign.id!);
      if (contribution == null) return;
      await _db.insertContribution(contribution);
      //show notification
      notificationService.showNotification(
        title: "Mchango - New Contribution",
        body:
            "You received Ksh${contribution.amount.toStringAsFixed(2)} from ${contribution.senderName ?? contribution.senderPhone} for campaign '${campaign.name}'",
        action: NotificationAction.mchango,
        lowPriority: false,
        payload: json.encode(
          {
            'campaignId': campaign.id,
            'threadId': message.threadId,
          },
        ),
      );
    } catch (e) {
      debugPrint('[MchangoService] processMessage error: ${e.runtimeType}');
    }
  }

  Future<void> updateCampaign(
    int campaignId, {
    required String name,
    int? endDate,
    bool clearEndDate = false,
    double? targetAmount,
    bool clearTargetAmount = false,
  }) async {
    try {
      await _db.updateCampaign(
        campaignId,
        name: name,
        endDate: endDate,
        clearEndDate: clearEndDate,
        targetAmount: targetAmount,
        clearTargetAmount: clearTargetAmount,
      );
    } catch (_) {}
  }

  Future<void> deleteCampaign(int campaignId) async {
    try {
      await _db.deleteCampaign(campaignId);
    } catch (_) {}
  }

  Future<void> deleteContribution(int contributionId) async {
    try {
      await _db.deleteContribution(contributionId);
    } catch (_) {}
  }

  Future<void> simulateContribution(String threadId) async {
    try {
      final random = Random();

      final names = [
        'JOHN DOE',
        'MARY WANJIKU',
        'PETER KAMAU',
        'GRACE AKINYI',
        'JAMES MWANGI',
        'FAITH NJERI',
        'SAMUEL ODHIAMBO',
        'RUTH WAMBUI',
        'DAVID KIPCHOGE',
        'ESTHER MUTHONI',
        'KEVIN OTIENO',
        'LUCY WANGARI',
        'BRIAN MUTUA',
        'CAROLINE ADHIAMBO',
        'MICHAEL NJOROGE',
      ];

      final amounts = [100, 200, 300, 500, 1000, 1500, 2000, 2500, 5000];

      final name = names[random.nextInt(names.length)];
      final amount = amounts[random.nextInt(amounts.length)];
      // Generate a realistic Kenyan phone number
      final phone =
          '07${random.nextInt(9)}${List.generate(7, (_) => random.nextInt(10)).join()}';
      // Generate a realistic M-Pesa transaction code
      final code = List.generate(10, (_) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        return chars[random.nextInt(chars.length)];
      }).join();

      final body =
          '$code Confirmed. You have received Ksh${_formatAmount(amount)} '
          'from $name $phone on ${_formatMpesaDate(DateTime.now())}. '
          'New M-PESA balance is Ksh${random.nextInt(50000)}.00. '
          'Transaction cost, Ksh0.00.';
      DateTime date = DateTime.now().add(Duration(minutes: 3));
      final message = AppSmsMessage(
        address: 'MPESA',
        body: body,
        date: date.millisecondsSinceEpoch,
        type: 1,
        threadId: threadId,
        status: MessageStatus.unknown,
        read: true,
        simId: -1,
      );

      await processMessage(message);
    } catch (e) {
      debugPrint(
          '[MchangoService] simulateContribution error: ${e.runtimeType}');
    }
  }

  String _formatAmount(int amount) {
    // M-Pesa format: 1,500.00
    final formatted = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$formatted.00';
  }

  String _formatMpesaDate(DateTime date) {
    // M-Pesa format: 1/1/25, 3:45 PM
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);
    return '${date.day}/${date.month}/$year, $hour:$minute $period';
  }
}
