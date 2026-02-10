import 'package:shared_preferences/shared_preferences.dart';

class UserDefaults {
  static String hasSyncedString = 'hasSynced';


  static void setHasSynced() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(hasSyncedString, true);
  }
  static Future<bool> hasSynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hasSyncedString) ?? false;
  }

}

  
