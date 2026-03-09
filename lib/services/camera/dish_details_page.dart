import 'dart:io';
import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../db/dish_entry.dart';
import '../shared_preference_helper.dart'; // ✅ adjust path if your helper is elsewhere

class DishDetailsPage extends StatefulWidget {
  final String imagePath;

  const DishDetailsPage({super.key, required this.imagePath});

  @override
  State<DishDetailsPage> createState() => _DishDetailsPageState();
}

class _DishDetailsPageState extends State<DishDetailsPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();

  bool _saving = false;

  // ✅ important: track whether this captured image became a saved post
  bool _saved = false;

  Future<void> _deleteImageIfNotSaved() async {
    if (_saved) return;

    try {
      final f = File(widget.imagePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    // ✅ if user leaves without saving, delete the captured file
    _deleteImageIfNotSaved();

    _nameCtrl.dispose();
    _descCtrl.dispose();
    _calCtrl.dispose();
    _cuisineCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final cuisine = _cuisineCtrl.text.trim();
    final calories = int.tryParse(_calCtrl.text.trim());

    if (name.isEmpty || desc.isEmpty || cuisine.isEmpty || calories == null || calories < 0) {
      _showError('Please fill all fields with valid values.');
      return;
    }

    setState(() => _saving = true);

    try {
      // ✅ required if DishEntry has username now
      final username = await SharedPreferenceHelper.currentUsername();
      if (username == null || username.trim().isEmpty) {
        _showError('No user session found. Please login again.');
        return;
      }

      final entry = DishEntry(
        id: null,
        username: username, // ✅ required
        imagePath: widget.imagePath,
        name: name,
        description: desc,
        calories: calories,
        cuisine: cuisine,
        createdAt: DateTime.now().toIso8601String(),
      );

      await AppDatabase.instance.insertDish(entry);

      // ✅ mark as saved so we DO NOT delete image on exit
      _saved = true;

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      _showError('Failed to save to database');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ✅ back button -> delete captured file if not saved
      onWillPop: () async {
        await _deleteImageIfNotSaved();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Dish Details')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ Dish Name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dish Name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ✅ Description
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 12),

              // ✅ Calories
              TextField(
                controller: _calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories (kcal)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ✅ Cuisine
              TextField(
                controller: _cuisineCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cuisine (e.g., Japanese, Malay, Western)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}