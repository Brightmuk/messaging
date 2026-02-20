import 'dart:convert';

class AppChat {
  final String threadId;
  final String address;
  final String normalizedAddress;
  final String? lastMessage;
  final int? lastMessageDate;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;

  AppChat._internal({
    required this.threadId,
    required this.address,
    required this.normalizedAddress,
    this.lastMessage,
    this.lastMessageDate,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
  });
  factory AppChat({
    required String threadId,
    required String address,
    String? lastMessage,
    int? lastMessageDate,
    int unreadCount = 0,
    bool isPinned = false,
    bool isArchived = false,
  }) {
    return AppChat._internal(
      threadId: threadId,
      address: address,
      normalizedAddress: normalizeAddress(address),
      lastMessage: lastMessage,
      lastMessageDate: lastMessageDate,
      unreadCount: unreadCount,
      isPinned: isPinned,
      isArchived: isArchived,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'threadId': threadId,
      'address': address,
      'normalizedAddress': normalizedAddress,
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
        other.normalizedAddress == normalizedAddress &&
        other.lastMessage == lastMessage &&
        other.lastMessageDate == lastMessageDate &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode {
    return threadId.hashCode ^
        address.hashCode ^
        normalizedAddress.hashCode ^
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

  static String normalizeAddress(String address) {
    // 1. Remove whitespace and convert to uppercase for consistency (e.g., "m-pesa" vs "MPESA")
    String clean = address.trim().toUpperCase();

    // 2. Identify if it's an Alphanumeric Sender ID (Labels like "MPESA", "ADMTXT")
    // If it contains any letters, we treat it as a literal label.
    if (RegExp(r'[A-Z]').hasMatch(clean)) {
      return clean;
    }

    // 3. Identify if it's a Shortcode (e.g., "555", "20205")
    // Shortcodes are digits-only but usually very short (3-6 digits).
    // We don't want to slice these; we want the exact code.
    String digitsOnly = clean.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length <= 6) {
      return digitsOnly;
    }

    // 4. Handle Standard Phone Numbers (e.g., +2547..., 07..., 01...)
    // We take the last 9 digits to ensure +254722... and 0722... match.
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }

    // Fallback for anything else
    return digitsOnly.isEmpty ? clean : digitsOnly;
  }

  bool isSameThread(String? newThreadId, String newAddress) {
    return normalizeAddress(newAddress) == normalizeAddress(address) ||
        (newThreadId != null && newThreadId == threadId);
  }
}
