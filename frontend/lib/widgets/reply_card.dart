// frontend/lib/widgets/reply_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For avatar

import '../theme/theme_constants.dart';
import '../app_constants.dart'; // For default avatar
import '../services/api/vote_service.dart'; // Import VoteService
import '../services/api/favorite_service.dart'; // Import FavoriteService
import '../services/auth_provider.dart'; // To get token

class ReplyCard extends StatefulWidget {
  // Data passed to the card
  final String replyId; // Use ID for actions
  final String content;
  final String? authorName;
  final String? authorAvatarUrl; // Expecting full URL from service/mapping
  final String? timeAgo;
  final int initialUpvotes;
  final int initialDownvotes;
  final int initialFavoriteCount; // New
  final bool initialHasUpvoted;
  final bool initialHasDownvoted;
  final bool initialIsFavorited; // New
  final bool isOwner;
  final int indentLevel;
  final Color? authorHighlightColor;

  // Callbacks for actions
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const ReplyCard({
    Key? key,
    required this.replyId,
    required this.content,
    this.authorName,
    this.authorAvatarUrl,
    this.timeAgo,
    required this.initialUpvotes,
    required this.initialDownvotes,
    required this.initialFavoriteCount, // New required prop
    required this.initialHasUpvoted,
    required this.initialHasDownvoted,
    required this.initialIsFavorited, // New required prop
    required this.isOwner,
    required this.indentLevel,
    this.authorHighlightColor,
    this.onReply,
    this.onDelete,
  }) : super(key: key);

  @override
  _ReplyCardState createState() => _ReplyCardState();
}

class _ReplyCardState extends State<ReplyCard> {
  // Local state for optimistic UI updates
  late int upvotes;
  late int downvotes;
  late int favoriteCount;
  late bool hasUpvoted;
  late bool hasDownvoted;
  late bool isFavorited;
  bool _isVoteLoading = false;
  bool _isFavoriteLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize local state from widget properties
    upvotes = widget.initialUpvotes;
    downvotes = widget.initialDownvotes;
    favoriteCount = widget.initialFavoriteCount;
    hasUpvoted = widget.initialHasUpvoted;
    hasDownvoted = widget.initialHasDownvoted;
    isFavorited = widget.initialIsFavorited;
  }

  // --- Vote Action ---
  Future<void> _handleVote(bool isUpvote) async {
    if (_isVoteLoading || !mounted) return;

    final voteService = Provider.of<VoteService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to vote.')),
      );
      return;
    }

    setState(() => _isVoteLoading = true);

    // Store previous state for potential rollback
    final previousUpvotes = upvotes;
    final previousDownvotes = downvotes;
    final previousHasUpvoted = hasUpvoted;
    final previousHasDownvoted = hasDownvoted;

    // Optimistic UI update
    setState(() {
      if (isUpvote) {
        if (hasUpvoted) { upvotes--; hasUpvoted = false; }
        else { upvotes++; hasUpvoted = true; if (hasDownvoted) { downvotes--; hasDownvoted = false; } }
      } else {
        if (hasDownvoted) { downvotes--; hasDownvoted = false; }
        else { downvotes++; hasDownvoted = true; if (hasUpvoted) { upvotes--; hasUpvoted = false; } }
      }
    });

    try {
      final response = await voteService.castOrRemoveVote(
        token: authProvider.token!,
        postId: null, // Voting on a reply
        replyId: int.parse(widget.replyId), // Pass reply ID
        voteType: isUpvote,
      );

      // Update counts from backend response for consistency
      final newCounts = response['new_counts'];
      if (mounted && newCounts is Map && newCounts.containsKey('upvotes') && newCounts.containsKey('downvotes')) {
        setState(() {
          upvotes = newCounts['upvotes'] ?? previousUpvotes;
          downvotes = newCounts['downvotes'] ?? previousDownvotes;
        });
      }
      print("Reply vote action successful: ${response['message']}");

    } catch (e) {
      if (mounted) {
        // Rollback optimistic update on error
        setState(() {
          upvotes = previousUpvotes; downvotes = previousDownvotes;
          hasUpvoted = previousHasUpvoted; hasDownvoted = previousHasDownvoted;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Vote failed: ${e.toString().replaceFirst("Exception: ","")}'),
            backgroundColor: ThemeConstants.errorColor));
      }
    } finally {
      if (mounted) {
        setState(() => _isVoteLoading = false);
      }
    }
  }

  // --- Favorite Action ---
  Future<void> _handleFavorite() async {
    if (_isFavoriteLoading || !mounted) return;

    final favoriteService = Provider.of<FavoriteService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to favorite.')),
      );
      return;
    }

    setState(() => _isFavoriteLoading = true);

    final previousIsFavorited = isFavorited;
    final previousFavoriteCount = favoriteCount;

    // Optimistic UI update
    setState(() {
      isFavorited = !isFavorited;
      favoriteCount += isFavorited ? 1 : -1;
      if (favoriteCount < 0) favoriteCount = 0; // Ensure count doesn't go below 0
    });

    try {
      final int replyIdInt = int.parse(widget.replyId);
      Map<String, dynamic> response;
      if (isFavorited) { // If UI is now favorited, call addFavorite
        response = await favoriteService.addFavorite(token: authProvider.token!, replyId: replyIdInt);
      } else { // If UI is now unfavorited, call removeFavorite
        response = await favoriteService.removeFavorite(token: authProvider.token!, replyId: replyIdInt);
      }

      // Update counts from backend response
      final newCounts = response['new_counts'];
      if (mounted && newCounts is Map && newCounts.containsKey('favorite_count')) {
        setState(() {
          favoriteCount = newCounts['favorite_count'] ?? previousFavoriteCount;
        });
      }
      print("Reply favorite action successful: ${response['message']}");

    } catch (e) {
      if (mounted) {
        // Rollback UI on error
        setState(() {
          isFavorited = previousIsFavorited;
          favoriteCount = previousFavoriteCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Favorite action failed: ${e.toString().replaceFirst("Exception: ","")}'),
            backgroundColor: ThemeConstants.errorColor));
      }
    } finally {
      if (mounted) {
        setState(() => _isFavoriteLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double indentPadding = widget.indentLevel * 18.0; // Slightly reduced indent space
    final Color cardBackgroundColor = isDark ? ThemeConstants.backgroundDarker : Colors.white; // Use darker bg for contrast
    final Color borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    // Use state variables for display
    final currentUpvotes = upvotes;
    final currentDownvotes = downvotes;
    final currentFavoriteCount = favoriteCount;
    final currentIsFavorited = isFavorited;
    final currentHasUpvoted = hasUpvoted;
    final currentHasDownvoted = hasDownvoted;

    return Container(
      margin: EdgeInsets.only(left: indentPadding, bottom: 4.0, top: 2.0), // Apply indent margin
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), // Consistent padding inside
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
        // Only add left border for indentation, no full border unless level 0?
        border: widget.indentLevel > 0
            ? Border(left: BorderSide(color: borderColor.withOpacity(0.6), width: 2.0))
            : null,
        // Add shadow only for top-level replies for visual separation
        boxShadow: widget.indentLevel == 0 ? ThemeConstants.softShadow() : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14, // Smaller avatar for replies
                backgroundColor: ThemeConstants.primaryColor.withOpacity(0.3),
                backgroundImage: widget.authorAvatarUrl != null && widget.authorAvatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.authorAvatarUrl!)
                    : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.authorName ?? 'Anonymous',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: widget.authorHighlightColor ?? (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
              if (widget.timeAgo != null)
                Text(
                  widget.timeAgo!,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              if (widget.isOwner && widget.onDelete != null)
                SizedBox( // Constrain IconButton size
                  height: 24, width: 24,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: ThemeConstants.errorColor.withOpacity(0.8),
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete Reply',
                    onPressed: widget.onDelete,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Content
          Padding(
            // Indent content relative to where avatar starts + padding
            padding: EdgeInsets.only(left: 14.0 + 8.0),
            child: Text(
              widget.content,
              style: TextStyle(color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9), height: 1.4, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),

          // Actions row
          Padding(
            padding: const EdgeInsets.only(left: 14.0 + 8.0 - 6.0), // Align actions slightly left of content
            child: Row(
              children: [
                _buildActionButton(
                    icon: currentHasUpvoted ? Icons.arrow_upward_rounded : Icons.arrow_upward_outlined,
                    label: currentUpvotes.toString(),
                    isActive: currentHasUpvoted,
                    activeColor: ThemeConstants.accentColor,
                    isLoading: _isVoteLoading,
                    onPressed: () => _handleVote(true),
                    isDark: isDark
                ),
                const SizedBox(width: 10),
                _buildActionButton(
                    icon: currentHasDownvoted ? Icons.arrow_downward_rounded : Icons.arrow_downward_outlined,
                    label: currentDownvotes.toString(),
                    isActive: currentHasDownvoted,
                    activeColor: ThemeConstants.errorColor,
                    isLoading: _isVoteLoading,
                    onPressed: () => _handleVote(false),
                    isDark: isDark
                ),
                const SizedBox(width: 10),
                _buildActionButton(
                    icon: Icons.reply_rounded,
                    label: 'Reply',
                    isActive: false,
                    onPressed: widget.onReply, // Use direct callback
                    isDark: isDark
                ),
                const SizedBox(width: 10),
                _buildActionButton(
                    icon: currentIsFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: currentFavoriteCount.toString(),
                    isActive: currentIsFavorited,
                    activeColor: Colors.pinkAccent[100], // Softer pink for fav
                    isLoading: _isFavoriteLoading,
                    onPressed: _handleFavorite,
                    isDark: isDark
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Action Button Helper (Same as in PostCard, maybe move to shared utils?)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onPressed, // Make onPressed nullable
    required bool isDark,
    Color? activeColor,
    bool isLoading = false,
  }) {
    final Color inactiveColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color color = isActive ? (activeColor ?? ThemeConstants.accentColor) : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading || onPressed == null ? null : onPressed, // Disable tap if loading or no callback
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
              else
                Icon(icon, size: 16, color: color), // Keep icon size consistent
              const SizedBox(width: 4), // Slightly more space
              Text(
                label,
                style: TextStyle(
                  fontSize: 12, // Keep text size consistent
                  color: color,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}