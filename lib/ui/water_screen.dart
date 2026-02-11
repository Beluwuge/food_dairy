import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:food_dairy/services/database_helper.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  int _ml = 0;

  @override
  void initState() {
    super.initState();
    _loadWater();
  }

  Future<void> _loadWater() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = await DatabaseHelper.instance.getWater(today);
    if (data.isNotEmpty) setState(() => _ml = data.first['ml']);
  }

  Future<void> _updateWater(int newVal) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await DatabaseHelper.instance.setWater(dateIso: today, ml: newVal);
    _loadWater();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Water Intake')),
      body: Column(
        children: [
          Text('Today: $_ml ml', style: const TextStyle(fontSize: 22)),
          Slider(
            min: 0,
            max: 3000,
            value: _ml.toDouble(),
            onChanged: (v) => _updateWater(v.toInt()),
          ),
        ],
      ),
    );
  }
}
