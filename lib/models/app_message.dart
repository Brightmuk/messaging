enum MessageStatus {
  unknown(0),
  pending(1), 
  sent(2), 
  delivered(3), 
  failed(4); 

  final int value;
  const MessageStatus(this.value);

  static MessageStatus fromInt(int value) {
    return MessageStatus.values.firstWhere((e) => e.value == value,
        orElse: () => MessageStatus.pending);
  }
}

class AppSmsMessage {
  final int? id;
  final String address;
  final String body;
  final int date;
  final int type; // 1 = received, 2 = sent
  final String threadId;
  final MessageStatus status;
  final bool read;

  AppSmsMessage({
    this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.type,
    required this.threadId,
    required this.status,
    this.read = false,
  });
  AppSmsMessage copyWith({
    int? id,
    String? address,
    int? type,
    String? body,
    int? date,
    String? threadId,
    MessageStatus? status,
    bool? read,
  }) {
    return AppSmsMessage(
      id: id ?? this.id,
      address: address ?? this.address,
      type: type ?? this.type,
      body: body ?? this.body,
      date: date ?? this.date,
      threadId: threadId ?? this.threadId,
      status: status ?? this.status,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date,
      'type': type,
      'threadId': threadId,
      'status': status.value,
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
      status: MessageStatus.fromInt(map['status']),
      read: map['read'] == 1,
    );
  }

  bool get isOutgoing => type == 2;
  bool get isIncoming => type == 1;

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
        other.status == status &&
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
        status.hashCode ^
        read.hashCode;
  }
}
