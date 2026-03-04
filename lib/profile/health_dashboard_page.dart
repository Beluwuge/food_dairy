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
  static const profile = 'profile';     // includes weight/height/age
  static const waterLog = 'water_log';  // {"YYYY-MM-DD": intMl}
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

      final posts = await AppDatabase.instance.getDishesByUser(username);

      final intakeRows =
      await AppDatabase.instance.getDailyIntakeRawForUser(
        username: username,
        dateKey: _todayKey,
      );

      _allPosts = posts;

      _todayIntake = intakeRows.map((r) {
        final dish = DishEntry.fromMap(r);
        final qty = (r['quantity'] as num).toInt();
        final intakeId = (r['intake_id'] as num).toInt();
        return _IntakeItem(intakeId: intakeId, entry: dish, quantity: qty);
      }).toList();

      _recompute();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recompute() {
    // BMI
    if (_weightKg != null && _heightCm != null && _weightKg! > 0 && _heightCm! > 0) {
      final hM = _heightCm! / 100.0;
      _bmi = _weightKg! / (hM * hM);
      final v = _bmi!;
      if (v < 18.5) _bmiLabel = 'Underweight';
      else if (v < 25) _bmiLabel = 'Normal';
      else if (v < 30) _bmiLabel = 'Overweight';
      else _bmiLabel = 'Obese';
    } else {
      _bmi = null;
      _bmiLabel = '-';
    }

    // Maintenance calories (front-end only)
    // Simple base estimate: 24*weight then multiply by activity factor.
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

  Future<void> _addConsumedDialog() async {
    if (_allPosts.isEmpty) {
      _err('No posts found. Add a dish with the camera first.');
      return;
    }

    DishEntry selected = _allPosts.first;
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
                  const Text('Add food to today',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<DishEntry>(
                    value: selected,
                    dropdownColor: AppColors.bgElevated,
                    items: _allPosts
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.name, style: const TextStyle(color: AppColors.textPrimary)),
                    ))
                        .toList(),
                    onChanged: (v) => setLocal(() => selected = v!),
                    decoration: _fieldDeco('Select dish'),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: qty,
                    dropdownColor: AppColors.bgElevated,
                    items: const [1, 2, 3, 4]
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text('x$e', style: const TextStyle(color: AppColors.textPrimary)),
                    ))
                        .toList(),
                    onChanged: (v) => setLocal(() => qty = v ?? 1),
                    decoration: _fieldDeco('Quantity'),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                    onPressed: () async {
                      await AppDatabase.instance.addIntake(dishId: selected.id!, dateKey: _todayKey, quantity: qty);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await _loadAll();
                    },
                    child: const Text('Add', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  InputDecoration _fieldDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.bgSecondary,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentPrimary)),
    );
  }

  void _err(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))),
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
                  Expanded(child: _Metric(label: 'BMI', value: _bmi == null ? '-' : _bmi!.toStringAsFixed(1))),
                  const SizedBox(width: 12),
                  Expanded(child: _Metric(label: 'Category', value: _bmiLabel)),
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
                      Expanded(child: _Metric(label: 'Maintenance', value: maint?.toString() ?? '-')),
                      const SizedBox(width: 12),
                      Expanded(child: _Metric(label: 'Consumed today', value: _consumedCalories.toString())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(label: 'Remaining', value: remaining?.toString() ?? '-'),
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
                                child: Text('Sedentary',
                                    style: TextStyle(color: AppColors.textPrimary)),
                              ),
                              DropdownMenuItem<String>(
                                value: 'light',
                                child: Text('Light',
                                    style: TextStyle(color: AppColors.textPrimary)),
                              ),
                              DropdownMenuItem<String>(
                                value: 'moderate',
                                child: Text('Moderate',
                                    style: TextStyle(color: AppColors.textPrimary)),
                              ),
                              DropdownMenuItem<String>(
                                value: 'active',
                                child: Text('Active',
                                    style: TextStyle(color: AppColors.textPrimary)),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                      onPressed: _addConsumedDialog,
                      child: const Text('Add food consumed', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _IntakeList(
                    items: _todayIntake,
                    onRemove: (intakeId) async {
                      await AppDatabase.instance.removeIntake(intakeId);
                      await _loadAll();
                    },
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
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _Metric(label: 'Today (ml)', value: '$_todayWaterMl')),
                      const SizedBox(width: 12),
                      Expanded(child: _Metric(label: 'Recommended', value: '$recWater')),
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
                                .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v ml', style: const TextStyle(color: AppColors.textPrimary)),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() => _quickAddMl = v ?? 250),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                          onPressed: () => _addWater(_quickAddMl),
                          child: const Text('Add', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
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
                    child: const Text('Reset today', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _IntakeItem {
  final int intakeId;
  final DishEntry entry;
  final int quantity;
  _IntakeItem({required this.intakeId, required this.entry, required this.quantity});
}

class _IntakeList extends StatelessWidget {
  final List<_IntakeItem> items;
  final Future<void> Function(int intakeId) onRemove;

  const _IntakeList({required this.items, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No food added today.', style: TextStyle(color: AppColors.textSecondary));
    }

    return Column(
      children: items.map((it) {
        final total = it.entry.calories * it.quantity;
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
                    Text(it.entry.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('x${it.quantity} • $total kcal',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onRemove(it.intakeId),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}