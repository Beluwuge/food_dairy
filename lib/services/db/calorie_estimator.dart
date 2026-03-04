import 'dart:math';

import 'usda_nutrition_api.dart';

class CalorieEstimator {
  final UsdaNutritionApi usda;
  CalorieEstimator(this.usda);

  // Very rough measure -> grams estimator
  int estimateGrams(String measure) {
    final s = measure.toLowerCase().trim();

    double qty = 1.0;
    final numMatch = RegExp(r'^\d+(\.\d+)?').firstMatch(s);
    if (numMatch != null) {
      qty = double.tryParse(numMatch.group(0)!) ?? 1.0;
    }

    if (s.contains('tbsp') || s.contains('tablespoon')) return (qty * 15).round();
    if (s.contains('tsp') || s.contains('teaspoon')) return (qty * 5).round();
    if (s.contains('cup')) return (qty * 240).round();
    if (s.contains('g')) return (qty * 1).round();
    if (s.contains('kg')) return (qty * 1000).round();
    if (s.contains('ml')) return (qty * 1).round();
    if (s.contains('oz')) return (qty * 28).round();
    if (s.contains('lb')) return (qty * 454).round();

    if (s.contains('pinch') || s.contains('dash')) return 1;
    if (s.contains('to taste')) return 0;

    return 50; // fallback
  }

  /// Estimate kcal for a MealDB meal JSON (uses strIngredient1..20 + strMeasure1..20)
  Future<int?> estimateMealCalories(Map<String, dynamic> meal) async {
    int totalKcal = 0;
    int matchedCount = 0;

    for (int i = 1; i <= 20; i++) {
      final ing = (meal['strIngredient$i'] ?? '').toString().trim();
      final mea = (meal['strMeasure$i'] ?? '').toString().trim();
      if (ing.isEmpty) continue;

      final kcalPer100g = await usda.caloriesPer100g(ing);
      if (kcalPer100g == null) continue;

      final grams = max(0, estimateGrams(mea));
      final kcal = (kcalPer100g * (grams / 100.0)).round();
      totalKcal += kcal;
      matchedCount++;
    }

    if (matchedCount == 0 || totalKcal <= 0) return null;
    return totalKcal;
  }
}