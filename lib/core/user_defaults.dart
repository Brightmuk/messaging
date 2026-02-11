import 'package:shared_preferences/shared_preferences.dart';

class UserDefaults {
  static String hasSyncedString = 'hasSynced';
  static String defaultSimString = 'defaultSim';


  static void setHasSynced() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(hasSyncedString, true);
  }
  static Future<bool> hasSynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hasSyncedString) ?? false;
  }
  static Future<int> getDefaultSim() async {
     final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(defaultSimString) ?? -1;
  }
  static Future<void> setDefaultSim(int simId) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(defaultSimString, simId);
  }

}

  
