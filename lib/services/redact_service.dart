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

    // Matches any "balance is Ksh/currency" pattern as a universal fallback
    // Redacts from the currency symbol onwards e.g. "...balance is Ksh..."
    final RegExp balancePattern = RegExp(
      r'(balance is\s+)(ksh|kes|airtel|tzs)',
      caseSensitive: false,
    );

    final match = balancePattern.firstMatch(message);

    if (match != null) {
      // Keep "balance is " but redact from the currency onwards
      return RedactResult(
        message:
            '${message.substring(0, match.start + match.group(1)!.length)}...',
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

    if (RegExp(r'paid to .+\.|sent to .+ for account').hasMatch(lower)) {
      return RedactType.paid;
    }

    if (lower.contains('sent to')) {
      return RedactType.sent;
    }

    // if (RegExp(r'account balance was|balance is [\d,]+').hasMatch(lower)) {
    //   return RedactType.balanceCheck;
    // }

    // reversal — debited from account
    if (lower.contains('reversal') || lower.contains('reversed')) {
      return RedactType.any;
    }

    // failed transaction — no funds moved
    if (lower.contains('failed') || lower.contains('insufficient funds')) {
      return RedactType.any;
    }

    return RedactType.any;
  }

  static bool isMonitored(String address) {
    return monitoredConversations.any(
      (keyword) => address.toLowerCase().contains(keyword),
    );
  }
}
