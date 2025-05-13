// frontend/lib/screens/create/create_reply_screen.dart

import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- Service Imports ---
import '../../services/api/reply_service.dart';
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

class CreateReplyScreen extends StatefulWidget {
  final int postId;
  final int? parentReplyId;
  final String? postTitle; // For display context
  final String? parentReplyContent; // For display context

  const CreateReplyScreen({
    Key? key,
    required this.postId,
    this.parentReplyId,
    this.postTitle,
    this.parentReplyContent,
  }) : super(key: key);

  @override
  _CreateReplyScreenState createState() => _CreateReplyScreenState();
}

class _CreateReplyScreenState extends State<CreateReplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  // --- UPDATED: Store a list of image files ---
  List<File> _pickedImageFiles = [];
  // --- END UPDATE ---

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // --- UPDATED: Pick multiple images ---
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    try {
      final List<XFile> pickedXFiles = await picker.pickMultiImage(imageQuality: 75, maxWidth: 1024);
      if (pickedXFiles.isNotEmpty && mounted) {
        setState(() {
          for (var xfile in pickedXFiles) {
            if (_pickedImageFiles.length < 3) { // Example limit of 3 images for replies
              _pickedImageFiles.add(File(xfile.path));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Maximum 3 images for replies.'), backgroundColor: Colors.orange),
              );
              break;
            }
          }
        });
      }
    } catch (e) {
      print("Image picker error (reply): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error picking images.'), backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- END UPDATE ---

  void _removeImage(int index) {
    if (mounted && index >= 0 && index < _pickedImageFiles.length) {
      setState(() {
        _pickedImageFiles.removeAt(index);
      });
    }
  }

  Future<void> _submitReply() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }
    setState(() => _isLoading = true);

    final replyService = Provider.of<ReplyService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (mounted) setState(() { _errorMessage = 'Authentication error.'; _isLoading = false; });
      return;
    }

    try {
      await replyService.createReply(
        token: authProvider.token!,
        postId: widget.postId,
        content: _contentController.text.trim(),
        parentReplyId: widget.parentReplyId,
        // --- UPDATED: Pass the list of files ---
        images: _pickedImageFiles.isNotEmpty ? _pickedImageFiles : null,
        // --- END UPDATE ---
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply posted successfully!'), backgroundColor: ThemeConstants.successColor)
        );
        Navigator.pop(context, true);
      }
    } on Exception catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Unexpected error posting reply."; _isLoading = false; });
      print("CreateReplyScreen: Unexpected error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String appBarTitle = widget.parentReplyId != null
        ? (widget.parentReplyContent != null && widget.parentReplyContent!.isNotEmpty
        ? 'Reply to Comment'
        : 'Reply to Reply')
        : (widget.postTitle != null && widget.postTitle!.isNotEmpty
        ? 'Reply to "${widget.postTitle}"'
        : 'Create Reply');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, overflow: TextOverflow.ellipsis),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.parentReplyContent != null && widget.parentReplyContent!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                  child: Text(
                    "Replying to: \"${widget.parentReplyContent}\"",
                    style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              CustomTextField(
                controller: _contentController,
                labelText: 'Your Reply *',
                hintText: 'Write your reply here...',
                maxLines: 6, minLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Reply content cannot be empty' : null,
                autofocus: true,
              ),
              const SizedBox(height: 20),

              // --- UPDATED: Image Picker Section for Multiple Images ---
              Text("Attach Images (Optional, max 3)", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_pickedImageFiles.isNotEmpty)
                SizedBox(
                  height: 80, // Smaller preview for replies
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImageFiles.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5),
                              child: Image.file(_pickedImageFiles[index], width: 70, height: 70, fit: BoxFit.cover),
                            ),
                            InkWell(
                              onTap: () => _removeImage(index),
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_pickedImageFiles.isEmpty ? "Add Images" : "Add More", style: const TextStyle(fontSize: 13)),
                onPressed: _pickImages,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Theme.of(context).primaryColor,
                  side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              // --- END UPDATE ---

              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14), textAlign: TextAlign.center),
                ),
              CustomButton(
                text: 'Post Reply',
                onPressed: _isLoading ? () {} : _submitReply,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}