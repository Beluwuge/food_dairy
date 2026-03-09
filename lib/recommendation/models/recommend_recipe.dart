class RecommendRecipe {
  final String id;
  final String name;
  final String cuisine;
  final int calories;
  final List<String> ingredients;
  final String? imageUrl;

  const RecommendRecipe({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.calories,
    required this.ingredients,
    this.imageUrl,
  });
}