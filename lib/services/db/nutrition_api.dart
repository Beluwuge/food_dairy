import 'dart:convert';
import 'package:http/http.dart' as http;

class NutritionApi {
  // TODO: Put your real credentials here
  static const String appId = 'YOUR_EDAMAM_APP_ID';
  static const String appKey = 'YOUR_EDAMAM_APP_KEY';

  static const String _endpoint = 'https://api.edamam.com/api/nutrition-details';

  Future<Map<String, dynamic>> analyzeIngredients({
    required String title,
    required List<String> ingredients,
  }) async {
    final uri = Uri.parse('$_endpoint?app_id=$appId&app_key=$appKey');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'ingr': ingredients,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Nutrition API error: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}