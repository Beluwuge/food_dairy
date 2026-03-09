import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/db/app_database.dart';
import '../services/db/mealdb_api.dart';
import '../services/shared_preference_helper.dart';

class LikedRecipesPage extends StatefulWidget {
  const LikedRecipesPage({super.key});

  @override
  State<LikedRecipesPage> createState() => _LikedRecipesPageState();
}

class _LikedRecipesPageState extends State<LikedRecipesPage> {
  final AppDatabase _db = AppDatabase.instance;
  final MealDbApi _api = MealDbApi();

  bool _loading = true;
  String _username = 'legacy';

  final List<Map<String, dynamic>> _likedMeals = [];
  final Map<String, Map<String, dynamic>> _mealCache = {};

  @override
  void initState() {
    super.initState();
    _loadLikedRecipes();
  }

  Future<void> _loadLikedRecipes() async {
    setState(() => _loading = true);

    final username = await SharedPreferenceHelper.currentUsername() ?? 'legacy';
    final likedRows = await _db.getLikedRecipes(username: username);

    final meals = <Map<String, dynamic>>[];

    for (final row in likedRows) {
      final recipeId = (row['recipe_id'] ?? '').toString();
      if (recipeId.isEmpty) continue;

      try {
        Map<String, dynamic>? meal = _mealCache[recipeId];
        if (meal == null) {
          meal = await _api.lookupMealById(recipeId);
          _mealCache[recipeId] = meal;
        }
        meals.add(meal);
      } catch (_) {
        meals.add({
          'idMeal': recipeId,
          'strMeal': (row['recipe_name'] ?? 'Unknown Recipe').toString(),
          'strMealThumb': '',
          'strArea': (row['cuisine'] ?? '').toString(),
          'strInstructions': '',
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _username = username;
      _likedMeals
        ..clear()
        ..addAll(meals);
      _loading = false;
    });
  }

  Future<void> _removeLike(Map<String, dynamic> meal) async {
    final recipeId = (meal['idMeal'] ?? '').toString();
    if (recipeId.isEmpty) return;

    await _db.unlikeRecipe(
      username: _username,
      recipeId: recipeId,
    );

    _likedMeals.removeWhere((m) => (m['idMeal'] ?? '').toString() == recipeId);

    if (!mounted) return;
    setState(() {});
  }

  void _openDetails(Map<String, dynamic> meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _LikedRecipeDetailSheet(
        meal: meal,
        onUnlike: () => _removeLike(meal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: const Text('Liked'),
      ),
      body: _likedMeals.isEmpty
          ? const Center(
        child: Text(
          'No liked recipes yet.',
          style: TextStyle(color: Colors.white70),
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        itemCount: _likedMeals.length,
        itemBuilder: (context, index) {
          final meal = _likedMeals[index];
          final imageUrl = (meal['strMealThumb'] ?? '').toString();

          return InkWell(
            onTap: () => _openDetails(meal),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
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
                  )
                else
                  Container(
                    color: const Color(0xFF121212),
                    child: const Center(
                      child: Icon(Icons.restaurant, color: Colors.white54),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 18,
                      color: Colors.redAccent,
                    ),
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

class _LikedRecipeDetailSheet extends StatelessWidget {
  const _LikedRecipeDetailSheet({
    required this.meal,
    required this.onUnlike,
  });

  final Map<String, dynamic> meal;
  final Future<void> Function() onUnlike;

  @override
  Widget build(BuildContext context) {
    final title = (meal['strMeal'] ?? '').toString();
    final img = (meal['strMealThumb'] ?? '').toString();
    final area = (meal['strArea'] ?? '').toString();
    final instructions = (meal['strInstructions'] ?? '').toString();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (img.isNotEmpty)
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
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await onUnlike();
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.favorite, color: Colors.redAccent),
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
                  child: Text(
                    area.isEmpty ? 'Unknown area' : area,
                    style: const TextStyle(color: Colors.white70),
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