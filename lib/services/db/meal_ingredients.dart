List<String> extractIngredients(Map<String, dynamic> meal) {
  final List<String> ingredients = [];

  for (int i = 1; i <= 20; i++) {
    final ing = meal['strIngredient$i']?.toString().trim();
    final mea = meal['strMeasure$i']?.toString().trim();

    if (ing != null && ing.isNotEmpty) {
      final line = '${mea ?? ''} $ing'.trim();
      ingredients.add(line);
    }
  }
  return ingredients;
}