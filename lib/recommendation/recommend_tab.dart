import 'package:flutter/material.dart';

import '../services/db/app_database.dart';
import '../services/shared_preference_helper.dart';
import 'recommend_service.dart';

class RecommendTab extends StatefulWidget {
  const RecommendTab({super.key});

  @override
  State<RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<RecommendTab> {
  final RecommendService _service = RecommendService();
  final AppDatabase _db = AppDatabase.instance;
  final PageController _pageController = PageController();

  List<RecommendResult> _feed = [];
  bool _loading = true;
  bool _refreshingFeed = false;
  String _username = 'legacy';

  int _currentIndex = 0;

  // New behavior:
  // after a like, do not rerank immediately.
  // wait until user has moved through 3 more posts.
  bool _hasPendingRecommendationRefresh = false;
  int _postsMovedSinceLastLike = 0;

  @override
  void initState() {
    super.initState();
    _loadFeed(initialIndex: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({required int initialIndex}) async {
    if (mounted) {
      setState(() => _loading = true);
    }

    final username = await SharedPreferenceHelper.currentUsername() ?? 'legacy';

    final results = await _service.getRecommendations(
      username: username,
      limit: 25,
    );

    if (!mounted) return;

    setState(() {
      _username = username;
      _feed = results;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients || _feed.isEmpty) return;
      final safeIndex = initialIndex.clamp(0, _feed.length - 1);
      _currentIndex = safeIndex;
      _pageController.jumpToPage(safeIndex);
    });
  }

  Future<void> _toggleLike(RecommendResult result) async {
    final meal = result.meal;
    final recipeId = (meal['idMeal'] ?? '').toString();
    if (recipeId.isEmpty) return;

    final isLiked = await _db.isRecipeLiked(
      username: _username,
      recipeId: recipeId,
    );

    if (isLiked) {
      await _db.unlikeRecipe(
        username: _username,
        recipeId: recipeId,
      );
    } else {
      await _db.likeRecipe(
        username: _username,
        recipeId: recipeId,
        recipeName: (meal['strMeal'] ?? '').toString(),
        cuisine: (meal['strArea'] ?? '').toString(),
        calories: null,
      );
    }

    // Do NOT refresh now.
    // Mark pending, and wait until user has moved 3 posts.
    _hasPendingRecommendationRefresh = true;
    _postsMovedSinceLastLike = 0;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _maybeRefreshRecommendationsAfterScroll(int newIndex) async {
    if (!_hasPendingRecommendationRefresh) return;
    if (_refreshingFeed) return;

    if (newIndex == _currentIndex) return;

    _postsMovedSinceLastLike += 1;
    _currentIndex = newIndex;

    if (_postsMovedSinceLastLike < 3) return;

    _refreshingFeed = true;

    final targetIndex = newIndex;

    await _loadFeed(initialIndex: targetIndex);

    _hasPendingRecommendationRefresh = false;
    _postsMovedSinceLastLike = 0;
    _refreshingFeed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_feed.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text('For You'),
        ),
        body: Center(
          child: TextButton(
            onPressed: () => _loadFeed(initialIndex: 0),
            child: const Text('Reload'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _feed.length,
            onPageChanged: (index) {
              _maybeRefreshRecommendationsAfterScroll(index);
            },
            itemBuilder: (context, index) {
              final item = _feed[index];
              return _RecommendPost(
                key: ValueKey(item.meal['idMeal']),
                result: item,
                username: _username,
                onLike: () => _toggleLike(item),
              );
            },
          ),

          if (_hasPendingRecommendationRefresh)
            Positioned(
              top: 54,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Refreshing in ${3 - _postsMovedSinceLastLike} post(s)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendPost extends StatefulWidget {
  const _RecommendPost({
    super.key,
    required this.result,
    required this.username,
    required this.onLike,
  });

  final RecommendResult result;
  final String username;
  final Future<void> Function() onLike;

  @override
  State<_RecommendPost> createState() => _RecommendPostState();
}

class _RecommendPostState extends State<_RecommendPost> {
  final AppDatabase _db = AppDatabase.instance;

  bool _liked = false;
  bool _loadingLike = true;

  @override
  void initState() {
    super.initState();
    _loadLikedState();
  }

  @override
  void didUpdateWidget(covariant _RecommendPost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = (oldWidget.result.meal['idMeal'] ?? '').toString();
    final newId = (widget.result.meal['idMeal'] ?? '').toString();
    if (oldId != newId || oldWidget.username != widget.username) {
      _loadLikedState();
    }
  }

  Future<void> _loadLikedState() async {
    setState(() => _loadingLike = true);

    final recipeId = (widget.result.meal['idMeal'] ?? '').toString();

    if (recipeId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _liked = false;
        _loadingLike = false;
      });
      return;
    }

    final liked = await _db.isRecipeLiked(
      username: widget.username,
      recipeId: recipeId,
    );

    if (!mounted) return;

    setState(() {
      _liked = liked;
      _loadingLike = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.result.meal;
    final imageUrl = (meal['strMealThumb'] ?? '').toString();
    final title = (meal['strMeal'] ?? 'Unknown Recipe').toString();
    final cuisine = (meal['strArea'] ?? 'Unknown Area').toString();
    final reason = widget.result.reasons.isNotEmpty
        ? widget.result.reasons.first
        : 'Recommended for you';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF121212)),
          )
        else
          Container(color: const Color(0xFF121212)),

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black45,
                Colors.black87,
                Colors.black,
              ],
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'For You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cuisine,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _loadingLike
                              ? null
                              : () async {
                            await widget.onLike();
                            if (!mounted) return;
                            setState(() => _liked = !_liked);
                          },
                          icon: Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            color: _liked ? Colors.redAccent : Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        IconButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.black,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (_) =>
                                  _RecipeInfoSheet(result: widget.result),
                            );
                          },
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecipeInfoSheet extends StatelessWidget {
  const _RecipeInfoSheet({required this.result});

  final RecommendResult result;

  @override
  Widget build(BuildContext context) {
    final meal = result.meal;
    final title = (meal['strMeal'] ?? 'Unknown Recipe').toString();
    final cuisine = (meal['strArea'] ?? 'Unknown Area').toString();
    final instructions = (meal['strInstructions'] ?? '').toString();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  cuisine,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Why this was recommended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.reasons.map(
                      (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $e',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Instructions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  instructions.isEmpty
                      ? 'No instructions provided.'
                      : instructions,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}