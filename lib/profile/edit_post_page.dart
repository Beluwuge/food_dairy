import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  String? _replacementPath;

  @override
  void initState() {
    super.initState();

    _nameCtrl.text = widget.entry.name;
    _descCtrl.text = widget.entry.description;
    _calCtrl.text = widget.entry.calories.toString();
    _cuisineCtrl.text = widget.entry.cuisine;

    _originalPath = widget.entry.imagePath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _calCtrl.dispose();
    _cuisineCtrl.dispose();
    super.dispose();
  }

  Future<void> _evictImageFromFlutterCache(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await FileImage(file).evict();
      }
    } catch (_) {}

    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }

  Future<void> _clearImagePickerCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;

      final entities = tempDir.listSync(recursive: true);

      for (final entity in entities) {
        if (entity is! File) continue;

        final fullPath = entity.path.toLowerCase();
        final fileName = p.basename(fullPath);

        final isLikelyTempImage = fileName.startsWith('cap') ||
            fileName.startsWith('image_picker') ||
            fileName.contains('image_picker') ||
            fullPath.contains('libcachedimagedata') ||
            (fullPath.contains('/cache/') &&
                (fileName.endsWith('.jpg') ||
                    fileName.endsWith('.jpeg') ||
                    fileName.endsWith('.png') ||
                    fileName.endsWith('.webp')));

        if (!isLikelyTempImage) continue;

        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _clearAllImageCaches() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}

    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    await _clearImagePickerCache();
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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

      if (picked == null) {
        await _clearAllImageCaches();
        return;
      }

      final dir = p.dirname(_originalPath);
      final base = p.basename(_originalPath);
      final replacementPath = p.join(
        dir,
        'replacement_${DateTime.now().millisecondsSinceEpoch}_$base',
      );

      if (_replacementPath != null) {
        await _evictImageFromFlutterCache(_replacementPath);
        await _deleteFileIfExists(_replacementPath);
      }

      await File(picked.path).copy(replacementPath);

      try {
        await File(picked.path).delete();
      } catch (_) {}

      await _clearAllImageCaches();

      if (!mounted) return;
      setState(() => _replacementPath = replacementPath);
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

    if (name.isEmpty ||
        desc.isEmpty ||
        cuisine.isEmpty ||
        calories == null ||
        calories < 0) {
      _err('Please fill all fields with valid values.');
      return;
    }

    setState(() => _busy = true);

    try {
      if (_replacementPath != null) {
        await _evictImageFromFlutterCache(_originalPath);
        await _evictImageFromFlutterCache(_replacementPath);

        // Delete original first
        await _deleteFileIfExists(_originalPath);

        // Move replacement into original path
        try {
          await File(_replacementPath!).rename(_originalPath);
        } catch (_) {
          await File(_replacementPath!).copy(_originalPath);
          await _deleteFileIfExists(_replacementPath);
        }

        _replacementPath = null;
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
      await _clearAllImageCaches();
      await _evictImageFromFlutterCache(_originalPath);

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelEdit() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _evictImageFromFlutterCache(_replacementPath);
      await _deleteFileIfExists(_replacementPath);
      _replacementPath = null;

      await _clearAllImageCaches();
    } finally {
      if (mounted) setState(() => _busy = false);
      if (mounted) Navigator.pop(context, false);
    }
  }

  void _err(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Error',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          msg,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewPath = _replacementPath ?? _originalPath;

    return WillPopScope(
      onWillPop: () async {
        await _cancelEdit();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          foregroundColor: AppColors.textPrimary,
          title: const Text('Edit Post'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : _cancelEdit,
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
                      key: ValueKey(previewPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickReplacementImage,
                    icon: const Icon(
                      Icons.camera_alt,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Take New Photo',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      backgroundColor: AppColors.bgElevated,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _field(_nameCtrl, 'Dish Name'),
                const SizedBox(height: 12),
                _field(_descCtrl, 'Description', maxLines: 3),
                const SizedBox(height: 12),
                _field(
                  _calCtrl,
                  'Calories (kcal)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _field(_cuisineCtrl, 'Cuisine'),
                const SizedBox(height: 16),
                if (_busy)
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentPrimary),
        ),
      ),
    );
  }
}