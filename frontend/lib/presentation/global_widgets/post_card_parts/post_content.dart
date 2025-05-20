import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// Core
import '../../../../core/theme/theme_constants.dart';
// Data Layer (using MediaItemDisplay from here)
import '../../../../data/models/chat_message_data.dart' show MediaItemDisplay;


class PostContent extends StatelessWidget {
  final String title;
  final String content;
  final List<MediaItemDisplay> parsedMedia;

  const PostContent({
    Key? key,
    required this.title,
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

  Widget _buildMediaDisplayWidget(BuildContext context) {
    if (parsedMedia.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstImage = parsedMedia.firstWhere(
            (item) => item.url != null && (item.mimeType.startsWith('image/')),
        orElse: () => MediaItemDisplay(id: '', mimeType: '', createdAt: DateTime.now())
    );

    if (firstImage.url != null && firstImage.mimeType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: ThemeConstants.smallPadding, bottom: ThemeConstants.smallPadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
          child: CachedNetworkImage(
            imageUrl: firstImage.url!,
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
    } else if (parsedMedia.isNotEmpty && parsedMedia.first.url != null) {
      final genericMedia = parsedMedia.first;
      return Padding(
        padding: const EdgeInsets.only(top: ThemeConstants.smallPadding, bottom: ThemeConstants.smallPadding),
        child: InkWell(
          onTap: () async {
            if (genericMedia.url != null) {
              final uri = Uri.parse(genericMedia.url!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: ${genericMedia.originalFilename ?? 'attachment'}')));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(ThemeConstants.smallPadding + 2),
            decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800.withOpacity(0.7) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(ThemeConstants.borderRadius)
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file_rounded, color: Theme.of(context).textTheme.bodySmall?.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    genericMedia.originalFilename ?? 'View Attachment',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // --- CORRECTED FIELD NAME HERE ---
                if (genericMedia.fileSizeBytes != null)
                  Text(" (${_formatBytes(genericMedia.fileSizeBytes)})", // Was genericMedia.fileSize
                      style: Theme.of(context).textTheme.bodySmall),
                // --- END CORRECTION ---
              ],
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildMediaDisplayWidget(context),
        Text(
          content,
          style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}