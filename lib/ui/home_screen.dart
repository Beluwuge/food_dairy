import 'package:flutter/material.dart';
import 'package:food_dairy/ui/diary_list_screen.dart';
import 'package:food_dairy/ui/water_screen.dart';
import 'package:food_dairy/ui/foods_screen.dart';
import 'package:food_dairy/ui/recipes_screen.dart';
import 'package:food_dairy/ui/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final List<Widget> _pages = const [
    DiaryListScreen(),
    WaterScreen(),
    FoodsScreen(),
    RecipesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book), label: 'Diary'),
          NavigationDestination(icon: Icon(Icons.water_drop), label: 'Water'),
          NavigationDestination(icon: Icon(Icons.food_bank), label: 'Foods'),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
