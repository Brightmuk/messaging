import 'package:messaging/models/app_chat.dart';
import 'package:messaging/models/app_message.dart';

enum SearchResultType { chat, message }

class GlobalSearchResult {
  final SearchResultType type;
  final AppChat? chat;
  final AppSmsMessage? message;

  GlobalSearchResult({required this.type, this.chat, this.message});
}