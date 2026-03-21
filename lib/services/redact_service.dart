enum RedactType { received, paid, sent, balanceCheck, any }

class RedactResult {
  final String message;
  final RedactType redactType;

  const RedactResult({
    required this.message,
    required this.redactType,
  });

  bool get isRedacted => message.endsWith('...');
  bool get isOutgoing =>
      redactType == RedactType.sent || redactType == RedactType.paid;
}

class RedactService {
  static const List<String> monitoredConversations = [
    'mpesa',
    'airtelmoney',
    'zidii',
    'mshwari',
    'tkash'
  ];

  static RedactResult redactAfterBalance(String message, String address) {
    final RedactType type = _detectType(message);

    if (!isMonitored(address)) {
      return RedactResult(message: message, redactType: type);
    }

    // Matches:
    // "New M-PESA balance is Ksh3,201.74"
    // "Your account balance was: M-PESA Account : Ksh..."
    // "Your Airtel Money balance is 45.00"
    final RegExp balancePattern = RegExp(
      r'(new m-?pesa balance is ksh|account balance was[:\s]+|airtel money balance is)',
      caseSensitive: false,
    );

    final match = balancePattern.firstMatch(message);

    if (match != null) {
      return RedactResult(
        message: '${message.substring(0, match.start)}...',
        redactType: type,
      );
    }

    return RedactResult(message: message, redactType: type);
  }

static RedactType _detectType(String message) {
  final lower = message.toLowerCase();

  if (lower.contains('you have received')) {
    return RedactType.received;
  }

  // "paid to <NAME>." — till number payments
  // "sent to <NAME> for account" — paybill, treat as payment
  if (RegExp(r'paid to .+\.|sent to .+ for account').hasMatch(lower)) {
    return RedactType.paid;
  }

  // "sent to <NAME> <phone>" or bare "sent to" — person-to-person
  if (lower.contains('sent to')) {
    return RedactType.sent;
  }

  if (RegExp(r'account balance was|balance is [\d,]+').hasMatch(lower)) {
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
