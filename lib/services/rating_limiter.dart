import 'package:shared_preferences/shared_preferences.dart';


class RateLimiter {
  static const String _keyOpenCount = 'app_open_count';
  static const String _keyHasRated = 'has_rated_app';
  static const String _keyFirstInstallTime = 'first_install_time';

  static Future<bool> shouldShowRateDialog() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check if they already rated
    if (prefs.getBool(_keyHasRated) ?? false) return false;

    // 2. Track First Install Time
    int? firstInstall = prefs.getInt(_keyFirstInstallTime);
    if (firstInstall == null) {
      firstInstall = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyFirstInstallTime, firstInstall);
    }

    // 3. Increment Open Counter
    int currentCount = (prefs.getInt(_keyOpenCount) ?? 0) + 1;
    await prefs.setInt(_keyOpenCount, currentCount);

    // 4. Calculate Time Elapsed (24 Hours = 86,400,000 ms)
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool hasBeen24Hours = (now - firstInstall) >= 86400000;

    // 5. Logic: Only show on the 3rd open AND after 24 hours
    return currentCount >= 3 && hasBeen24Hours;
  }

  // If they tap "Later", we reset the open count to 0 to "snooze" the request
  static Future<void> snooze() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOpenCount, 0); 
  }

  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
  }
}