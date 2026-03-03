import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'services/db/mealdb_api.dart';
import 'services/db/nutrition_api.dart';
import 'services/db/meal_ingredients.dart';

class RecipeGridPage extends StatefulWidget {
  const RecipeGridPage({super.key});

  @override
  State<RecipeGridPage> createState() => _RecipeGridPageState();
}

class _RecipeGridPageState extends State<RecipeGridPage> {
  final _api = MealDbApi();

  // Simple feed: choose a letter; later you can replace with search/filter
  String _letter = 'a';
  late Future<List<Map<String, dynamic>>> _mealsFuture;

  // Cache full meal details so we don't refetch on every tap
  final Map<String, Map<String, dynamic>> _mealDetailsCache = {};

  @override
  void initState() {
    super.initState();
    _mealsFuture = _api.listMealsByFirstLetter(_letter);
  }

  Future<void> _reload(String letter) async {
    setState(() {
      _letter = letter;
      _mealsFuture = _api.listMealsByFirstLetter(_letter);
    });
  }

  Future<Map<String, dynamic>> _getMealDetails(Map<String, dynamic> meal) async {
    final id = (meal['idMeal'] ?? '').toString();
    if (id.isEmpty) return meal;

    final cached = _mealDetailsCache[id];
    if (cached != null) return cached;

    // search.php returns full meal details already; but keep this robust
    final hasIngredients = meal.containsKey('strIngredient1');
    final details = hasIngredients ? meal : await _api.lookupMealById(id);

    _mealDetailsCache[id] = details;
    return details;
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
      builder: (_) => _RecipePostSheet(meal: details),
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
        actions: [
          _LetterMenu(
            current: _letter,
            onPick: (l) => _reload(l),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mealsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Load failed: ${snap.error}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final meals = snap.data ?? [];
          if (meals.isEmpty) {
            return const Center(
              child: Text('No meals found', style: TextStyle(color: Colors.white70)),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: meals.length,
            itemBuilder: (context, i) {
              final m = meals[i];
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
          );
        },
      ),
    );
  }
}

class _RecipePostSheet extends StatelessWidget {
  const _RecipePostSheet({required this.meal});

  final Map<String, dynamic> meal;

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
                // Post media (square like IG)
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

                // Header row
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

                // Meta chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(text: category.isEmpty ? 'Unknown category' : category),
                      _Chip(text: area.isEmpty ? 'Unknown area' : area),
                      // Calories placeholder (you’ll wire later)
                      const _Chip(text: 'Calories: (later)'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Ingredients
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

                // Instructions
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

class _LetterMenu extends StatelessWidget {
  const _LetterMenu({required this.current, required this.onPick});

  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune),
      onSelected: onPick,
      itemBuilder: (_) {
        const letters = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
        return letters
            .map(
              (l) => PopupMenuItem(
            value: l,
            child: Row(
              children: [
                Expanded(child: Text('Feed: "$l"')),
                if (l == current) const Icon(Icons.check, size: 16),
              ],
            ),
          ),
        )
            .toList();
      },
    );
  }
}