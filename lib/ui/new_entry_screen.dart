import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_dairy/services/database_helper.dart';

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  Uint8List? _imageBytes;
  final _textCtrl = TextEditingController();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _saveEntry() async {
    if (_imageBytes == null) return;
    await DatabaseHelper.instance.insertDiaryEntry(
      imageBytes: _imageBytes!,
      comment: _textCtrl.text.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_imageBytes != null)
              Image.memory(_imageBytes!, height: 200),
            ElevatedButton(onPressed: _pickImage, child: const Text('Take Photo')),
            TextField(controller: _textCtrl, decoration: const InputDecoration(labelText: 'Comment')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _saveEntry, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
