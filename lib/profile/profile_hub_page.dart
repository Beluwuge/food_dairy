import 'dart:io';
import 'package:flutter/material.dart';
import 'package:food_dairy/services/db/app_database.dart';
import 'package:food_dairy/services/db/dish_entry.dart';
import 'package:food_dairy/profile/edit_profile_page.dart';
import 'package:food_dairy/profile/health_dashboard_page.dart';
import 'package:food_dairy/profile/post_detail_page.dart';
import 'package:food_dairy/services/shared_preference_helper.dart';
import 'package:food_dairy/Settings.dart';

class AppColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgSecondary = Color(0xFF121212);
  static const bgElevated = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA8A8A8);
  static const accentPrimary = Color(0xFF0095F6);
  static const divider = Color(0xFF2A2A2E);
}

class StorageKeys {
  static const profile = 'profile'; // {"name":..., "age":..., "weightKg":..., "heightCm":..., "activity": "light"}
}

class ProfileHubPage extends StatefulWidget {
  const ProfileHubPage({super.key});

  @override
  State<ProfileHubPage> createState() => _ProfileHubPageState();
}

class _ProfileHubPageState extends State<ProfileHubPage> {
  bool _loading = true;
  List<DishEntry> _posts = [];

  String _displayName = 'User';
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final profile = await SharedPreferenceHelper.getMap(StorageKeys.profile);
      final posts = await AppDatabase.instance.getAllDishes();

      _displayName = (profile['name']?.toString().trim().isNotEmpty == true)
          ? profile['name'].toString().trim()
          : 'User';

      // Optional: if you have session username saved elsewhere, load it
      // _username = (await SharedPreferenceHelper.getMap('session'))['username'] ?? 'fooddiary';

      _posts = posts;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    _loadAll();
  }

  void _openHealth() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HealthDashboardPage()),
    );
  }

  // ✅ UPDATED: now awaits return value, passes onDelete, refreshes if deleted
  Future<void> _openPost(DishEntry post) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          entry: post,
          onDelete: (e) => AppDatabase.instance.deleteDish(e),
        ),
      ),
    );

    if (deleted == true) {
      await _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsCount = _posts.length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Row(
          children: [
            Text(
              _username.isNotEmpty ? _username : 'Profile',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(), // or SettingsPage()
                ),
              );
            },
          ),
          SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
            : CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.bgElevated,
                          child: Text(
                            _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _Stat(value: '$postsCount', label: 'posts'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PillButton(
                            text: 'Edit profile',
                            onPressed: _openEditProfile,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PillButton(
                            text: 'Health',
                            onPressed: _openHealth,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _TabIcon(active: true, icon: Icons.grid_on),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.divider, height: 1),
                  ],
                ),
              ),
            ),

            if (_posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No posts yet.\nUse the camera tab to add one.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final post = _posts[index];
                      return GestureDetector(
                        onTap: () => _openPost(post),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          color: AppColors.bgElevated,
                          child: Image.file(
                            File(post.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _posts.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _PillButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.bgElevated,
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _IconPillButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.bgElevated,
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 18),
    );
  }
}

class _TabIcon extends StatelessWidget {
  final bool active;
  final IconData icon;
  const _TabIcon({required this.active, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: active ? AppColors.textPrimary : AppColors.textSecondary);
  }
}