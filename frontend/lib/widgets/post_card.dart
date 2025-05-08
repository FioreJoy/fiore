// frontend/lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // To access services
import 'package:cached_network_image/cached_network_image.dart'; // For images

import '../theme/theme_constants.dart';
import '../app_constants.dart'; // For default avatar or base URL if needed
import '../services/api/vote_service.dart'; // Import VoteService
import '../services/api/favorite_service.dart'; // Import FavoriteService
import '../services/auth_provider.dart'; // To get token

class PostCard extends StatefulWidget {
  // Data passed to the card
  final String postId; // Use ID for actions
  final String title;
  final String content;
  final String? authorName;
  final String? authorAvatarUrl; // Expecting full URL from service/mapping
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

  // Callbacks for actions
  final VoidCallback onReply;
  final VoidCallback? onDelete; // Nullable if not owner
  final VoidCallback onTap; // Action when tapping the card body

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
    required this.onReply,
    this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
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
        if (hasUpvoted) { // Undoing upvote
          upvotes--; hasUpvoted = false;
        } else { // Casting upvote (or switching from downvote)
          upvotes++; hasUpvoted = true;
          if (hasDownvoted) { downvotes--; hasDownvoted = false; }
        }
      } else { // Downvoting
        if (hasDownvoted) { // Undoing downvote
          downvotes--; hasDownvoted = false;
        } else { // Casting downvote (or switching from upvote)
          downvotes++; hasDownvoted = true;
          if (hasUpvoted) { upvotes--; hasUpvoted = false; }
        }
      }
    });

    try {
      final response = await voteService.castOrRemoveVote(
        token: authProvider.token!,
        postId: int.parse(widget.postId), // Pass post ID
        replyId: null,
        voteType: isUpvote, // Pass the action type
      );

      // Update counts from backend response for consistency (optional but good)
      final newCounts = response['new_counts'];
      if (mounted && newCounts is Map && newCounts.containsKey('upvotes') && newCounts.containsKey('downvotes')) {
        setState(() {
          upvotes = newCounts['upvotes'] ?? previousUpvotes;
          downvotes = newCounts['downvotes'] ?? previousDownvotes;
          // Vote status is already optimistically updated, backend action determines final state
        });
      }
      print("Post vote action successful: ${response['message']}");

    } catch (e) {
      if (mounted) {
        // Rollback optimistic update on error
        setState(() {
          upvotes = previousUpvotes;
          downvotes = previousDownvotes;
          hasUpvoted = previousHasUpvoted;
          hasDownvoted = previousHasDownvoted;
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
    });

    try {
      final int postIdInt = int.parse(widget.postId);
      Map<String, dynamic> response;
      if (isFavorited) { // If UI is now favorited, call addFavorite
        response = await favoriteService.addFavorite(token: authProvider.token!, postId: postIdInt);
      } else { // If UI is now unfavorited, call removeFavorite
        response = await favoriteService.removeFavorite(token: authProvider.token!, postId: postIdInt);
      }

      // Update counts from backend response
      final newCounts = response['new_counts'];
      if (mounted && newCounts is Map && newCounts.containsKey('favorite_count')) {
        setState(() {
          favoriteCount = newCounts['favorite_count'] ?? previousFavoriteCount;
          // Favorite status is already optimistically updated
        });
      }
      print("Post favorite action successful: ${response['message']}");

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Use the state variables for display
    final currentUpvotes = upvotes;
    final currentDownvotes = downvotes;
    final currentFavoriteCount = favoriteCount;
    final currentIsFavorited = isFavorited;
    final currentHasUpvoted = hasUpvoted;
    final currentHasDownvoted = hasDownvoted;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding), // Add margin between cards
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
      ),
      child: InkWell(
        onTap: widget.onTap, // Use onTap passed from parent
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Row (Keep existing structure) ---
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: ThemeConstants.primaryColor.withOpacity(0.5),
                    backgroundImage: widget.authorAvatarUrl != null
                        ? CachedNetworkImageProvider(widget.authorAvatarUrl!) // Use CachedNetworkImage for network URLs
                        : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.authorName ?? 'Anonymous',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                        Text(
                          widget.timeAgo,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (widget.communityName != null)
                    Container( /* ... community chip (keep as is) ... */
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (widget.communityColor ?? ThemeConstants.highlightColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: (widget.communityColor ?? ThemeConstants.highlightColor).withOpacity(0.5), width: 1),
                      ),
                      child: Text(
                        widget.communityName!,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.communityColor ?? ThemeConstants.highlightColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: ThemeConstants.mediumPadding),

              // --- Title & Content (Keep existing structure) ---
              Text(
                widget.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                widget.content,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
                maxLines: 4, // Adjust max lines as needed
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: ThemeConstants.mediumPadding),

              // --- Action Row (Updated) ---
              Row(
                children: [
                  // Upvote Button
                  _buildActionButton(
                      icon: currentHasUpvoted ? Icons.arrow_upward_rounded : Icons.arrow_upward_outlined,
                      label: currentUpvotes.toString(),
                      isActive: currentHasUpvoted,
                      activeColor: ThemeConstants.accentColor, // Use accent for upvote
                      isLoading: _isVoteLoading, // Pass loading state
                      onPressed: () => _handleVote(true), // Pass true for upvote
                      isDark: isDark
                  ),
                  const SizedBox(width: 12),
                  // Downvote Button
                  _buildActionButton(
                      icon: currentHasDownvoted ? Icons.arrow_downward_rounded : Icons.arrow_downward_outlined,
                      label: currentDownvotes.toString(),
                      isActive: currentHasDownvoted,
                      activeColor: ThemeConstants.errorColor, // Use error for downvote
                      isLoading: _isVoteLoading, // Pass loading state
                      onPressed: () => _handleVote(false), // Pass false for downvote
                      isDark: isDark
                  ),
                  const SizedBox(width: 12),
                  // Reply Button
                  _buildActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: widget.initialReplyCount.toString(), // Use initial count directly
                      isActive: false, // Reply button isn't 'active' in the same way as vote/fav
                      onPressed: widget.onReply, // Use callback from parent
                      isDark: isDark
                  ),
                  const SizedBox(width: 12),
                  // Favorite Button
                  _buildActionButton(
                      icon: currentIsFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: currentFavoriteCount.toString(),
                      isActive: currentIsFavorited,
                      activeColor: Colors.pinkAccent, // Use a distinct color for favorite
                      isLoading: _isFavoriteLoading, // Pass loading state
                      onPressed: _handleFavorite, // Use favorite handler
                      isDark: isDark
                  ),

                  const Spacer(), // Pushes delete button to the end

                  // Delete Button (conditional)
                  if (widget.isOwner && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.grey.shade600, // Subtle color
                      onPressed: widget.onDelete,
                      tooltip: 'Delete Post',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Updated Action Button Helper
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required bool isDark,
    Color? activeColor, // Color when active (vote/favorite)
    bool isLoading = false, // Added loading state
  }) {
    final Color inactiveColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color color = isActive ? (activeColor ?? ThemeConstants.accentColor) : inactiveColor;

    return Material( // Use Material for InkWell effect
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed, // Disable tap when loading
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Slightly more padding
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
              else
                Icon(icon, size: 18, color: color), // Slightly larger icon
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13, // Slightly larger text
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