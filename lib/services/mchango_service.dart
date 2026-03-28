
import 'package:messaging/models/app_message.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/services/database_helper.dart';

class MchangoService {
  static final MchangoService _instance = MchangoService._internal();
  factory MchangoService() => _instance;
  MchangoService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // M-Pesa received money pattern:
  // "BG27XY1Z2A Confirmed. You have received Ksh1,500.00 from JOHN DOE 0712345678..."
  static final RegExp _mpesaReceivedPattern = RegExp(
    r'received\s+Ksh([\d,]+\.?\d*)\s+from\s+([A-Z\s]+?)\s+([\d]+)',
    caseSensitive: false,
  );

  /// Returns a contribution if the message matches a received M-Pesa payment
  Contribution? parseContribution(
      AppSmsMessage message, int campaignId, double? minAmount) {
    final match = _mpesaReceivedPattern.firstMatch(message.body);
    if (match == null) return null;

    final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
    final amount = double.tryParse(amountStr) ?? 0;
    final senderName = match.group(2)?.trim();
    final senderPhone = match.group(3) ?? '';

    if (amount <= 0) return null;
    if (minAmount != null && amount < minAmount) return null;

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

  Future<void> stopCampaign(int campaignId) =>
      _db.stopCampaign(campaignId);

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
      if (campaign.endDate != null &&
          message.date > campaign.endDate!) {
        await _db.stopCampaign(campaign.id!);
        return;
      }

      // Skip if already processed
      if (message.id != null &&
          await _db.contributionExists(campaign.id!, message.id!)) return;

      final contribution = parseContribution(
          message, campaign.id!, campaign.targetAmount);
      if (contribution == null) return;

      await _db.insertContribution(contribution);
    } catch (_) {}
  }
}