import 'package:shared_preferences/shared_preferences.dart';

class UserDefaults {
  static const String _hasSyncedString = 'hasSynced';
  static const String _hasViewedPermissionString = 'hasViewedPermission';
  static const String _defaultSimString = 'defaultSim';
  static const String _hideStatusString = 'hideStatus';
  static const String _hasOnboardedString = 'hasOnboarded';
  static const String _adsRemovedString = 'adsRemoved';
  static const String _demoModeKey = 'isDemoMode';
  static const String _canshowOverlayKey = 'canShowOverlay';
   static const String _nextShowOverlayPromptKey = 'nextShowOverlayPrompt';
  static const String _textScaleKey = 'textScale';
  static const String _hasOnboardedMchangoString = 'hasOnboardedMchango';

  static Future<void> setHasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_hasOnboardedString, true);
  }

  static Future<bool> hasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasOnboardedString) ?? false;
  }
    static Future<void> setHasViewedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_hasViewedPermissionString, true);
  }

  static Future<bool> hasViewedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasViewedPermissionString) ?? false;
  }

  static void setHasSynced() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_hasSyncedString, true);
  }

  static Future<bool> hasSynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSyncedString) ?? false;
  }

  static Future<int> getDefaultSim() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultSimString) ?? -1;
  }

  static Future<void> setDefaultSim(int simId) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_defaultSimString, simId);
  }

  static Future<void> setHideStatus(bool hideStatus) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_hideStatusString, hideStatus);
  }

  static Future<bool> getHideStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideStatusString) ?? true;
  }

  static Future<void> setAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_adsRemovedString, true);
  }

  static Future<bool> getAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    if(await isDemoMode()) return true;
    return prefs.getBool(_adsRemovedString) ?? false;
  }

  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoModeKey) ?? false;
  }

  static Future<void> setDemoMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, value);
  }
    static Future<bool> canShowOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_canshowOverlayKey) ?? false;
  }

  static Future<void> setShowOverlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_canshowOverlayKey, value);
  }
  static Future<bool> canShowOverlayPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    int? timestamp = prefs.getInt(_nextShowOverlayPromptKey) ?? 0;
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();
    return date.isBefore(now);

  }
  static Future<void> setDismissedShowOverlayPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime nextshow = DateTime.now().add(const Duration(days: 25));
    await prefs.setInt(_nextShowOverlayPromptKey, nextshow.millisecondsSinceEpoch);
  }
  static Future<double> getTextScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_textScaleKey) ?? 1.1;
  }
  static Future<void> setTextScale(double scale)async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, scale);
  }
    static Future<void> setHasOnboardedMchango() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_hasOnboardedMchangoString, true);
  }

  static Future<bool> hasOnboardedMchango() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasOnboardedMchangoString) ?? false;
  }
}
