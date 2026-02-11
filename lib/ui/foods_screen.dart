import 'package:flutter/material.dart';

class FoodsScreen extends StatelessWidget {
  const FoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final foods = [
      {'name': 'Apple', 'cal': 52},
      {'name': 'Banana', 'cal': 89},
      {'name': 'Rice', 'cal': 130},
      {'name': 'Chicken', 'cal': 165},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Foods')),
      body: ListView.builder(
        itemCount: foods.length,
        itemBuilder: (ctx, i) {
          final f = foods[i];
          return ListTile(
            title: Text(f['name']!),
            trailing: Text('${f['cal']} kcal'),
          );
        },
      ),
    );
  }
}
