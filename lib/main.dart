import 'package:flutter/material.dart';
import 'package:food_dairy/ui/home_screen.dart';
import 'package:food_dairy/services/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const FoodDairyApp());
}

class FoodDairyApp extends StatelessWidget {
  const FoodDairyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Diary',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomeScreen(),
    );
  }
}
