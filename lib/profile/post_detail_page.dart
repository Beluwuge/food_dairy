import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_dairy/services/db/dish_entry.dart';
import 'package:food_dairy/profile/edit_post_page.dart';

class AppColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgElevated = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA8A8A8);
  static const divider = Color(0xFF2A2A2E);
  static const danger = Color(0xFFFF453A);
}

class PostDetailPage extends StatefulWidget {
  final DishEntry entry;

  /// Recommended: this should delete from sqflite + delete image file + clear cache
  final Future<void> Function(DishEntry entry) onDelete;

  const PostDetailPage({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    if (_deleting) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Delete post?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove the post and delete the saved image from storage.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      // Single source of truth: DB layer handles row + file + cache deletion
      await widget.onDelete(widget.entry);

      if (!mounted) return;
      Navigator.pop(context, true); // signal "deleted" to previous page
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed. Please try again.')),
      );
      setState(() => _deleting = false);
    }
  }

  Future<void> _editPost() async {
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostPage(entry: widget.entry),
      ),
    );

    // If edited, pop and let ProfileHub reload (or return to rebuild detail)
    if (edited == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final isUrlImage = e.imagePath.startsWith('http');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Post'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editPost,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: isUrlImage
                  ? CachedNetworkImage(
                imageUrl: e.imagePath,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: AppColors.textSecondary),
                ),
              )
                  : Image.file(
                File(e.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: AppColors.textSecondary),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgPrimary,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(label: 'Cuisine', value: e.cuisine),
                  _MetaRow(label: 'Calories', value: '${e.calories} kcal'),
                  const SizedBox(height: 10),
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.description,
                    style: const TextStyle(color: AppColors.textPrimary, height: 1.3),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _deleting
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.delete_outline, color: Colors.white),
                      label: Text(
                        _deleting ? 'Deleting…' : 'Delete Post',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: AppColors.danger.withOpacity(0.6),
                      ),
                      onPressed: _deleting ? null : _confirmAndDelete,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}