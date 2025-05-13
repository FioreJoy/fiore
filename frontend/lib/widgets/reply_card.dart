// frontend/lib/widgets/reply_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // <-- ADDED IMPORT FOR Timer

import '../theme/theme_constants.dart';
import '../app_constants.dart';
import '../services/api/vote_service.dart';
import '../services/api/favorite_service.dart';
import '../services/auth_provider.dart';
// Use MediaItemDisplay from chat_message_data.dart
import '../models/chat_message_data.dart' show MediaItemDisplay;


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
  final List<dynamic>? media; // Expecting List<Map<String,dynamic>>

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
  List<MediaItemDisplay> _parsedMedia = []; // Use MediaItemDisplay

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
            .map((item) => MediaItemDisplay.fromJson(item as Map<String, dynamic>)) // Use MediaItemDisplay
            .toList();
      } catch (e) {
        print("Error parsing media in ReplyCard: $e. Media data: ${widget.media}");
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
    existingTimer = Timer(duration, action);
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
      _voteDebounce = null;
      if (!mounted) return;
      final voteService = Provider.of<VoteService>(context, listen: false);
      try {
        final response = await voteService.castOrRemoveVote(
          token: authProvider.token!, postId: null, replyId: int.parse(widget.replyId), voteType: isUpvote,
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
      _favDebounce = null;
      if (!mounted) return;
      final favoriteService = Provider.of<FavoriteService>(context, listen: false);
      try {
        final int replyIdInt = int.parse(widget.replyId); Map<String, dynamic> response;
        if (isFavorited) { response = await favoriteService.addFavorite(token: authProvider.token!, replyId: replyIdInt); }
        else { response = await favoriteService.removeFavorite(token: authProvider.token!, replyId: replyIdInt); }
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

  Widget _buildReplyMediaDisplay() {
    if (_parsedMedia.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstMediaItem = _parsedMedia.firstWhere(
            (item) => item.url != null && (item.mimeType.startsWith('image/')),
        orElse: () => MediaItemDisplay(id: '', mimeType: 'application/octet-stream', createdAt: DateTime.now())
    );

    if (firstMediaItem.url != null && firstMediaItem.mimeType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 14.0 + 8.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150, maxWidth: 250),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5),
            child: CachedNetworkImage(
              imageUrl: firstMediaItem.url!, fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5)))),
              errorWidget: (context, url, error) => Container(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30))),
            ),
          ),
        ),
      );
    } else if (_parsedMedia.isNotEmpty && _parsedMedia.first.url != null) {
      final genericMedia = _parsedMedia.first;
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 14.0 + 8.0),
        child: InkWell(
          onTap: () async {
            if (genericMedia.url != null) {
              final uri = Uri.parse(genericMedia.url!);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(color: isDark ? Colors.grey.shade700.withOpacity(0.5) : Colors.grey.shade200, borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5)),
            child: Row( mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.attach_file, size: 16, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
              const SizedBox(width: 6),
              Flexible(child: Text(genericMedia.originalFilename ?? 'Attachment', style: Theme.of(context).textTheme.bodySmall?.copyWith(decoration: TextDecoration.underline, fontSize: 12), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double indentPadding = widget.indentLevel * 18.0;
    final Color cardBackgroundColor = isDark ? ThemeConstants.backgroundDarker : Colors.white;
    final Color borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final currentUpvotes = upvotes; final currentDownvotes = downvotes;
    final currentFavoriteCount = favoriteCount; final currentIsFavorited = isFavorited;
    final currentHasUpvoted = hasUpvoted; final currentHasDownvoted = hasDownvoted;

    return Container(
      margin: EdgeInsets.only(left: indentPadding, bottom: 4.0, top: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
        border: widget.indentLevel > 0 ? Border(left: BorderSide(color: borderColor.withOpacity(0.6), width: 2.0)) : null,
        boxShadow: widget.indentLevel == 0 ? ThemeConstants.softShadow() : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade300,
              backgroundImage: widget.authorAvatarUrl != null && widget.authorAvatarUrl!.isNotEmpty ? CachedNetworkImageProvider(widget.authorAvatarUrl!) : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.authorName ?? 'Anonymous', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.authorHighlightColor ?? (isDark ? Colors.white70 : Colors.black87)))),
            if (widget.timeAgo != null) Text(widget.timeAgo!, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600)),
            if (widget.isOwner && widget.onDelete != null) SizedBox(height: 24, width: 24, child: IconButton(icon: const Icon(Icons.delete_outline, size: 16), color: ThemeConstants.errorColor.withOpacity(0.8), padding: EdgeInsets.zero, tooltip: 'Delete Reply', onPressed: widget.onDelete)),
          ]),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(left: 14.0 + 8.0), child: Text(widget.content, style: TextStyle(color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9), height: 1.4, fontSize: 14))),
          _buildReplyMediaDisplay(),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(left: 14.0 + 8.0 - 6.0), child: Row(children: [
            _buildActionButton(icon: currentHasUpvoted ? Icons.arrow_upward_rounded : Icons.arrow_upward_outlined, label: currentUpvotes.toString(), isActive: currentHasUpvoted, activeColor: ThemeConstants.accentColor, isLoading: _isVoteLoading && currentHasUpvoted, onPressed: () => _handleVote(true), isDark: isDark),
            const SizedBox(width: 10),
            _buildActionButton(icon: currentHasDownvoted ? Icons.arrow_downward_rounded : Icons.arrow_downward_outlined, label: currentDownvotes.toString(), isActive: currentHasDownvoted, activeColor: ThemeConstants.errorColor, isLoading: _isVoteLoading && currentHasDownvoted, onPressed: () => _handleVote(false), isDark: isDark),
            const SizedBox(width: 10),
            if (widget.onReply != null) // Only show reply button if callback is provided
              _buildActionButton(icon: Icons.reply_rounded, label: 'Reply', isActive: false, onPressed: widget.onReply, isDark: isDark),
            if (widget.onReply != null) const SizedBox(width: 10),
            _buildActionButton(icon: currentIsFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: currentFavoriteCount.toString(), isActive: currentIsFavorited, activeColor: Colors.pinkAccent[100], isLoading: _isFavoriteLoading, onPressed: _handleFavorite, isDark: isDark),
          ])),
        ],
      ),
    );
  }

  Widget _buildActionButton({ required IconData icon, required String label, required bool isActive, required VoidCallback? onPressed, required bool isDark, Color? activeColor, bool isLoading = false, }) {
    final Color inactiveColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color color = isActive ? (activeColor ?? ThemeConstants.accentColor) : inactiveColor;
    return Material(color: Colors.transparent, child: InkWell(
        onTap: isLoading || onPressed == null ? null : onPressed, borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 2),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Row(
            mainAxisSize: MainAxisSize.min, children: [
          if (isLoading) SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
          else Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ]))));
  }
}