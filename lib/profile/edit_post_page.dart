import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:food_dairy/services/db/app_database.dart';
import 'package:food_dairy/services/db/dish_entry.dart';

class AppColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgElevated = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA8A8A8);
  static const divider = Color(0xFF2A2A2E);
  static const accentPrimary = Color(0xFF0095F6);
  static const danger = Color(0xFFFF453A);
}

class EditPostPage extends StatefulWidget {
  final DishEntry entry;

  const EditPostPage({super.key, required this.entry});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();

  bool _busy = false;

  late final String _originalPath;
  String? _oldPath;
  String? _newPath;

  @override
  void initState() {
    super.initState();

    _nameCtrl.text = widget.entry.name;
    _descCtrl.text = widget.entry.description;
    _calCtrl.text = widget.entry.calories.toString();
    _cuisineCtrl.text = widget.entry.cuisine;

    _originalPath = widget.entry.imagePath;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareEditFiles();
    });
  }

  Future<void> _prepareEditFiles() async {
    final original = File(_originalPath);
    if (!await original.exists()) return;

    final dir = p.dirname(_originalPath);
    final base = p.basename(_originalPath);
    final oldPath = p.join(dir, 'old_$base');

    final oldFile = File(oldPath);

    if (await oldFile.exists()) {
      if (!mounted) return;
      setState(() => _oldPath = oldPath);
      return;
    }

    try {
      await original.rename(oldPath);
      if (!mounted) return;
      setState(() => _oldPath = oldPath);
    } catch (_) {
      if (!mounted) return;
      setState(() => _oldPath = null);
    }
  }

  Future<void> _pickReplacementImage() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final picker = ImagePicker();

      final XFile? picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (picked == null) return;

      final dir = p.dirname(_originalPath);
      final base = p.basename(_originalPath);

      final newPath = p.join(dir, 'new_$base');

      final existing = File(newPath);
      if (await existing.exists()) {
        await existing.delete();
      }

      await File(picked.path).copy(newPath);

      if (!mounted) return;

      setState(() {
        _newPath = newPath;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final cuisine = _cuisineCtrl.text.trim();
    final calories = int.tryParse(_calCtrl.text.trim());

    if (name.isEmpty || desc.isEmpty || cuisine.isEmpty || calories == null) {
      _err('Please fill all fields.');
      return;
    }

    setState(() => _busy = true);

    try {
      if (_newPath != null) {
        if (_oldPath != null) {
          try {
            await File(_oldPath!).delete();
          } catch (_) {}
        }

        try {
          await File(_newPath!).rename(_originalPath);
        } catch (_) {
          await File(_newPath!).copy(_originalPath);
          await File(_newPath!).delete();
        }
      } else {
        if (_oldPath != null) {
          final oldFile = File(_oldPath!);
          if (await oldFile.exists()) {
            await oldFile.rename(_originalPath);
          }
        }
      }

      final updated = DishEntry(
        id: widget.entry.id,
        username: widget.entry.username,
        imagePath: _originalPath,
        name: name,
        description: desc,
        calories: calories,
        cuisine: cuisine,
        createdAt: widget.entry.createdAt,
      );

      await AppDatabase.instance.updateDish(updated);

      if (!mounted) return;

      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelAndRestore() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      if (_newPath != null) {
        await File(_newPath!).delete();
      }

      if (_oldPath != null) {
        final oldFile = File(_oldPath!);
        if (await oldFile.exists()) {
          await oldFile.rename(_originalPath);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      if (mounted) Navigator.pop(context, false);
    }
  }

  void _err(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text("Error", style: TextStyle(color: AppColors.textPrimary)),
        content: Text(msg, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _calCtrl.dispose();
    _cuisineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewPath = _newPath ?? _oldPath ?? _originalPath;

    return WillPopScope(
      onWillPop: () async {
        await _cancelAndRestore();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          foregroundColor: AppColors.textPrimary,
          title: const Text("Edit Post"),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : _cancelAndRestore,
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : _save,
              child: const Text(
                "Save",
                style: TextStyle(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          ],
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(previewPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Take New Photo"),
                    onPressed: _pickReplacementImage,
                  ),
                ),

                const SizedBox(height: 16),

                _field(_nameCtrl, "Dish Name"),
                const SizedBox(height: 12),

                _field(_descCtrl, "Description", maxLines: 3),
                const SizedBox(height: 12),

                _field(_calCtrl, "Calories", keyboardType: TextInputType.number),
                const SizedBox(height: 12),

                _field(_cuisineCtrl, "Cuisine"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String label, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}