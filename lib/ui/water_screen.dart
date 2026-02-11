import 'package:flutter/material.dart';
import 'package:food_diary/services/analytics_service.dart';
import 'package:food_diary/services/db.dart';
import 'package:intl/intl.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  int _ml = 0;
  late final String _dateIso;

  @override
  void initState() {
    super.initState();
    _dateIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final log = await AppDatabase.instance.getWaterForDate(_dateIso);
    setState(() => _ml = log.ml);
  }

  Future<void> _set(int ml) async {
    final newMl = ml.clamp(0, 10000);
    setState(() => _ml = newMl);
    await AppDatabase.instance.setWaterForDate(_dateIso, newMl);
    await AnalyticsService.instance.event('water_update', payload: 'date=$_dateIso ml=$newMl');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Today: $_dateIso', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Water intake: $_ml ml', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Slider(
                    value: _ml.toDouble(),
                    min: 0,
                    max: 3000,
                    divisions: 30,
                    label: '$_ml ml',
                    onChanged: (v) => _set(v.round()),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton(onPressed: () => _set(_ml + 250), child: const Text('+250 ml')),
                      OutlinedButton(onPressed: () => _set(_ml + 500), child: const Text('+500 ml')),
                      OutlinedButton(onPressed: () => _set(0), child: const Text('Reset')),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
