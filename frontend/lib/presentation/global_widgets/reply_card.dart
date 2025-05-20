import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// CachedNetworkImage used in ReplyHeader
// UrlLauncher used in ReplyContentBody

// Core
import '../../core/theme/theme_constants.dart';
// import '../../core/constants/app_constants.dart'; // Used in ReplyHeader for default avatar

// Data Layer (Services and Models)
import '../../data/datasources/remote/vote_api.dart'; // Using typedef: VoteApiService
import '../../data/datasources/remote/favorite_api.dart'; // Using typedef: VoteApiService
import '../../data/models/chat_message_data.dart'
    show MediaItemDisplay; // For media items

// Presentation Layer (Providers and Parts)
import '../providers/auth_provider.dart';
import 'reply_card_parts/reply_header.dart';
import 'reply_card_parts/reply_content_body.dart';
import 'reply_card_parts/reply_actions_bar.dart';

// Typedefs for API services (assuming defined centrally or in main.dart)
typedef VoteApiService = VoteService;
typedef FavoriteApiService = FavoriteService;

class ReplyCard extends StatefulWidget {
  final String replyId;
  final String content;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? timeAgo;
  final int initialUpvotes;
  final int initialDownvotes;
  final int initialFavoriteCount;
  final bool initialHasUpvoted;
  final bool initialHasDownvoted;
  final bool initialIsFavorited;
  final bool isOwner;
  final int indentLevel;
  final Color? authorHighlightColor;
  final List<dynamic>? media;

  final VoidCallback? onReply; // To reply specifically to this reply
  final VoidCallback? onDelete;

  const ReplyCard({
    /* Constructor same as before */
    Key? key,
    required this.replyId,
    required this.content,
    this.authorName,
    this.authorAvatarUrl,
    this.timeAgo,
    required this.initialUpvotes,
    required this.initialDownvotes,
    required this.initialFavoriteCount,
    required this.initialHasUpvoted,
    required this.initialHasDownvoted,
    required this.initialIsFavorited,
    required this.isOwner,
    required this.indentLevel,
    this.media,
    this.authorHighlightColor,
    this.onReply,
    this.onDelete,
  }) : super(key: key);

  @override
  _ReplyCardState createState() => _ReplyCardState();
}

class _ReplyCardState extends State<ReplyCard> {
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
    /* Same as original, for initializing state from widget properties */
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
    if (timerInstanceVariable?.isActive ?? false)
      timerInstanceVariable!.cancel();
    if (timerInstanceVariable == _voteDebounce)
      _voteDebounce = Timer(duration, action);
    else if (timerInstanceVariable == _favDebounce)
      _favDebounce = Timer(duration, action);
    else
      Timer(duration, action);
  }

  Future<void> _handleVote(bool isUpvote) async {
    /* Same as original, but uses service typedef */
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Log in to vote.')));
      return;
    }
    final prevUp = upvotes;
    final prevDown = downvotes;
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
          postId: null,
          replyId: int.parse(widget.replyId),
          voteType: isUpvote,
        );
        final newCounts = response['new_counts'];
        if (mounted &&
            newCounts is Map &&
            newCounts.containsKey('upvotes') &&
            newCounts.containsKey('downvotes'))
          setState(() {
            upvotes = newCounts['upvotes'] ?? prevUp;
            downvotes = newCounts['downvotes'] ?? prevDown;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            upvotes = prevUp;
            downvotes = prevDown;
            hasUpvoted = prevHasUp;
            hasDownvoted = prevHasDown;
          });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Vote fail: ${e.toString().replaceFirst("E: ", "")}'),
            backgroundColor: ThemeConstants.errorColor));
      } finally {
        if (mounted) setState(() => _isVoteLoading = false);
      }
    });
  }

  Future<void> _handleFavorite() async {
    /* Same as original, but uses service typedef */
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Log in to fav.')));
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
        final int replyIdInt = int.parse(widget.replyId);
        Map<String, dynamic> response;
        if (isFavorited)
          response = await favoriteService.addFavorite(
              token: authProvider.token!, replyId: replyIdInt);
        else
          response = await favoriteService.removeFavorite(
              token: authProvider.token!, replyId: replyIdInt);
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
            content: Text('Fav fail: ${e.toString().replaceFirst("E: ", "")}'),
            backgroundColor: ThemeConstants.errorColor));
      } finally {
        if (mounted) setState(() => _isFavoriteLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double indentPadding =
        widget.indentLevel * 18.0; // Or based on ThemeConstants.smallPadding

    return Container(
      margin: EdgeInsets.only(left: indentPadding, bottom: 4.0, top: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
        border: widget.indentLevel > 0
            ? Border(
                left: BorderSide(
                    color:
                        (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                            .withOpacity(0.6),
                    width: 2.0))
            : null,
        boxShadow: widget.indentLevel == 0 ? ThemeConstants.softShadow() : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReplyHeader(
            authorName: widget.authorName,
            authorAvatarUrl: widget.authorAvatarUrl,
            timeAgo: widget.timeAgo,
            authorHighlightColor: widget.authorHighlightColor,
            isOwner: widget.isOwner,
            onDelete: widget.onDelete,
          ),
          const SizedBox(height: 8), // Spacing after header
          ReplyContentBody(
            content: widget.content,
            parsedMedia: _parsedMedia,
          ),
          // SizedBox height between content and actions is handled by actions bar's top padding
          ReplyActionsBar(
            upvotes: upvotes,
            downvotes: downvotes,
            favoriteCount: favoriteCount,
            hasUpvoted: hasUpvoted,
            hasDownvoted: hasDownvoted,
            isFavorited: isFavorited,
            isVoteLoading: _isVoteLoading,
            isFavoriteLoading: _isFavoriteLoading,
            onUpvote: () => _handleVote(true),
            onDownvote: () => _handleVote(false),
            onReplyToThis:
                widget.onReply, // Pass the onReply callback from parent
            onFavorite: _handleFavorite,
          ),
        ],
      ),
    );
  }
}
