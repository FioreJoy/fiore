import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// Core
import '../../../../core/theme/theme_constants.dart';
// Data Layer (using MediaItemDisplay from here)
import '../../../../data/models/chat_message_data.dart' show MediaItemDisplay;


class ReplyContentBody extends StatelessWidget {
  final String content;
  final List<MediaItemDisplay> parsedMedia;

  const ReplyContentBody({
    Key? key,
    required this.content,
    required this.parsedMedia,
  }) : super(key: key);

  String _formatBytes(int? bytes, {int decimals = 1}) {
    if (bytes == null || bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Widget _buildReplyMediaDisplayWidget(BuildContext context) {
    if (parsedMedia.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstImage = parsedMedia.firstWhere(
            (item) => item.url != null && (item.mimeType.startsWith('image/')),
        orElse: () => MediaItemDisplay(id: '', mimeType: '', createdAt: DateTime.now())
    );

    if (firstImage.url != null && firstImage.mimeType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150, maxWidth: 250),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5),
            child: CachedNetworkImage(
              imageUrl: firstImage.url!, fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5)))),
              errorWidget: (context, url, error) => Container(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30))),
            ),
          ),
        ),
      );
    } else if (parsedMedia.isNotEmpty && parsedMedia.first.url != null) {
      final genericMedia = parsedMedia.first;
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: InkWell(
          onTap: () async { if (genericMedia.url != null) { final uri = Uri.parse(genericMedia.url!); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }},
          child: Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(color: isDark ? Colors.grey.shade700.withOpacity(0.5) : Colors.grey.shade200, borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5)),
            child: Row( mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.attach_file, size: 16, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
              const SizedBox(width: 6),
              Flexible(child: Text(genericMedia.originalFilename ?? 'Attachment', style: Theme.of(context).textTheme.bodySmall?.copyWith(decoration: TextDecoration.underline, fontSize: 12), overflow: TextOverflow.ellipsis,)),
              // --- CORRECTED FIELD NAME HERE ---
              if (genericMedia.fileSizeBytes != null)
                Text(" (${_formatBytes(genericMedia.fileSizeBytes)})", // Was genericMedia.fileSize
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
              // --- END CORRECTION ---
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14.0 + 8.0),
          child: Text( content, style: TextStyle(color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9), height: 1.4, fontSize: 14),),
        ),
        if (parsedMedia.isNotEmpty)
          _buildReplyMediaDisplayWidget(context),
      ],
    );
  }
}