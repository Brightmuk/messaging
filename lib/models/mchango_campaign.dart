// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Campaign {
  final int? id;
  final String name;
  final String threadId;
  final int startDate;
  final int? endDate;
  final double? targetAmount;
  final bool isActive;
  final double openingBalance;

  Campaign({
    this.id,
    required this.name,
    required this.threadId,
    required this.startDate,
    this.endDate,
    this.targetAmount,
    this.isActive = true,
    this.openingBalance = 0,
  });

  double get progress => targetAmount != null && targetAmount! > 0
      ? (totalCollected / targetAmount!).clamp(0.0, 1.0)
      : 0;

  // Computed — set from outside
  double totalCollected = 0;
  int contributorCount = 0;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'threadId': threadId,
      'startDate': startDate,
      'endDate': endDate,
      'targetAmount': targetAmount,
      'isActive': isActive? 1 : 0,
      'openingBalance': openingBalance,
    };
  }

  factory Campaign.fromMap(Map<String, dynamic> map) {
    return Campaign(
      id: map['id'] != null ? map['id'] as int : null,
      name: map['name'] as String,
      threadId: map['threadId'] as String,
      startDate: map['startDate'] as int,
      endDate: map['endDate'] != null ? map['endDate'] as int : null,
      targetAmount: map['targetAmount'] != null ? map['targetAmount'] as double : null,
      isActive: (map['isActive'] as int?) == 1,
      openingBalance: map['openingBalance'] as double,
    );
  }



  Campaign copyWith({
    int? id,
    String? name,
    String? threadId,
    int? startDate,
    int? endDate,
    double? targetAmount,
    bool? isActive,
    double? openingBalance,
  }) {
    return Campaign(
      id: id ?? this.id,
      name: name ?? this.name,
      threadId: threadId ?? this.threadId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetAmount: targetAmount ?? this.targetAmount,
      isActive: isActive ?? this.isActive,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }

  String toJson() => json.encode(toMap());

  factory Campaign.fromJson(String source) => Campaign.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Campaign(id: $id, name: $name, threadId: $threadId, startDate: $startDate, endDate: $endDate, targetAmount: $targetAmount, isActive: $isActive, openingBalance: $openingBalance)';
  }

  @override
  bool operator ==(covariant Campaign other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.name == name &&
      other.threadId == threadId &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.targetAmount == targetAmount &&
      other.isActive == isActive &&
      other.openingBalance == openingBalance;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      threadId.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      targetAmount.hashCode ^
      isActive.hashCode ^
      openingBalance.hashCode;
  }
}

class Contribution {
  final int? id;
  final int campaignId;
  final String? senderName;
  final String senderPhone;
  final double amount;
  final int date;
  final int? messageId;

  Contribution({
    this.id,
    required this.campaignId,
    this.senderName,
    required this.senderPhone,
    required this.amount,
    required this.date,
    this.messageId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'campaignId': campaignId,
    'senderName': senderName,
    'senderPhone': senderPhone,
    'amount': amount,
    'date': date,
    'messageId': messageId,
  };

  factory Contribution.fromMap(Map<String, dynamic> map) => Contribution(
    id: map['id'],
    campaignId: map['campaignId'],
    senderName: map['senderName'],
    senderPhone: map['senderPhone'],
    amount: map['amount'],
    date: map['date'],
    messageId: map['messageId'],
  );
}