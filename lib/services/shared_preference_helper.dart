import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceHelper {
  // ---------- Map helpers ----------

  static Future<Map<String, dynamic>> getMap(String key) async {
    final pref = await SharedPreferences.getInstance();

    final value = pref.getString(key);
    if (value == null || value.isEmpty) return {};

    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;

    // If somehow stored as other JSON type, return empty safely
    return {};
  }

  static Future<void> saveMap(String key, Map<String, dynamic> map) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(key, jsonEncode(map));
  }

  static Future<void> removeKey(String key) async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(key);
  }

  static Future<void> clearAll() async {
    final pref = await SharedPreferences.getInstance();
    await pref.clear();
  }

  // ---------- Session helpers ----------

  static const String sessionKey = 'session'; // {"isLoggedIn": true, "username": "..."}

  static Future<void> setSession({
    required String username,
    required bool isLoggedIn,
  }) async {
    await saveMap(sessionKey, {
      'isLoggedIn': isLoggedIn,
      'username': username,
    });
  }

  static Future<void> clearSession() async {
    await removeKey(sessionKey);
  }

  static Future<String?> currentUsername() async {
    final session = await getMap(sessionKey);
    final isLoggedIn = session['isLoggedIn'] == true;
    final username = session['username']?.toString().trim();
    if (!isLoggedIn) return null;
    if (username == null || username.isEmpty) return null;
    return username;
  }

  // ---------- User-scoped keys ----------

  /// Use this for all per-user saved maps:
  /// e.g. keyForUser('profile', 'john') => 'profile__john'
  static String keyForUser(String baseKey, String username) => '${baseKey}__${username.trim()}';

  /// Convenience: get a per-user map in one call
  static Future<Map<String, dynamic>> getUserMap(String baseKey, String username) async {
    return getMap(keyForUser(baseKey, username));
  }

  /// Convenience: save a per-user map in one call
  static Future<void> saveUserMap(String baseKey, String username, Map<String, dynamic> map) async {
    return saveMap(keyForUser(baseKey, username), map);
  }

  /// Optional: remove a per-user key
  static Future<void> removeUserKey(String baseKey, String username) async {
    return removeKey(keyForUser(baseKey, username));
  }
}