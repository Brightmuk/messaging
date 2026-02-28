import 'package:messaging/services/sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DefaultAppReminder {
  static const String _keyOpenCount = 'default_app_check_opens';
  static const String _keyFirstOpenTime = 'default_app_first_open';
  static const String _keyLastPrompted = 'default_app_last_prompt_time';

  static Future<bool> shouldShowPrompt() async {
    // 1. If it's already the default app, don't show anything
    bool isDefault = await SmsService.isDefaultSmsApp();
    if (isDefault) return false;

    final prefs = await SharedPreferences.getInstance();

    // 2. Track First Open Time (72 hour countdown starts here)
    int? firstOpen = prefs.getInt(_keyFirstOpenTime);
    if (firstOpen == null) {
      firstOpen = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyFirstOpenTime, firstOpen);
    }

    // 3. Track Open Count (Must be at least 10)
    int currentCount = (prefs.getInt(_keyOpenCount) ?? 0) + 1;
    await prefs.setInt(_keyOpenCount, currentCount);

    // 4. Time Check (72 Hours = 259,200,000 ms)
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool hasBeen72Hours = (now - firstOpen) >= 259200000;

    // 5. Cooldown: Don't annoy them. Only show once every 7 days if they say no.
    int lastPrompt = prefs.getInt(_keyLastPrompted) ?? 0;
    bool coolingDown = (now - lastPrompt) < 1209600000; // 14 days

    return currentCount >= 10 && hasBeen72Hours && !coolingDown;
  }

  static Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastPrompted, DateTime.now().millisecondsSinceEpoch);
  }
}