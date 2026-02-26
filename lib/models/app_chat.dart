import 'dart:convert';

import 'package:flutter/material.dart';

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
  static bool isBusiness(String address){
     return !supportsReplies(address) || address.length < 6;
  }

  static String normalizeAddress(String address) {
    String clean = address.trim().toUpperCase();

    if (RegExp(r'[A-Z]').hasMatch(clean)) {
      return clean;
    }

    String digitsOnly = clean.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length <= 6) {
      return digitsOnly;
    }

    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }

    return digitsOnly.isEmpty ? clean : digitsOnly;
  }

  bool isSameThread(String? newThreadId, String newAddress) {
    return normalizeAddress(newAddress) == normalizeAddress(address) ||
        (newThreadId != null && newThreadId == threadId);
  }
  Widget prefix(Color color) {
    if (AppChat.isBusiness(address)) {
      return Icon(
        Icons.business_outlined,
        color: color,
      );
    }
    if (address.startsWith(RegExp(r'[a-zA-Z]')) && address.isNotEmpty) {
      return Text(address[0].toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold));
    }
    return Icon(Icons.person_outline, color: color);
  }
}
