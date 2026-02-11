import 'package:flutter/material.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipes = [
      {'title': 'Oats Bowl', 'desc': 'Oats + milk + fruit'},
      {'title': 'Grilled Chicken', 'desc': 'Chicken + salad'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: ListView.builder(
        itemCount: recipes.length,
        itemBuilder: (ctx, i) {
          final r = recipes[i];
          return ListTile(
            title: Text(r['title']!),
            subtitle: Text(r['desc']!),
          );
        },
      ),
    );
  }
}
