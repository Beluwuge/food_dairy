import 'package:flutter/material.dart';
import 'package:food_dairy/models/models.dart';
import 'package:food_dairy/services/database_helper.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late Future<List<Recipe>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppDatabase.instance.listRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recipe>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final recipes = snap.data ?? [];

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: recipes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final r = recipes[i];
            return Card(
              child: ListTile(
                title: Text(r.title),
                subtitle: Text(r.description),
              ),
            );
          },
        );
      },
    );
  }
}
