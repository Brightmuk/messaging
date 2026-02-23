class RedactService {
  static List<String> monitoredConversations = ['mpesa', 'airtelmoney','zidii','mshwari','tkash'];
  static String redactAfterBalance(String message, String address) {
    // 1. Check if the address is monitored (M-Pesa, etc.)
    if (!monitoredConversations.any((keyword) => address.toLowerCase().contains(keyword))) {
      return message;
    }

    final RegExp balancePattern = RegExp(
      r'(balance|bal|amt)(?:\s+is)?(?:\s*[:\-])?\s*(?:Ksh|KSH)',
      caseSensitive: false,
    );

    final match = balancePattern.firstMatch(message);

    if (match != null) {
      // Cut the message right after the word 'Balance' or 'Ksh'
      // match.end gives us the position after "Ksh"
      return "${message.substring(0, match.end)}...";
    }

    return message;
  }
static bool isMonitored(String address) {
  return monitoredConversations.any((keyword) => address.toLowerCase().contains(keyword));
  }
}