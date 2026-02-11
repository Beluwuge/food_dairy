import 'package:flutter/material.dart';
import 'package:food_dairy/models/models.dart';
import 'package:food_dairy/services/analytics_service.dart';
import 'package:food_dairy/services/database_helper.dart';

class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  late Future<List<FoodItem>> _future;

  FoodItem? _selected;
  final _gramsCtrl = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _future = AppDatabase.instance.listFoods();
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    super.dispose();
  }

  int? _calcCalories(FoodItem item) {
    final grams = int.tryParse(_gramsCtrl.text.trim());
    if (grams == null || grams <= 0) return null;
    return ((item.caloriesPer100g * grams) / 100.0).round();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FoodItem>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final foods = snap.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Calories Calculator', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<FoodItem>(
                        value: _selected,
                        items: foods
                            .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text('${f.name} (${f.caloriesPer100g} kcal/100g)'),
                        ))
                            .toList(),
                        onChanged: (v) async {
                          setState(() => _selected = v);
                          if (v != null) {
                            await AnalyticsService.instance.event('food_selected', payload: v.name);
                          }
                        },
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Food'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _gramsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Grams eaten'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Builder(builder: (_) {
                        final sel = _selected;
                        if (sel == null) return const Text('Select a foods.');
                        final cals = _calcCalories(sel);
                        if (cals == null) return const Text('Enter valid grams.');
                        return Text('Estimated calories: $cals kcal');
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  child: ListView.separated(
                    itemCount: foods.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = foods[i];
                      return ListTile(
                        title: Text(f.name),
                        trailing: Text('${f.caloriesPer100g} kcal/100g'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
