import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// CachedNetworkImage is used in PostHeader and PostContent, not directly here anymore.
// UrlLauncher is used in PostContent.

// Core
import '../../core/theme/theme_constants.dart';
// AppConstants is used in PostHeader (for default avatar).

// Data layer (for API services)
import '../../data/datasources/remote/vote_api.dart'; // Using typedef: VoteApiService
import '../../data/datasources/remote/favorite_api.dart'; // Using typedef: FavoriteApiService
// For models if we passed complex data, but primarily ChatMessageData for MediaItemDisplay
import '../../data/models/chat_message_data.dart' show MediaItemDisplay;

// Presentation layer (Providers and Post Card Parts)
import '../providers/auth_provider.dart';
import 'post_card_parts/post_header.dart';
import 'post_card_parts/post_content.dart';
import 'post_card_parts/post_actions_bar.dart';

// For typedefs from main.dart or a central place
// This ensures VoteService can be correctly typed if it's still named VoteService in its file.
typedef VoteApiService = VoteService;
typedef FavoriteApiService = FavoriteService;

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
  final List<dynamic>? media; // Expecting List<Map<String,dynamic>> from API

  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback onTap; // For tapping the main card content

  const PostCard({
    /* Constructor remains mostly the same */
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
  List<MediaItemDisplay> _parsedMedia = [];

  Timer? _voteDebounce;
  Timer? _favDebounce;

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
            .map((item) =>
                MediaItemDisplay.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
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

  void _debouncedApiCall(
      Timer? timerInstanceVariable, Duration duration, VoidCallback action) {
    // Simplified: Parent component manages _voteDebounce, _favDebounce
    // Or, return the new Timer instance to be assigned.
    // For this method, let's assume it manages them locally if they were fields here.
    // But since they are _PostCardState fields, direct assignment is cleaner.
    if (timerInstanceVariable?.isActive ?? false)
      timerInstanceVariable!.cancel();
    // Create new timer and assign back
    if (timerInstanceVariable == _voteDebounce) {
      _voteDebounce = Timer(duration, action);
    } else if (timerInstanceVariable == _favDebounce) {
      _favDebounce = Timer(duration, action);
    } else {
      // Fallback for direct use, though not intended by design.
      Timer(duration, action);
    }
  }

  Future<void> _handleVote(bool isUpvote) async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Log in to vote.')));
      return;
    }
    final prevUpvotes = upvotes;
    final prevDownvotes = downvotes;
    final prevHasUp = hasUpvoted;
    final prevHasDown = hasDownvoted;
    setState(() {
      _isVoteLoading = true;
      if (isUpvote) {
        if (hasUpvoted) {
          upvotes--;
          hasUpvoted = false;
        } else {
          upvotes++;
          hasUpvoted = true;
          if (hasDownvoted) {
            downvotes--;
            hasDownvoted = false;
          }
        }
      } else {
        if (hasDownvoted) {
          downvotes--;
          hasDownvoted = false;
        } else {
          downvotes++;
          hasDownvoted = true;
          if (hasUpvoted) {
            upvotes--;
            hasUpvoted = false;
          }
        }
      }
    });
    _debouncedApiCall(_voteDebounce, const Duration(milliseconds: 700),
        () async {
      if (!mounted) return;
      _voteDebounce = null;
      final voteService = Provider.of<VoteApiService>(context, listen: false);
      try {
        final response = await voteService.castOrRemoveVote(
          token: authProvider.token!,
          postId: int.parse(widget.postId),
          replyId: null,
          voteType: isUpvote,
        );
        final newCounts = response['new_counts'];
        if (mounted &&
            newCounts is Map &&
            newCounts.containsKey('upvotes') &&
            newCounts.containsKey('downvotes'))
          setState(() {
            upvotes = newCounts['upvotes'] ?? prevUpvotes;
            downvotes = newCounts['downvotes'] ?? prevDownvotes;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            upvotes = prevUpvotes;
            downvotes = prevDownvotes;
            hasUpvoted = prevHasUp;
            hasDownvoted = prevHasDown;
          });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Vote failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: ThemeConstants.errorColor));
      } finally {
        if (mounted) setState(() => _isVoteLoading = false);
      }
    });
  }

  Future<void> _handleFavorite() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Log in to favorite.')));
      return;
    }
    final prevIsFav = isFavorited;
    final prevFavCount = favoriteCount;
    setState(() {
      _isFavoriteLoading = true;
      isFavorited = !isFavorited;
      favoriteCount += isFavorited ? 1 : -1;
      if (favoriteCount < 0) favoriteCount = 0;
    });
    _debouncedApiCall(_favDebounce, const Duration(milliseconds: 700),
        () async {
      if (!mounted) return;
      _favDebounce = null;
      final favoriteService =
          Provider.of<FavoriteApiService>(context, listen: false);
      try {
        final int postIdInt = int.parse(widget.postId);
        Map<String, dynamic> response;
        if (isFavorited)
          response = await favoriteService.addFavorite(
              token: authProvider.token!, postId: postIdInt);
        else
          response = await favoriteService.removeFavorite(
              token: authProvider.token!, postId: postIdInt);
        final newCounts = response['new_counts'];
        if (mounted &&
            newCounts is Map &&
            newCounts.containsKey('favorite_count'))
          setState(() =>
              favoriteCount = newCounts['favorite_count'] ?? prevFavCount);
      } catch (e) {
        if (mounted)
          setState(() {
            isFavorited = prevIsFav;
            favoriteCount = prevFavCount;
          });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Favorite failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: ThemeConstants.errorColor));
      } finally {
        if (mounted) setState(() => _isFavoriteLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: isDark ? 1 : 2,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius)),
      color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostHeader(
                // Use new widget
                postId: widget.postId,
                authorName: widget.authorName,
                authorAvatarUrl: widget.authorAvatarUrl,
                timeAgo: widget.timeAgo,
                communityName: widget.communityName,
                communityColor: widget.communityColor,
                isOwner: widget.isOwner,
                onDelete: widget.onDelete,
              ),
              const SizedBox(height: ThemeConstants.mediumPadding),
              PostContent(
                // Use new widget
                title: widget.title,
                content: widget.content,
                parsedMedia: _parsedMedia,
              ),
              const SizedBox(height: ThemeConstants.mediumPadding),
              Divider(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  height: 1),
              PostActionsBar(
                // Use new widget
                upvotes: upvotes,
                downvotes: downvotes,
                replyCount: widget
                    .initialReplyCount, // Or dynamically update if replies are fetched here
                favoriteCount: favoriteCount,
                hasUpvoted: hasUpvoted,
                hasDownvoted: hasDownvoted,
                isFavorited: isFavorited,
                isVoteLoading: _isVoteLoading,
                isFavoriteLoading: _isFavoriteLoading,
                onUpvote: () => _handleVote(true),
                onDownvote: () => _handleVote(false),
                onReply: widget.onReply,
                onFavorite: _handleFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
