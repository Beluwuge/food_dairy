import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'services/db/app_database.dart';
import 'services/db/calorie_estimator.dart';
import 'services/db/meal_ingredients.dart';
import 'services/db/mealdb_api.dart';
import 'services/db/recipe_feed_repository.dart';
import 'services/db/usda_nutrition_api.dart';
import 'services/shared_preference_helper.dart';

class RecipeGridPage extends StatefulWidget {
  const RecipeGridPage({super.key});

  @override
  State<RecipeGridPage> createState() => _RecipeGridPageState();
}

class _RecipeGridPageState extends State<RecipeGridPage> {
  final _api = MealDbApi();
  final _scroll = ScrollController();
  final _db = AppDatabase.instance;
  final _repository = RecipeFeedRepository.instance;

  static const String _usdaKey = '0aywdxu7epTDBs9RAFhlCbAUqvw1AHFfTvg4x4bc';
  late final CalorieEstimator _estimator =
  CalorieEstimator(UsdaNutritionApi(apiKey: _usdaKey));

  bool _loadingMore = false;
  String? _username;

  final List<Map<String, dynamic>> _meals = [];
  final Map<String, Map<String, dynamic>> _mealDetailsCache = {};
  final Map<String, int> _calorieCache = {};
  final Map<String, bool> _likedCache = {};

  @override
  void initState() {
    super.initState();
    _initUserAndFeed();

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadNextFeed();
      }
    });
  }

  Future<void> _initUserAndFeed() async {
    _username = await SharedPreferenceHelper.currentUsername() ?? 'legacy';
    if (mounted) setState(() {});
    await _loadNextFeed();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadNextFeed() async {
    if (_loadingMore || _repository.isDone) return;

    setState(() => _loadingMore = true);
    try {
      final loaded = await _repository.loadNextBatch();
      _meals
        ..clear()
        ..addAll(loaded);
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

  Future<bool> _isLiked(String username, String mealId) async {
    final cached = _likedCache[mealId];
    if (cached != null) return cached;

    final liked = await _db.isRecipeLiked(username: username, recipeId: mealId);
    _likedCache[mealId] = liked;
    return liked;
  }

  Future<void> _toggleLike({
    required String username,
    required Map<String, dynamic> meal,
    int? calories,
  }) async {
    final mealId = (meal['idMeal'] ?? '').toString();
    if (mealId.isEmpty) return;

    final current = _likedCache[mealId] ?? await _isLiked(username, mealId);

    if (current) {
      await _db.unlikeRecipe(username: username, recipeId: mealId);
      _likedCache[mealId] = false;
    } else {
      await _db.likeRecipe(
        username: username,
        recipeId: mealId,
        recipeName: (meal['strMeal'] ?? '').toString(),
        cuisine: (meal['strArea'] ?? '').toString(),
        calories: calories,
      );
      _likedCache[mealId] = true;
    }

    if (mounted) setState(() {});
  }

  Future<void> _openPost(BuildContext context, Map<String, dynamic> meal) async {
    final details = await _getMealDetails(meal);
    if (!context.mounted) return;

    final username =
        _username ?? await SharedPreferenceHelper.currentUsername() ?? 'legacy';
    final mealId = (details['idMeal'] ?? '').toString();
    final liked = mealId.isEmpty ? false : await _isLiked(username, mealId);

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
        initialLiked: liked,
        onToggleLike: (int? kcal) async {
          await _toggleLike(username: username, meal: details, calories: kcal);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usernameReady = _username != null;

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
        itemCount: _meals.length + 1,
        itemBuilder: (context, i) {
          if (i == _meals.length) {
            if (_repository.isDone) {
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
          final mealId = (m['idMeal'] ?? '').toString();
          final username = _username ?? 'legacy';

          if (!usernameReady || mealId.isEmpty) {
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
          }

          return FutureBuilder<bool>(
            future: _isLiked(username, mealId),
            builder: (context, likeSnap) {
              final isLiked = likeSnap.data ?? false;

              return InkWell(
                onTap: () => _openPost(context, m),
                child: Stack(
                  children: [
                    Positioned.fill(
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
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () async {
                          final kcal = await _getCaloriesForMeal(m);
                          await _toggleLike(
                            username: username,
                            meal: m,
                            calories: kcal,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isLiked ? Colors.redAccent : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RecipePostSheet extends StatefulWidget {
  const _RecipePostSheet({
    required this.meal,
    required this.getCalories,
    required this.initialLiked,
    required this.onToggleLike,
  });

  final Map<String, dynamic> meal;
  final Future<int?> Function(Map<String, dynamic>) getCalories;
  final bool initialLiked;
  final Future<void> Function(int? kcal) onToggleLike;

  @override
  State<_RecipePostSheet> createState() => _RecipePostSheetState();
}

class _RecipePostSheetState extends State<_RecipePostSheet> {
  late bool _liked;
  int? _kcal;

  @override
  void initState() {
    super.initState();
    _liked = widget.initialLiked;

    widget.getCalories(widget.meal).then((v) {
      if (!mounted) return;
      setState(() => _kcal = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.meal['strMeal'] ?? '').toString();
    final img = (widget.meal['strMealThumb'] ?? '').toString();
    final category = (widget.meal['strCategory'] ?? '').toString();
    final area = (widget.meal['strArea'] ?? '').toString();
    final instructions = (widget.meal['strInstructions'] ?? '').toString();
    final ingredients = extractIngredients(widget.meal);

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
                        onPressed: () async {
                          await widget.onToggleLike(_kcal);
                          if (!mounted) return;
                          setState(() => _liked = !_liked);
                        },
                        icon: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? Colors.redAccent : Colors.white70,
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
                      _Chip(
                        text: _kcal == null ? 'Calories: ...' : 'Calories: $_kcal kcal',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Ingredients',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: ingredients.isEmpty
                        ? const [
                      Text(
                        'No ingredients found.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ]
                        : ingredients
                        .map(
                          (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '•  ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Expanded(
                              child: Text(
                                e,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.25,
                                ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}