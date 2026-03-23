enum MaskType { received, paid, sent, balanceCheck, any }

class MaskResult {
  final String message;
  final MaskType maskType;

  const MaskResult({
    required this.message,
    required this.maskType,
  });

  bool get isRedacted => message.endsWith('...');
  bool get isOutgoing =>
      maskType == MaskType.sent || maskType == MaskType.paid;
}

class MaskService {
  static const List<String> monitoredConversations = [
    'mpesa',
    'airtelmoney',
    'zidii',
    'mshwari',
    'tkash',
    // '791670106'
  ];

  static MaskResult maskAfterBalance(String message, String address) {
    final MaskType type = _detectType(message);

    if (!isMonitored(address)) {
      return MaskResult(message: message, maskType: type);
    }

    // Matches any "balance is Ksh/currency" pattern as a universal fallback
    // Redacts from the currency symbol onwards e.g. "...balance is Ksh..."
    final RegExp balancePattern = RegExp(
      r'(balance is\s+)(ksh|kes|airtel|tzs)',
      caseSensitive: false,
    );

    final match = balancePattern.firstMatch(message);

    if (match != null) {
      // Keep "balance is " but mask from the currency onwards
      return MaskResult(
        message:
            '${message.substring(0, match.start + match.group(1)!.length)}...',
        maskType: type,
      );
    }

    return MaskResult(message: message, maskType: type);
  }

  static MaskType _detectType(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('you have received')) {
      return MaskType.received;
    }

    if (RegExp(r'paid to .+\.|sent to .+ for account').hasMatch(lower)) {
      return MaskType.paid;
    }

    if (lower.contains('sent to')) {
      return MaskType.sent;
    }

    // if (RegExp(r'account balance was|balance is [\d,]+').hasMatch(lower)) {
    //   return RedactType.balanceCheck;
    // }

    // reversal — debited from account
    if (lower.contains('reversal') || lower.contains('reversed')) {
      return MaskType.any;
    }

    // failed transaction — no funds moved
    if (lower.contains('failed') || lower.contains('insufficient funds')) {
      return MaskType.any;
    }

    return MaskType.any;
  }

  static bool isMonitored(String address) {
    return monitoredConversations.any(
      (keyword) => address.toLowerCase().contains(keyword),
    );
  }
}
