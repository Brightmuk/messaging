enum RedactType { received, paid, sent, balanceCheck, any }

class RedactResult {
  final String message;
  final RedactType redactType;

  const RedactResult({
    required this.message,
    required this.redactType,
  });

  bool get isRedacted => message.endsWith('...');
  bool get isOutgoing => redactType == RedactType.sent || redactType == RedactType.paid;

}

class RedactService {
  static const List<String> monitoredConversations = [
    'mpesa', 'airtelmoney', 'zidii', 'mshwari', 'tkash'
  ];

static RedactResult redactAfterBalance(String message, String address) {
  final RedactType type = _detectType(message);

  if (!isMonitored(address)) {
    return RedactResult(message: message, redactType: type);
  }

  final RegExp balancePattern = RegExp(
    r'(balance|bal|amt)(?:\s+is)?(?:\s*[:\-])?\s*(?:Ksh|KSH)',
    caseSensitive: false,
  );

  final match = balancePattern.firstMatch(message);

  if (match != null) {
    return RedactResult(
      message: '${message.substring(0, match.end)}...',
      redactType: type,
    );
  }

  return RedactResult(message: message, redactType: type);
}

  static RedactType _detectType(String message) {
    final lower = message.toLowerCase();

    // Order matters — check most specific patterns first
    if (RegExp(r'\b(received|you have received|credited)\b').hasMatch(lower)) {
      return RedactType.received;
    }
    if (RegExp(r'\b(paid to|payment to|pay bill|paybill)\b').hasMatch(lower)) {
      return RedactType.paid;
    }
    if (RegExp(r'\b(sent to|you have sent|transferred to)\b').hasMatch(lower)) {
      return RedactType.sent;
    }
    if (RegExp(r'\b(balance inquiry|bal inq|account balance)\b').hasMatch(lower)) {
      return RedactType.balanceCheck;
    }

    return RedactType.any;
  }

  static bool isMonitored(String address) {
    return monitoredConversations.any(
      (keyword) => address.toLowerCase().contains(keyword),
    );
  }
 
}
