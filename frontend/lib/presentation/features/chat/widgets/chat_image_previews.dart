import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme_constants.dart';

class ChatImagePreviews extends StatelessWidget {
  final List<File> pickedImageFiles;
  final Function(int) onRemoveImage;

  const ChatImagePreviews({
    Key? key,
    required this.pickedImageFiles,
    required this.onRemoveImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (pickedImageFiles.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 90, // Fixed height for the preview row
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? ThemeConstants.backgroundDark.withOpacity(0.5)
              : Colors.grey.shade100,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerColor, width: 0.5))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pickedImageFiles.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    pickedImageFiles[index],
                    width: 70, // Smaller preview size
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                InkWell(
                  onTap: () => onRemoveImage(index),
                  child: Container(
                    margin: const EdgeInsets.all(
                        2), // Slightly smaller margin for a smaller 'x'
                    padding: const EdgeInsets.all(1), // Smaller padding
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 12), // Smaller icon
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
