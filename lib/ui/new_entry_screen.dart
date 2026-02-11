import 'dart:io';

import 'package:flutter/material.dart';
import 'package:food_diary/models/models.dart';
import 'package:food_diary/services/analytics_service.dart';
import 'package:food_diary/services/db.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final _commentCtrl = TextEditingController();
  final _picker = ImagePicker();
  XFile? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;
    setState(() => _picked = file);
    await AnalyticsService.instance.event('diary_photo_taken');
  }

  Future<String> _persistToAppDir(XFile xfile) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'diary_images'));
    if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

    final filename = 'meal_${DateTime.now().millisecondsSinceEpoch}${p.extension(xfile.path)}';
    final newPath = p.join(imagesDir.path, filename);

    // Copy to persistent app directory
    final bytes = await xfile.readAsBytes();
    final f = File(newPath);
    await f.writeAsBytes(bytes, flush: true);
    return newPath;
  }

  Future<void> _save() async {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Take a photo first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final persistedPath = await _persistToAppDir(_picked!);
      final entry = DiaryEntry(
        imagePath: persistedPath,
        comment: _commentCtrl.text.trim(),
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await AppDatabase.instance.insertDiaryEntry(entry);
      await AnalyticsService.instance.event('diary_saved');

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      await AnalyticsService.instance.event('diary_save_error', payload: e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _picked != null;

    return Scaffold(
      appBar: AppBar(title: const Text('New Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: SizedBox(
                height: 240,
                width: double.infinity,
                child: hasImage
                    ? Image.file(File(_picked!.path), fit: BoxFit.cover)
                    : const Center(child: Text('No photo yet')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
                hintText: 'e.g., felt hungry, portion size, mood, etc.',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('Save Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
