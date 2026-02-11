import 'package:flutter/material.dart';
import 'package:food_diary/models/models.dart';
import 'package:food_diary/services/analytics_service.dart';
import 'package:food_diary/services/db.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();

  UserProfile? _loaded;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await AppDatabase.instance.getProfile();
    if (p != null) {
      _loaded = p;
      _name.text = p.name;
      _age.text = p.age.toString();
      _weight.text = p.weightKg.toStringAsFixed(1);
      _height.text = p.heightCm.toStringAsFixed(1);
    }
    if (mounted) setState(() {});
  }

  double? _calcBmi(UserProfile p) {
    final hM = p.heightCm / 100.0;
    if (hM <= 0) return null;
    return p.weightKg / (hM * hM);
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final age = int.tryParse(_age.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    final height = double.tryParse(_height.text.trim());

    if (name.isEmpty || age == null || weight == null || height == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in valid values.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = UserProfile(name: name, age: age, weightKg: weight, heightCm: height);
      await AppDatabase.instance.upsertProfile(profile);
      await AnalyticsService.instance.event('profile_saved');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _loaded;
    final bmi = p == null ? null : _calcBmi(p);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: _age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age')),
                  TextField(controller: _weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)')),
                  TextField(controller: _height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm)')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BMI Calculator', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (bmi == null)
                    const Text('Save your profile (height & weight) to calculate BMI.')
                  else
                    Text('BMI: ${bmi.toStringAsFixed(1)} (${_bmiCategory(bmi)})'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
