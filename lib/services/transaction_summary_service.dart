class TransactionSummary {
  final String action;
  final String amount;
  final String name;
  final bool isReceived;
  final bool isAlert; // To handle "Insufficient funds" or "Balance is..."

  TransactionSummary({
    required this.action,
    required this.amount,
    required this.name,
    required this.isReceived,
    this.isAlert = false,
  });

  factory TransactionSummary.parse(String message) {
    final String msg = message.toUpperCase();

    // 1. Handle System Alerts / Failures first
    if (msg.contains("INSUFFICIENT FUNDS") || msg.contains("FAILED") || msg.contains("CANCELLED")) {
      return TransactionSummary(
        action: "Declined",
        amount: _extractAmount(message) ?? "",
        name: msg.contains("CANCELLED") ? "User Cancelled" : "Low Balance",
        isReceived: false,
        isAlert: true,
      );
    }

    // 2. Handle Balance Inquiries
    if (msg.contains("YOUR AIRTEL MONEY BALANCE IS") || msg.contains("YOUR ACCOUNT BALANCE WAS")) {
      return TransactionSummary(
        action: "Checked balance", // Clean display name
        amount: "",               // Keep empty to hide balance
        name: "",
        isReceived: true,
        isAlert: true,
      );
    }

    // 3. Handle Reversals
    if (msg.contains("REVERSED") || msg.contains("REVERSAL")) {
      return TransactionSummary(
        action: "Reversed",
        amount: _extractAmount(message) ?? "",
        name: "Transaction",
        isReceived: false,
      );
    }

    // 4. Handle Successful Transactions
    bool received = msg.contains("RECEIVED") || msg.contains("DEPOSITED");
    String amount = _extractAmount(message) ?? "0.00";
    String name = "Transaction";

    if (msg.contains("PAID TO")) {
      name = _extractBetween(message, "paid to ", ". on");
    } else if (msg.contains("PURCHASED")) {
      name = _extractBetween(message, "of ", " via");
    } else if (received) {
      name = _extractBetween(message, "from ", " on ");
    } else if (msg.contains("SENT TO")) {
      name = _extractBetween(message, "sent to ", " on ");
    }

    return TransactionSummary(
      action: received ? "Received" : "Spent",
      amount: "Ksh $amount",
      name: name.length > 20 ? name.substring(0, 20) : name,
      isReceived: received,
    );
  }

  static String? _extractAmount(String text) {
    final match = RegExp(r"(?:Ksh|KSH)\s?([\d,.]+)").firstMatch(text);
    return match?.group(1);
  }

  static String _extractBetween(String text, String start, String end) {
    try {
      final startIndex = text.toLowerCase().indexOf(start.toLowerCase()) + start.length;
      final endIndex = text.toLowerCase().indexOf(end.toLowerCase(), startIndex);
      if (startIndex == -1 || endIndex == -1) return "General";
      return text.substring(startIndex, endIndex).trim();
    } catch (_) { return "General"; }
  }
  bool get isOutgoing => !isReceived || action == "Declined";

  /// True if this is specifically a balance inquiry (Privacy trigger)
  bool get isBalanceCheck => action == "Checked balance";

  /// True if it was a successful payment to a merchant or person
  bool get isSpent => action == "Spent";

  bool get isSpendOrReceived => isSpent || isReceived;

  /// True if it's a reversal or a deposit
  bool get isIncoming => isReceived && !isBalanceCheck;

  /// True if the transaction failed (Insufficient funds, etc.)
  bool get hasFailed => isAlert && action == "Declined";
}