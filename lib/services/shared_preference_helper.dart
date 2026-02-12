import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedPreferenceHelper {
  static Future<Map<String, dynamic>> getMap(String key) async{
    SharedPreferences pref = await .getInstance();
    if(pref.containsKey(key)){
      String? value = pref.getString(key);
      if(value != null){
        return jsonDecode(value) as Map<String, dynamic>;
      }
      else {
        return{};
      }
    }
    else {
      return{};
    }
  }

  static Future<void> saveMap(String key, Map<String, dynamic> map) async{
    SharedPreferences pref = await.getInstance();
    String mapString = jsonEncode(map);
    await pref.setString(key, mapString);
  }
}