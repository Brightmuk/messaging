import 'package:shared_preferences/shared_preferences.dart';

class UserDefaults {
  static const String _hasSyncedString = 'hasSynced';
  static const String _hasViewedPermissionString = 'hasViewedPermission';
  static const String _defaultSimString = 'defaultSim';
  static const String _hideStatusString = 'hideStatus';
  static const String _hasOnboardedString = 'hasOnboarded';
  static const String _adsRemovedString = 'adsRemoved';
  static const String _demoModeKey = 'isDemoMode';

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
}
