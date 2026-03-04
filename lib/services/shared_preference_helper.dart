import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedPreferenceHelper {
  static Future<Map<String, dynamic>> getMap(String key) async {
    final pref = await SharedPreferences.getInstance();

    if (!pref.containsKey(key)) {
      return {};
    }

    final value = pref.getString(key);
    if (value == null || value.isEmpty) {
      return {};
    }

    return jsonDecode(value) as Map<String, dynamic>;
  }

  static Future<void> saveMap(String key, Map<String, dynamic> map) async {
    final pref = await SharedPreferences.getInstance();
    final mapString = jsonEncode(map);
    await pref.setString(key, mapString);
  }

  // ✅ Delete a specific key entirely
  static Future<void> removeKey(String key) async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(key);
  }

  // ✅ Clear everything (optional)
  static Future<void> clearAll() async {
    final pref = await SharedPreferences.getInstance();
    await pref.clear();
  }
}