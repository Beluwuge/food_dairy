import 'dart:math';
import 'package:flutter/material.dart';
import 'package:food_dairy/services/db/app_database.dart';
import 'package:food_dairy/services/db/dish_entry.dart';
import 'package:food_dairy/services/shared_preference_helper.dart';

class AppColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgSecondary = Color(0xFF121212);
  static const bgElevated = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA8A8A8);
  static const accentPrimary = Color(0xFF0095F6);
  static const divider = Color(0xFF2A2A2E);
}

class StorageKeys {
  static const profile = 'profile';      // includes weightKg/heightCm/age
  static const waterLog = 'water_log';   // {"YYYY-MM-DD": intMl}
  static const likedIntake = 'liked_intake_log'; // {"YYYY-MM-DD": [{...}]}
}

class HealthDashboardPage extends StatefulWidget {
  const HealthDashboardPage({super.key});

  @override
  State<HealthDashboardPage> createState() => _HealthDashboardPageState();
}

class _HealthDashboardPageState extends State<HealthDashboardPage> {
  bool _loading = true;

  // Profile fields
  String _name = 'User';
  int? _age;
  double? _weightKg;
  double? _heightCm;

  // Activity
  String _activity = 'light'; // sedentary/light/moderate/active
  final Map<String, double> _activityFactor = const {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
  };

  // Outputs
  double? _bmi;
  String _bmiLabel = '-';
  int? _maintenanceCalories;

  // Water
  int _todayWaterMl = 0;
  int _quickAddMl = 250;

  // Intake
  List<DishEntry> _allPosts = [];
  List<_LikedRecipeOption> _likedRecipeOptions = [];
  List<_IntakeItem> _todayIntake = [];
  int _consumedCalories = 0;

  String get _todayKey {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    try {
      final username = await SharedPreferenceHelper.currentUsername();
      if (username == null) return;

      final profile = await SharedPreferenceHelper.getUserMap(
        StorageKeys.profile,
        username,
      );

      final water = await SharedPreferenceHelper.getUserMap(
        StorageKeys.waterLog,
        username,
      );

      final likedIntakeLog = await SharedPreferenceHelper.getUserMap(
        StorageKeys.likedIntake,
        username,
      );

      final posts = await AppDatabase.instance.getDishesByUser(username);

      final intakeRows =
      await AppDatabase.instance.getDailyIntakeRawForUser(
        username: username,
        dateKey: _todayKey,
      );

      final likedRows = await AppDatabase.instance.getLikedRecipes(
        username: username,
      );

      _allPosts = posts;
      _likedRecipeOptions = _mapLikedRecipeOptions(likedRows);

      final dbIntake = intakeRows.map((r) {
        final dish = DishEntry.fromMap(r);
        final qty = (r['quantity'] as num).toInt();
        final intakeId = (r['intake_id'] as num).toInt();
        return _IntakeItem.db(
          intakeId: intakeId,
          entry: dish,
          quantity: qty,
        );
      }).toList();

      final likedIntake = _mapLikedIntakeFromStorage(
        likedIntakeLog[_todayKey],
        username: username,
      );

      _todayIntake = [
        ...dbIntake,
        ...likedIntake,
      ];

      // FIX: match keys saved by EditProfilePage
      _name = (profile['name'] ?? 'User').toString();

      final ageRaw = profile['age'];
      _age = ageRaw == null ? null : int.tryParse(ageRaw.toString());

      final weightRaw = profile['weightKg'];
      _weightKg =
      weightRaw == null ? null : double.tryParse(weightRaw.toString());

      final heightRaw = profile['heightCm'];
      _heightCm =
      heightRaw == null ? null : double.tryParse(heightRaw.toString());

      final activityRaw = (profile['activity'] ?? 'light').toString();
      if (_activityFactor.containsKey(activityRaw)) {
        _activity = activityRaw;
      }

      final todayWater = water[_todayKey];
      _todayWaterMl =
      todayWater == null ? 0 : int.tryParse(todayWater.toString()) ?? 0;

      print("PROFILE DATA: $profile");
      print("Weight: $_weightKg Height: $_heightCm");

      _recompute();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_LikedRecipeOption> _mapLikedRecipeOptions(dynamic likedRows) {
    final result = <_LikedRecipeOption>[];

    if (likedRows is! Iterable) return result;

    for (final row in likedRows) {
      if (row is! Map) continue;

      final recipeId = (row['recipe_id'] ?? '').toString().trim();
      final name = (row['recipe_name'] ?? row['name'] ?? '').toString().trim();
      final cuisine = (row['cuisine'] ?? '').toString().trim();

      final caloriesRaw = row['calories'];
      final calories = caloriesRaw == null
          ? 0
          : int.tryParse(caloriesRaw.toString()) ?? 0;

      if (recipeId.isEmpty || name.isEmpty) continue;

      result.add(
        _LikedRecipeOption(
          recipeId: recipeId,
          name: name,
          cuisine: cuisine,
          calories: calories,
        ),
      );
    }

    return result;
  }

  List<_IntakeItem> _mapLikedIntakeFromStorage(
      dynamic raw, {
        required String username,
      }) {
    final result = <_IntakeItem>[];

    if (raw is! List) return result;

    for (final item in raw) {
      if (item is! Map) continue;

      final logId = (item['logId'] ?? '').toString().trim();
      final recipeId = (item['recipeId'] ?? '').toString().trim();
      final name = (item['name'] ?? '').toString().trim();
      final cuisine = (item['cuisine'] ?? '').toString().trim();

      final qtyRaw = item['quantity'];
      final calRaw = item['calories'];

      final quantity =
      qtyRaw == null ? 1 : int.tryParse(qtyRaw.toString()) ?? 1;
      final calories =
      calRaw == null ? 0 : int.tryParse(calRaw.toString()) ?? 0;

      if (logId.isEmpty || name.isEmpty) continue;

      final entry = DishEntry(
        id: null,
        username: username,
        imagePath: '',
        name: name,
        description: 'Liked recipe',
        calories: calories,
        cuisine: cuisine.isEmpty ? 'Liked recipe' : cuisine,
        createdAt: '',
      );

      result.add(
        _IntakeItem.liked(
          logId: logId,
          recipeId: recipeId,
          entry: entry,
          quantity: quantity,
        ),
      );
    }

    return result;
  }

  void _recompute() {
    // BMI
    if (_weightKg != null &&
        _heightCm != null &&
        _weightKg! > 0 &&
        _heightCm! > 0) {
      final hM = _heightCm! / 100.0;
      _bmi = _weightKg! / (hM * hM);
      final v = _bmi!;
      if (v < 18.5) {
        _bmiLabel = 'Underweight';
      } else if (v < 25) {
        _bmiLabel = 'Normal';
      } else if (v < 30) {
        _bmiLabel = 'Overweight';
      } else {
        _bmiLabel = 'Obese';
      }
    } else {
      _bmi = null;
      _bmiLabel = '-';
    }

    // Maintenance calories
    if (_weightKg != null && _weightKg! > 0) {
      final factor = _activityFactor[_activity] ?? 1.375;
      _maintenanceCalories = (24.0 * _weightKg! * factor).round();
    } else {
      _maintenanceCalories = null;
    }

    // Intake calories
    _consumedCalories = _todayIntake.fold<int>(
      0,
          (sum, it) => sum + (it.entry.calories * it.quantity),
    );
  }

  Future<void> _saveActivity(String activity) async {
    final username = await SharedPreferenceHelper.currentUsername();
    if (username == null) return;

    _activity = activity;

    final profile = await SharedPreferenceHelper.getUserMap(
      StorageKeys.profile,
      username,
    );

    await SharedPreferenceHelper.saveUserMap(
      StorageKeys.profile,
      username,
      {...profile, 'activity': activity},
    );

    setState(_recompute);
  }

  int _recommendedWaterMl() {
    if (_weightKg == null || _weightKg! <= 0) return 2000;
    return (35 * _weightKg!).round();
  }

  double _waterProgress() {
    final rec = _recommendedWaterMl();
    if (rec <= 0) return 0;
    return (_todayWaterMl / rec).clamp(0.0, 1.0);
  }

  Future<void> _saveWater() async {
    final username = await SharedPreferenceHelper.currentUsername();
    if (username == null) return;

    final water = await SharedPreferenceHelper.getUserMap(
      StorageKeys.waterLog,
      username,
    );

    water[_todayKey] = _todayWaterMl;

    await SharedPreferenceHelper.saveUserMap(
      StorageKeys.waterLog,
      username,
      water,
    );
  }

  Future<void> _addWater(int ml) async {
    setState(() => _todayWaterMl = max(0, _todayWaterMl + ml));
    await _saveWater();
  }

  Future<void> _resetWater() async {
    setState(() => _todayWaterMl = 0);
    await _saveWater();
  }

  Future<void> _saveLikedIntakeLogItem({
    required String username,
    required _LikedRecipeOption recipe,
    required int quantity,
  }) async {
    final log = await SharedPreferenceHelper.getUserMap(
      StorageKeys.likedIntake,
      username,
    );

    final current = (log[_todayKey] is List)
        ? List<Map<String, dynamic>>.from(
      (log[_todayKey] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
      ),
    )
        : <Map<String, dynamic>>[];

    current.add({
      'logId': DateTime.now().microsecondsSinceEpoch.toString(),
      'recipeId': recipe.recipeId,
      'name': recipe.name,
      'cuisine': recipe.cuisine,
      'calories': recipe.calories,
      'quantity': quantity,
    });

    log[_todayKey] = current;

    await SharedPreferenceHelper.saveUserMap(
      StorageKeys.likedIntake,
      username,
      log,
    );
  }

  Future<void> _removeLikedIntakeLogItem({
    required String username,
    required String logId,
  }) async {
    final log = await SharedPreferenceHelper.getUserMap(
      StorageKeys.likedIntake,
      username,
    );

    final current = (log[_todayKey] is List)
        ? List<Map<String, dynamic>>.from(
      (log[_todayKey] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
      ),
    )
        : <Map<String, dynamic>>[];

    current.removeWhere((e) => (e['logId'] ?? '').toString() == logId);

    log[_todayKey] = current;

    await SharedPreferenceHelper.saveUserMap(
      StorageKeys.likedIntake,
      username,
      log,
    );
  }

  List<_FoodOption> _buildFoodOptions() {
    final options = <_FoodOption>[
      ..._allPosts.map((e) => _FoodOption.post(e)),
      ..._likedRecipeOptions.map((e) => _FoodOption.liked(e)),
    ];

    options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  Future<void> _addConsumedDialog() async {
    final options = _buildFoodOptions();

    if (options.isEmpty) {
      _err('No posts or liked recipes found.');
      return;
    }

    _FoodOption selected = options.first;
    int qty = 1;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add food to today',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<_FoodOption>(
                    value: selected,
                    dropdownColor: AppColors.bgElevated,
                    items: options
                        .map(
                          (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) => setLocal(() => selected = v!),
                    decoration: _fieldDeco('Select dish'),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: qty,
                    dropdownColor: AppColors.bgElevated,
                    items: const [1, 2, 3, 4]
                        .map(
                          (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          'x$e',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) => setLocal(() => qty = v ?? 1),
                    decoration: _fieldDeco('Quantity'),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                    ),
                    onPressed: () async {
                      final username =
                      await SharedPreferenceHelper.currentUsername();
                      if (username == null) return;

                      if (selected.kind == _FoodOptionKind.post) {
                        final dish = selected.post!;
                        await AppDatabase.instance.addIntake(
                          dishId: dish.id!,
                          dateKey: _todayKey,
                          quantity: qty,
                        );
                      } else {
                        final likedRecipe = selected.liked!;
                        await _saveLikedIntakeLogItem(
                          username: username,
                          recipe: likedRecipe,
                          quantity: qty,
                        );
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await _loadAll();
                    },
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _removeConsumedItem(_IntakeItem item) async {
    final username = await SharedPreferenceHelper.currentUsername();
    if (username == null) return;

    if (item.isLikedRecipe) {
      if (item.logId == null) return;
      await _removeLikedIntakeLogItem(
        username: username,
        logId: item.logId!,
      );
    } else {
      await AppDatabase.instance.removeIntake(item.intakeId!);
    }

    await _loadAll();
  }

  InputDecoration _fieldDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.bgSecondary,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accentPrimary),
      ),
    );
  }

  void _err(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final maint = _maintenanceCalories;
    final remaining = maint == null ? null : max(0, maint - _consumedCalories);
    final recWater = _recommendedWaterMl();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Health'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Card(
              title: 'BMI',
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'BMI',
                      value: _bmi == null ? '-' : _bmi!.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      label: 'Category',
                      value: _bmiLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              title: 'Calories',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Maintenance',
                          value: maint?.toString() ?? '-',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Metric(
                          label: 'Consumed today',
                          value: _consumedCalories.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Remaining',
                          value: remaining?.toString() ?? '-',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _activity,
                            dropdownColor: AppColors.bgElevated,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem<String>(
                                value: 'sedentary',
                                child: Text(
                                  'Sedentary',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'light',
                                child: Text(
                                  'Light',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'moderate',
                                child: Text(
                                  'Moderate',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'active',
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) async {
                              if (v == null) return;
                              await _saveActivity(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                      ),
                      onPressed: _addConsumedDialog,
                      child: const Text(
                        'Add food consumed',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _IntakeList(
                    items: _todayIntake,
                    onRemove: _removeConsumedItem,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              title: 'Water',
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: _waterProgress(),
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accentPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Today (ml)',
                          value: '$_todayWaterMl',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Metric(
                          label: 'Recommended',
                          value: '$recWater',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _quickAddMl,
                            dropdownColor: AppColors.bgElevated,
                            isExpanded: true,
                            items: const [150, 250, 350, 500]
                                .map(
                                  (v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  '$v ml',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _quickAddMl = v ?? 250),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPrimary,
                          ),
                          onPressed: () => _addWater(_quickAddMl),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.bgElevated,
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    onPressed: _resetWater,
                    child: const Text(
                      'Reset today',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Profile used: $_name'
                  '${_age == null ? '' : ' • $_age'}'
                  '${_weightKg == null ? '' : ' • ${_weightKg!.toStringAsFixed(1)}kg'}'
                  '${_heightCm == null ? '' : ' • ${_heightCm!.toStringAsFixed(0)}cm'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeItem {
  final int? intakeId;
  final String? logId;
  final String? recipeId;
  final DishEntry entry;
  final int quantity;
  final bool isLikedRecipe;

  _IntakeItem.db({
    required int intakeId,
    required this.entry,
    required this.quantity,
  })  : intakeId = intakeId,
        logId = null,
        recipeId = null,
        isLikedRecipe = false;

  _IntakeItem.liked({
    required String logId,
    required String recipeId,
    required this.entry,
    required this.quantity,
  })  : intakeId = null,
        logId = logId,
        recipeId = recipeId,
        isLikedRecipe = true;
}

class _IntakeList extends StatelessWidget {
  final List<_IntakeItem> items;
  final Future<void> Function(_IntakeItem item) onRemove;

  const _IntakeList({required this.items, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No food added today.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return Column(
      children: items.map((it) {
        final total = it.entry.calories * it.quantity;
        final suffix = it.isLikedRecipe ? ' ❤️' : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${it.entry.name}$suffix',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'x${it.quantity} • $total kcal',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onRemove(it),
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

enum _FoodOptionKind { post, liked }

class _FoodOption {
  final _FoodOptionKind kind;
  final DishEntry? post;
  final _LikedRecipeOption? liked;

  const _FoodOption._({
    required this.kind,
    this.post,
    this.liked,
  });

  factory _FoodOption.post(DishEntry post) {
    return _FoodOption._(
      kind: _FoodOptionKind.post,
      post: post,
    );
  }

  factory _FoodOption.liked(_LikedRecipeOption liked) {
    return _FoodOption._(
      kind: _FoodOptionKind.liked,
      liked: liked,
    );
  }

  String get label {
    if (kind == _FoodOptionKind.post) {
      return post!.name;
    }
    return '${liked!.name} ❤️';
  }
}

class _LikedRecipeOption {
  final String recipeId;
  final String name;
  final String cuisine;
  final int calories;

  const _LikedRecipeOption({
    required this.recipeId,
    required this.name,
    required this.cuisine,
    required this.calories,
  });
}