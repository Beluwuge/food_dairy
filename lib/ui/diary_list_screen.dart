import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:food_dairy/services/database_helper.dart';
import 'package:food_dairy/ui/new_entry_screen.dart';
import 'package:intl/intl.dart';

class DiaryListScreen extends StatefulWidget {
  const DiaryListScreen({super.key});

  @override
  State<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends State<DiaryListScreen> {
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final data = await DatabaseHelper.instance.getDiaryEntries();
    setState(() => _entries = data);
  }

  Future<void> _deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteDiaryEntry(id);
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diary')),
      body: ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (ctx, i) {
          final e = _entries[i];
          final dt = DateTime.fromMillisecondsSinceEpoch(e['created_at']);
          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(dt);
          final Uint8List bytes = e['image_blob'];

          return Dismissible(
            key: ValueKey(e['id']),
            onDismissed: (_) => _deleteEntry(e['id']),
            background: Container(color: Colors.red),
            child: ListTile(
              leading: Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover),
              title: Text(dateStr),
              subtitle: Text(e['comment'] ?? ''),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewEntryScreen()),
          );
          if (result == true) _loadEntries();
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
