import '../services/db/app_database.dart';
import '../services/db/recipe_feed_repository.dart';
import '../services/shared_preference_helper.dart';

class RecommendResult {
  final Map<String, dynamic> meal;
  final int score;
  final List<String> reasons;

  const RecommendResult({
    required this.meal,
    required this.score,
    required this.reasons,
  });
}

class RecommendService {
  RecommendService({
    AppDatabase? db,
    RecipeFeedRepository? repository,
  })  : _db = db ?? AppDatabase.instance,
        _repository = repository ?? RecipeFeedRepository.instance;

  final AppDatabase _db;
  final RecipeFeedRepository _repository;

  Future<List<RecommendResult>> getRecommendations({
    String? username,
    int limit = 25,
  }) async {
    final user = username ?? await _readUsername();

    final likedRows = await _db.getLikedRecipes(username: user);
    final preferredCuisine = _findTopCuisine(likedRows);

    // IMPORTANT: Only use cached meals (no API calls)
    final meals = _repository.cachedMeals;

    if (meals.isEmpty) {
      return [];
    }

    final results = <RecommendResult>[];

    for (final meal in meals) {
      results.add(_scoreMeal(meal, preferredCuisine, likedRows));
    }

    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).toList();
  }

  RecommendResult _scoreMeal(
      Map<String, dynamic> meal,
      String? preferredCuisine,
      List<Map<String, dynamic>> likedRows,
      ) {
    int score = 0;
    final reasons = <String>[];

    final cuisine = (meal['strArea'] ?? '').toString().trim();

    if (preferredCuisine != null &&
        preferredCuisine.isNotEmpty &&
        _normCuisine(cuisine) == _normCuisine(preferredCuisine)) {
      score += 5;
      reasons.add('Because you like $preferredCuisine cuisine');
    }

    if (_likedCuisineHit(cuisine, likedRows)) {
      score += 3;
      reasons.add('Similar to recipes you liked');
    }

    if (reasons.isEmpty) {
      reasons.add('Recommended for you');
    }

    return RecommendResult(
      meal: meal,
      score: score,
      reasons: reasons,
    );
  }

  bool _likedCuisineHit(String cuisine, List<Map<String, dynamic>> liked) {
    final normalizedCuisine = _normCuisine(cuisine);
    if (normalizedCuisine.isEmpty) return false;

    for (final row in liked) {
      final likedCuisine = (row['cuisine'] ?? '').toString();
      if (_normCuisine(likedCuisine) == normalizedCuisine) {
        return true;
      }
    }

    return false;
  }

  String? _findTopCuisine(List<Map<String, dynamic>> liked) {
    if (liked.isEmpty) return null;

    final counts = <String, int>{};

    for (final row in liked) {
      final cuisine = (row['cuisine'] ?? '').toString().trim();
      if (cuisine.isEmpty) continue;

      counts[cuisine] = (counts[cuisine] ?? 0) + 1;
    }

    if (counts.isEmpty) return null;

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  String _normCuisine(String value) {
    return value.toLowerCase().trim();
  }

  Future<String> _readUsername() async {
    final username = await SharedPreferenceHelper.currentUsername();
    return username ?? 'legacy';
  }
}