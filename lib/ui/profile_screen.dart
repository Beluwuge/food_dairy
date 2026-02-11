import 'package:flutter/material.dart';
import 'package:food_dairy/services/database_helper.dart'

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await DatabaseHelper.instance.getProfile();
    if (data.isNotEmpty) {
      final p = data.first;
      _nameCtrl.text = p['name'] ?? '';
      _ageCtrl.text = p['age']?.toString() ?? '';
      _weightCtrl.text = p['weight']?.toString() ?? '';
      _heightCtrl.text = p['height']?.toString() ?? '';
    }
  }

  Future<void> _saveProfile() async {
    await DatabaseHelper.instance.insertOrUpdateProfile(
      name: _nameCtrl.text,
      age: int.tryParse(_ageCtrl.text) ?? 0,
      weight: double.tryParse(_weightCtrl.text) ?? 0,
      height: double.tryParse(_heightCtrl.text) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _ageCtrl, decoration: const InputDecoration(labelText: 'Age')),
            TextField(controller: _weightCtrl, decoration: const InputDecoration(labelText: 'Weight')),
            TextField(controller: _heightCtrl, decoration: const InputDecoration(labelText: 'Height')),
            ElevatedButton(onPressed: _saveProfile, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
