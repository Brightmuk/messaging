// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class AppSmsMessage {
  final int? id;
  final String address;
  final String body;
  final int date;
  final int type; // 1 = received, 2 = sent
  final String threadId;
  final bool read;

  AppSmsMessage({
    this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.type,
    required this.threadId,
    this.read = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date,
      'type': type,
      'threadId': threadId,
      'read': read ? 1 : 0,
    };
  }

  factory AppSmsMessage.fromMap(Map<String, dynamic> map) {
    return AppSmsMessage(
      id: map['id'],
      address: map['address'],
      body: map['body'],
      date: map['date'],
      type: map['type'],
      threadId: map['threadId'],
      read: map['read'] == 1,
    );
  }

  bool get isSent => type == 2;
  bool get isReceived => type == 1;
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppSmsMessage &&
        other.id == id &&
        other.address == address &&
        other.body == body &&
        other.date == date &&
        other.type == type &&
        other.threadId == threadId &&
        other.read == read;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        address.hashCode ^
        body.hashCode ^
        date.hashCode ^
        type.hashCode ^
        threadId.hashCode ^
        read.hashCode;
  
  }
 
}

class AppChat {
  final String threadId;
  final String address;
  final String? lastMessage;
  final int? lastMessageDate;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;

  AppChat({
    required this.threadId,
    required this.address,
    this.lastMessage,
    this.lastMessageDate,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
  });

  bool isSameThread(String? newThreadId, String newAddress) {
    return normalize(newAddress) == normalize(address) ||
        (newThreadId != null && newThreadId == threadId);
  }

  static String normalize(String phone) {
    if (phone.isEmpty) return '';
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('254')) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'threadId': threadId,
      'address': address,
      'lastMessage': lastMessage,
      'lastMessageDate': lastMessageDate,
      'unreadCount': unreadCount,
      'isPinned': isPinned ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
    };
  }

  factory AppChat.fromMap(Map<String, dynamic> map) {
    return AppChat(
      threadId: map['threadId'] as String,
      address: map['address'] as String,
      lastMessage:
          map['lastMessage'] != null ? map['lastMessage'] as String : null,
      lastMessageDate:
          map['lastMessageDate'] != null ? map['lastMessageDate'] as int : null,
      unreadCount: map['unreadCount'] as int,
      isPinned: (map['isPinned'] as int?) == 1,
      isArchived: (map['isArchived'] as int?) == 1,
    );
  }

  AppChat copyWith({
    String? threadId,
    String? address,
    String? lastMessage,
    int? lastMessageDate,
    int? unreadCount,
  }) {
    return AppChat(
      threadId: threadId ?? this.threadId,
      address: address ?? this.address,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  String toJson() => json.encode(toMap());

  factory AppChat.fromJson(String source) =>
      AppChat.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'AppChat(threadId: $threadId, address: $address, lastMessage: $lastMessage, lastMessageDate: $lastMessageDate, unreadCount: $unreadCount)';
  }

  @override
  bool operator ==(covariant AppChat other) {
    if (identical(this, other)) return true;

    return other.threadId == threadId &&
        other.address == address &&
        other.lastMessage == lastMessage &&
        other.lastMessageDate == lastMessageDate &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode {
    return threadId.hashCode ^
        address.hashCode ^
        lastMessage.hashCode ^
        lastMessageDate.hashCode ^
        unreadCount.hashCode;
  }

  static bool supportsReplies(String address) {
    if (RegExp(r'[a-zA-Z]').hasMatch(address)) {
      return false;
    }
    String clean = address.replaceAll(RegExp(r'\D'), '');
    return clean.length >= 3;
  }
}
