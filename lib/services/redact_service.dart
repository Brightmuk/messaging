class RedactService {
  static List<String> monitoredConversations = ['mpesa', 'airtelmoney','zidii','mshwari','tkash'];
  static String redactBalances(String message, String address) {
    if(!monitoredConversations.any((keyword) => address.toLowerCase().contains(keyword))) {
      return message;
    }
    

  final RegExp balancePattern = RegExp(
    r'(?:balance|bal|amt)(?:\s+is)?(?:\s*[:\-])?\s*(?:Ksh|KSH)[.\s]*([\d,]+\.?\d*)',
    caseSensitive: false,
  );

  // We use splitMapJoin to find the amount and replace ONLY the number part
  return message.splitMapJoin(
    balancePattern,
    onMatch: (Match match) {
      String fullMatch = match.group(0)!;
      String amount = match.group(1)!;
      // Replace the specific amount with [HIDDEN]
      return fullMatch.replaceFirst(amount, "[HIDDEN]");
    },
    onNonMatch: (String text) => text,
  );
}
static bool isMonitored(String address) {
  return monitoredConversations.any((keyword) => address.toLowerCase().contains(keyword));
  }
}