import 'dart:convert';
import 'package:http/http.dart' as http;

class MealDbApi {
  // Keep www. Use HTTPS. The base directory itself returns 403, but endpoints work.
  static const String _base = 'https://www.themealdb.com/api/json/v1/1';

  Future<List<Map<String, dynamic>>> listMealsByFirstLetter(String letter) async {
    final uri = Uri.parse('$_base/search.php?f=$letter');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('MealDB HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final meals = (body['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return meals;
  }

  Future<Map<String, dynamic>> lookupMealById(String id) async {
    final uri = Uri.parse('$_base/lookup.php?i=$id');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('MealDB HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final meals = (body['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (meals.isEmpty) throw Exception('Meal not found: $id');
    return meals.first;
  }
}