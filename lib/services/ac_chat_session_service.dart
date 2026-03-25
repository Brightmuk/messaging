class ActiveChatSession {
  static final ActiveChatSession _instance = ActiveChatSession._internal();
  factory ActiveChatSession() => _instance;
  ActiveChatSession._internal();

  String? _activeThreadId;

  void enter(String threadId) {
    _activeThreadId = threadId;
  }

  void leave() {
    _activeThreadId = null;
  }

  bool isActive(String threadId) {
    return _activeThreadId == threadId;
  }
}