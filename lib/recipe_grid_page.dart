import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'services/db/mealdb_api.dart';
import 'services/db/meal_ingredients.dart';
import 'services/db/usda_nutrition_api.dart';
import 'services/db/calorie_estimator.dart';

class RecipeGridPage extends StatefulWidget {
  const RecipeGridPage({super.key});

  @override
  State<RecipeGridPage> createState() => _RecipeGridPageState();
}

class _RecipeGridPageState extends State<RecipeGridPage> {
  final _api = MealDbApi();
  final _scroll = ScrollController();

  // USDA key
  static const String _usdaKey = '0aywdxu7epTDBs9RAFhlCbAUqvw1AHFfTvg4x4bc';
  late final CalorieEstimator _estimator =
  CalorieEstimator(UsdaNutritionApi(apiKey: _usdaKey));

  // Feed letters a..z auto-load
  int _letterIndex = 0; // 0=a
  bool _loadingMore = false;
  bool _done = false;

  // Combined list across letters
  final List<Map<String, dynamic>> _meals = [];

  // Cache full meal details so we don't refetch
  final Map<String, Map<String, dynamic>> _mealDetailsCache = {};
  // Cache calories per meal id
  final Map<String, int> _calorieCache = {};

  @override
  void initState() {
    super.initState();
    _loadNextFeed();

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadNextFeed();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _currentLetter() => String.fromCharCode('a'.codeUnitAt(0) + _letterIndex);

  Future<void> _loadNextFeed() async {
    if (_loadingMore || _done) return;
    if (_letterIndex > 25) {
      setState(() => _done = true);
      return;
    }

    setState(() => _loadingMore = true);
    try {
      final letter = _currentLetter();
      final nextMeals = await _api.listMealsByFirstLetter(letter);

      // Add only if not empty; still move to next letter either way (to avoid infinite loop)
      if (nextMeals.isNotEmpty) {
        _meals.addAll(nextMeals);
      }

      _letterIndex++;
      if (_letterIndex > 25) _done = true;
      if (mounted) setState(() {});
    } catch (e) {
      // If a letter feed fails, skip it and continue
      _letterIndex++;
      if (_letterIndex > 25) _done = true;
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<Map<String, dynamic>> _getMealDetails(Map<String, dynamic> meal) async {
    final id = (meal['idMeal'] ?? '').toString();
    if (id.isEmpty) return meal;

    final cached = _mealDetailsCache[id];
    if (cached != null) return cached;

    // Some endpoints already return full details; check ingredient field
    final hasIngredients = meal.containsKey('strIngredient1');
    final details = hasIngredients ? meal : await _api.lookupMealById(id);

    _mealDetailsCache[id] = details;
    return details;
  }

  Future<int?> _getCaloriesForMeal(Map<String, dynamic> meal) async {
    final id = (meal['idMeal'] ?? '').toString();
    if (id.isEmpty) return null;

    final cached = _calorieCache[id];
    if (cached != null) return cached;

    final kcal = await _estimator.estimateMealCalories(meal);
    if (kcal != null) _calorieCache[id] = kcal;
    return kcal;
  }

  Future<void> _openPost(BuildContext context, Map<String, dynamic> meal) async {
    final details = await _getMealDetails(meal);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RecipePostSheet(
        meal: details,
        getCalories: _getCaloriesForMeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: const Text('Recipes'),
      ),
      body: _meals.isEmpty && _loadingMore
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        itemCount: _meals.length + 1, // +1 for footer loader
        itemBuilder: (context, i) {
          if (i == _meals.length) {
            if (_done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No more feeds',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              );
            }
            return Center(
              child: _loadingMore
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const SizedBox.shrink(),
            );
          }

          final m = _meals[i];
          final thumb = (m['strMealThumb'] ?? '').toString();

          return InkWell(
            onTap: () => _openPost(context, m),
            child: Container(
              color: const Color(0xFF121212),
              child: CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecipePostSheet extends StatelessWidget {
  const _RecipePostSheet({
    required this.meal,
    required this.getCalories,
  });

  final Map<String, dynamic> meal;
  final Future<int?> Function(Map<String, dynamic>) getCalories;

  @override
  Widget build(BuildContext context) {
    final title = (meal['strMeal'] ?? '').toString();
    final img = (meal['strMealThumb'] ?? '').toString();
    final category = (meal['strCategory'] ?? '').toString();
    final area = (meal['strArea'] ?? '').toString();
    final instructions = (meal['strInstructions'] ?? '').toString();
    final ingredients = extractIngredients(meal);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFF1C1C1E),
                        child: Icon(Icons.restaurant, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(text: category.isEmpty ? 'Unknown category' : category),
                      _Chip(text: area.isEmpty ? 'Unknown area' : area),
                      FutureBuilder<int?>(
                        future: getCalories(meal),
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const _Chip(text: 'Calories: ...');
                          }
                          final kcal = snap.data;
                          return _Chip(text: kcal == null ? 'Calories: N/A' : 'Calories: $kcal kcal');
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Ingredients',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: ingredients.isEmpty
                        ? const [
                      Text('No ingredients found.', style: TextStyle(color: Colors.white70)),
                    ]
                        : ingredients
                        .map(
                          (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: TextStyle(color: Colors.white70)),
                            Expanded(
                              child: Text(
                                e,
                                style: const TextStyle(color: Colors.white70, height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),

                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Instructions',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    instructions.isEmpty ? 'No instructions provided.' : instructions,
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}