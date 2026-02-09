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
    
    return super == other;
  }
}

class AppChat {
  final String threadId;
  final String address;
  final String? lastMessage;
  final int? lastMessageDate;
  final int unreadCount;

  AppChat({
    required this.threadId,
    required this.address,
    this.lastMessage,
    this.lastMessageDate,
    this.unreadCount = 0,
  });



  bool isSameThread (String newThreadId, String newAddress) {
    print("Comparing $threadId and $newThreadId with $address and $newAddress");
    return newThreadId == threadId || 
           normalize(newAddress) == normalize(address);
  }

  @override
  int get hashCode => Object.hash(threadId, normalize(address));
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
    return {
      'threadId': threadId,
      'address': address,
      'lastMessage': lastMessage,
      'lastMessageDate': lastMessageDate,
      'unreadCount': unreadCount,
    };
  }

  factory AppChat.fromMap(Map<String, dynamic> map) {
    return AppChat(
      threadId: map['threadId'],
      address: map['address'],
      lastMessage: map['lastMessage'],
      lastMessageDate: map['lastMessageDate'],
      unreadCount: map['unreadCount'] ?? 0,
    );
  }
}
