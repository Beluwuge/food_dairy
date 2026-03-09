import 'mealdb_api.dart';

class RecipeFeedRepository {
  RecipeFeedRepository._();
  static final RecipeFeedRepository instance = RecipeFeedRepository._();

  final MealDbApi _api = MealDbApi();

  final List<Map<String, dynamic>> _meals = [];
  final Set<String> _seenIds = {};
  int _letterIndex = 0;
  bool _loading = false;
  bool _done = false;

  List<Map<String, dynamic>> get cachedMeals => List.unmodifiable(_meals);

  bool get isDone => _done;

  void reset() {
    _meals.clear();
    _seenIds.clear();
    _letterIndex = 0;
    _loading = false;
    _done = false;
  }

  String _currentLetter() =>
      String.fromCharCode('a'.codeUnitAt(0) + _letterIndex);

  Future<List<Map<String, dynamic>>> loadNextBatch() async {
    if (_loading || _done) return cachedMeals;
    if (_letterIndex > 25) {
      _done = true;
      return cachedMeals;
    }

    _loading = true;
    try {
      final letter = _currentLetter();
      final nextMeals = await _api.listMealsByFirstLetter(letter);

      for (final meal in nextMeals) {
        final id = (meal['idMeal'] ?? '').toString();
        if (id.isEmpty || _seenIds.contains(id)) continue;
        _seenIds.add(id);
        _meals.add(meal);
      }

      _letterIndex++;
      if (_letterIndex > 25) _done = true;
    } catch (_) {
      _letterIndex++;
      if (_letterIndex > 25) _done = true;
    } finally {
      _loading = false;
    }

    return cachedMeals;
  }

  Future<List<Map<String, dynamic>>> ensureAtLeast(int minimumCount) async {
    while (_meals.length < minimumCount && !_done) {
      await loadNextBatch();
    }
    return cachedMeals;
  }
}