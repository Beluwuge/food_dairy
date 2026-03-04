import 'dart:convert';
import 'package:http/http.dart' as http;

/// USDA FoodData Central minimal client (calories only).
class UsdaNutritionApi {
  final String apiKey;
  UsdaNutritionApi({required this.apiKey});

  static const _base = 'https://api.nal.usda.gov/fdc/v1';

  /// Returns kcal per 100g for the best match, if available.
  Future<double?> caloriesPer100g(String ingredientName) async {
    final uri = Uri.parse('$_base/foods/search?api_key=$apiKey');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "query": ingredientName,
        "pageSize": 1,
      }),
    );

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final foods = (data['foods'] as List?) ?? [];
    if (foods.isEmpty) return null;

    final food = foods.first as Map<String, dynamic>;
    final nutrients = (food['foodNutrients'] as List?) ?? [];

    // Look for Energy (kcal)
    for (final n in nutrients) {
      final m = n as Map<String, dynamic>;
      final name = (m['nutrientName'] ?? '').toString().toLowerCase();
      final unit = (m['unitName'] ?? '').toString().toLowerCase();
      final value = m['value'];

      if (name.contains('energy') && unit.contains('kcal') && value is num) {
        return value.toDouble();
      }
    }
    return null;
  }
}