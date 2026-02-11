import 'dart:io';

import 'package:flutter/material.dart';
import 'package:food_diary/models/models.dart';
import 'package:food_diary/services/analytics_service.dart';
import 'package:food_diary/services/db.dart';
import 'package:food_diary/ui/diary/new_entry_screen.dart';
import 'package:intl/intl.dart';

class DiaryListScreen extends StatefulWidget {
  const DiaryListScreen({super.key});

  @override
  State<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends State<DiaryListScreen> {
  late Future<List<DiaryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppDatabase.instance.listDiaryEntries();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = AppDatabase.instance.listDiaryEntries();
    });
  }

  Future<void> _addEntry() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewEntryScreen()),
    );
    if (created == true) {
      await AnalyticsService.instance.event('diary_add_success');
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add_a_photo),
      ),
      body: FutureBuilder<List<DiaryEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No entries yet.\nTap the camera button to add one.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = items[i];
                final dt = DateTime.fromMillisecondsSinceEpoch(e.createdAtMillis);
                final dateText = DateFormat('yyyy-MM-dd HH:mm').format(dt);

                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete entry?'),
                        content: const Text('This will remove the diary entry.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                        ],
                      ),
                    ) ??
                        false;
                  },
                  onDismissed: (_) async {
                    if (e.id != null) {
                      await AppDatabase.instance.deleteDiaryEntry(e.id!);
                      await AnalyticsService.instance.event('diary_delete', payload: 'id=${e.id}');
                      await _refresh();
                    }
                  },
                  child: Card(
                    elevation: 1,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          builder: (_) => _EntryDetailSheet(entry: e, dateText: dateText),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(e.imagePath),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 84,
                                  height: 84,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateText, style: Theme.of(context).textTheme.labelLarge),
                                  const SizedBox(height: 6),
                                  Text(
                                    e.comment.isEmpty ? '(No comment)' : e.comment,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Swipe left to delete',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EntryDetailSheet extends StatelessWidget {
  final DiaryEntry entry;
  final String dateText;

  const _EntryDetailSheet({required this.entry, required this.dateText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateText, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(entry.imagePath),
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          Text(entry.comment.isEmpty ? '(No comment)' : entry.comment),
          const SizedBox(height: 10),
          Text(
            'Tip: long-press the image to zoom (optional enhancement).',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
