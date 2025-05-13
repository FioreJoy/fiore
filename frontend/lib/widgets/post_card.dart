// frontend/lib/widgets/post_card.dart
import 'dart:async'; // <-- ADDED IMPORT FOR Timer
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme_constants.dart';
import '../app_constants.dart';
import '../services/api/vote_service.dart';
import '../services/api/favorite_service.dart';
import '../services/auth_provider.dart';
// Use MediaItemDisplay from chat_message_data.dart
import '../models/chat_message_data.dart' show MediaItemDisplay;

class PostCard extends StatefulWidget {
  final String postId;
  final String title;
  final String content;
  final String? authorName;
  final String? authorAvatarUrl;
  final String timeAgo;
  final int initialUpvotes;
  final int initialDownvotes;
  final int initialReplyCount;
  final int initialFavoriteCount;
  final bool initialHasUpvoted;
  final bool initialHasDownvoted;
  final bool initialIsFavorited;
  final bool isOwner;
  final String? communityName;
  final Color? communityColor;
  final List<dynamic>? media; // Expecting List<Map<String,dynamic>>

  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback onTap;

  const PostCard({
    Key? key,
    required this.postId,
    required this.title,
    required this.content,
    this.authorName,
    this.authorAvatarUrl,
    required this.timeAgo,
    required this.initialUpvotes,
    required this.initialDownvotes,
    required this.initialReplyCount,
    required this.initialFavoriteCount,
    required this.initialHasUpvoted,
    required this.initialHasDownvoted,
    required this.initialIsFavorited,
    required this.isOwner,
    this.communityName,
    this.communityColor,
    this.media,
    required this.onReply,
    this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int upvotes;
  late int downvotes;
  late int favoriteCount;
  late bool hasUpvoted;
  late bool hasDownvoted;
  late bool isFavorited;
  bool _isVoteLoading = false;
  bool _isFavoriteLoading = false;
  List<MediaItemDisplay> _parsedMedia = []; // Use MediaItemDisplay

  Timer? _voteDebounce; // Type Timer is now recognized
  Timer? _favDebounce;  // Type Timer is now recognized

  @override
  void initState() {
    super.initState();
    upvotes = widget.initialUpvotes;
    downvotes = widget.initialDownvotes;
    favoriteCount = widget.initialFavoriteCount;
    hasUpvoted = widget.initialHasUpvoted;
    hasDownvoted = widget.initialHasDownvoted;
    isFavorited = widget.initialIsFavorited;

    if (widget.media != null) {
      try {
        _parsedMedia = widget.media!
            .where((item) => item is Map<String, dynamic>)
            .map((item) => MediaItemDisplay.fromJson(item as Map<String, dynamic>)) // Use MediaItemDisplay
            .toList();
      } catch (e) {
        print("Error parsing media in PostCard: $e. Media data: ${widget.media}");
        _parsedMedia = [];
      }
    }
  }

  @override
  void dispose() {
    _voteDebounce?.cancel();
    _favDebounce?.cancel();
    super.dispose();
  }

  void _debouncedApiCall(Timer? existingTimer, Duration duration, VoidCallback action) {
    if (existingTimer?.isActive ?? false) existingTimer!.cancel();
    // Timer is now recognized
    existingTimer = Timer(duration, action);
    // Re-assign the timer to the instance variable if you want to manage it outside.
    // For this pattern, we're just using the passed-in timer reference.
    // If _voteDebounce or _favDebounce should be updated, do:
    // if (existingTimer == _voteDebounce) _voteDebounce = Timer(duration, action); else _favDebounce = Timer(duration, action);
  }


  Future<void> _handleVote(bool isUpvote) async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to vote.')));
      return;
    }

    final previousUpvotes = upvotes; final previousDownvotes = downvotes;
    final previousHasUpvoted = hasUpvoted; final previousHasDownvoted = hasDownvoted;
    setState(() {
      _isVoteLoading = true;
      if (isUpvote) {
        if (hasUpvoted) { upvotes--; hasUpvoted = false; }
        else { upvotes++; hasUpvoted = true; if (hasDownvoted) { downvotes--; hasDownvoted = false; } }
      } else {
        if (hasDownvoted) { downvotes--; hasDownvoted = false; }
        else { downvotes++; hasDownvoted = true; if (hasUpvoted) { upvotes--; hasUpvoted = false; } }
      }
    });

    _debouncedApiCall(_voteDebounce, const Duration(milliseconds: 700), () async {
      _voteDebounce = null; // Clear the timer after execution or cancellation
      if (!mounted) return;
      final voteService = Provider.of<VoteService>(context, listen: false);
      try {
        final response = await voteService.castOrRemoveVote(
          token: authProvider.token!, postId: int.parse(widget.postId), replyId: null, voteType: isUpvote,
        );
        final newCounts = response['new_counts'];
        if (mounted && newCounts is Map && newCounts.containsKey('upvotes') && newCounts.containsKey('downvotes')) {
          setState(() {
            upvotes = newCounts['upvotes'] ?? previousUpvotes;
            downvotes = newCounts['downvotes'] ?? previousDownvotes;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            upvotes = previousUpvotes; downvotes = previousDownvotes;
            hasUpvoted = previousHasUpvoted; hasDownvoted = previousHasDownvoted;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: ThemeConstants.errorColor));
        }
      } finally { if (mounted) setState(() => _isVoteLoading = false); }
    });
  }

  Future<void> _handleFavorite() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to favorite.')));
      return;
    }
    final previousIsFavorited = isFavorited; final previousFavoriteCount = favoriteCount;
    setState(() {
      _isFavoriteLoading = true;
      isFavorited = !isFavorited;
      favoriteCount += isFavorited ? 1 : -1;
      if (favoriteCount < 0) favoriteCount = 0;
    });

    _debouncedApiCall(_favDebounce, const Duration(milliseconds: 700), () async {
      _favDebounce = null; // Clear the timer
      if (!mounted) return;
      final favoriteService = Provider.of<FavoriteService>(context, listen: false);
      try {
        final int postIdInt = int.parse(widget.postId); Map<String, dynamic> response;
        if (isFavorited) { response = await favoriteService.addFavorite(token: authProvider.token!, postId: postIdInt); }
        else { response = await favoriteService.removeFavorite(token: authProvider.token!, postId: postIdInt); }

        final newCounts = response['new_counts'];
        if (mounted && newCounts is Map && newCounts.containsKey('favorite_count')) {
          setState(() => favoriteCount = newCounts['favorite_count'] ?? previousFavoriteCount);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isFavorited = previousIsFavorited;
            favoriteCount = previousFavoriteCount;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Favorite action failed: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: ThemeConstants.errorColor));
        }
      } finally { if (mounted) setState(() => _isFavoriteLoading = false); }
    });
  }

  Widget _buildMediaDisplay(BuildContext context) {
    if (_parsedMedia.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstMediaItem = _parsedMedia.firstWhere(
            (item) => item.url != null && (item.mimeType.startsWith('image/')),
        orElse: () => MediaItemDisplay(
            id: '', mimeType: 'application/octet-stream', createdAt: DateTime.now())
    );

    if (firstMediaItem.url != null && firstMediaItem.mimeType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: ThemeConstants.smallPadding, bottom: ThemeConstants.smallPadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
          child: CachedNetworkImage(
            imageUrl: firstMediaItem.url!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
            ),
          ),
        ),
      );
    } else if (_parsedMedia.isNotEmpty && _parsedMedia.first.url != null) {
      final genericMedia = _parsedMedia.first;
      return Padding(
        padding: const EdgeInsets.only(top: ThemeConstants.smallPadding, bottom: ThemeConstants.smallPadding),
        child: InkWell(
          onTap: () async {
            if (genericMedia.url != null) {
              final uri = Uri.parse(genericMedia.url!);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: ${genericMedia.originalFilename ?? 'attachment'}')));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(ThemeConstants.smallPadding),
            decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800.withOpacity(0.7) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(ThemeConstants.borderRadius)
            ),
            child: Row( children: [
              Icon(Icons.attach_file_rounded, color: Theme.of(context).textTheme.bodySmall?.color),
              const SizedBox(width: 8),
              Expanded(child: Text(genericMedia.originalFilename ?? 'View Attachment', style: Theme.of(context).textTheme.bodyMedium?.copyWith(decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUpvotes = upvotes; final currentDownvotes = downvotes;
    final currentFavoriteCount = favoriteCount; final currentIsFavorited = isFavorited;
    final currentHasUpvoted = hasUpvoted; final currentHasDownvoted = hasDownvoted;

    return Card(
      elevation: isDark ? 1 : 2,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius)),
      color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade300,
                    backgroundImage: widget.authorAvatarUrl != null && widget.authorAvatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(widget.authorAvatarUrl!)
                        : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.authorName ?? 'Anonymous', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text(widget.timeAgo, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  ])),
                  if (widget.communityName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: (widget.communityColor ?? ThemeConstants.highlightColor).withOpacity(isDark ? 0.25 : 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: (widget.communityColor ?? ThemeConstants.highlightColor).withOpacity(0.5), width: 0.8)),
                      child: Text(widget.communityName!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget.communityColor ?? ThemeConstants.highlightColor)),
                    ),
                ],
              ),
              const SizedBox(height: ThemeConstants.mediumPadding),
              Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildMediaDisplay(context),
              Text(widget.content, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800), maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: ThemeConstants.mediumPadding),
              Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      _buildActionButton(context, icon: currentHasUpvoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, label: currentUpvotes.toString(), isActive: currentHasUpvoted, activeColor: ThemeConstants.accentColor, isLoading: _isVoteLoading && currentHasUpvoted, onPressed: () => _handleVote(true)),
                      const SizedBox(width: 10),
                      _buildActionButton(context, icon: currentHasDownvoted ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined, label: currentDownvotes.toString(), isActive: currentHasDownvoted, activeColor: ThemeConstants.errorColor, isLoading: _isVoteLoading && currentHasDownvoted, onPressed: () => _handleVote(false)),
                      const SizedBox(width: 10),
                      _buildActionButton(context, icon: Icons.chat_bubble_outline_rounded, label: widget.initialReplyCount.toString(), isActive: false, onPressed: widget.onReply),
                    ]),
                    Row(children: [
                      _buildActionButton(context, icon: currentIsFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: currentFavoriteCount.toString(), isActive: currentIsFavorited, activeColor: Colors.pinkAccent, isLoading: _isFavoriteLoading, onPressed: _handleFavorite),
                      if (widget.isOwner && widget.onDelete != null)
                        IconButton(icon: const Icon(Icons.delete_sweep_outlined, size: 20), color: Colors.grey.shade500, onPressed: widget.onDelete, tooltip: 'Delete Post', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, { required IconData icon, required String label, required bool isActive, required VoidCallback? onPressed, Color? activeColor, bool isLoading = false, }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color inactiveColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color color = isActive ? (activeColor ?? theme.colorScheme.primary) : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading || onPressed == null ? null : onPressed,
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.8, color: color))
              else Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}