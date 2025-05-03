// frontend/lib/screens/create/create_reply_screen.dart

import 'package:flutter/material.dart';
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
  // Use int type consistent with backend/models
  final int postId;
  final int? parentReplyId;
  final String? postTitle;
  final String? parentReplyContent;

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

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication error. Please log in again.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Call the API service method
      await replyService.createReply(
        token: authProvider.token!,
        postId: widget.postId,
        content: _contentController.text.trim(),
        parentReplyId: widget.parentReplyId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply posted successfully!'), backgroundColor: ThemeConstants.successColor)
        );
        // Pop back and indicate success (true)
        Navigator.pop(context, true);
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred posting the reply.";
          _isLoading = false;
        });
        print("CreateReplyScreen: Unexpected error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.parentReplyId != null
        ? 'Reply to Reply'
        : (widget.postTitle != null && widget.postTitle!.isNotEmpty
        ? 'Reply to "${widget.postTitle}"'
        : 'Create Reply'); // Handle potentially empty post title

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Display content being replied to (if available)
              if (widget.parentReplyContent != null && widget.parentReplyContent!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                  ),
                  child: Text(
                    "Replying to: \"${widget.parentReplyContent}\"",
                    style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Reply input field
              CustomTextField(
                controller: _contentController,
                labelText: 'Your Reply *',
                hintText: 'Write your reply here...',
                maxLines: 6,
                minLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Reply content cannot be empty' : null,
                autofocus: true, // Focus field immediately
              ),
              const SizedBox(height: 24),

              // Error Message Display
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Submit Button
              CustomButton(
                text: 'Post Reply',
                // Wrap the async call in a standard VoidCallback
                onPressed: _isLoading ? () {} : () => _submitReply(),
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
                // Removed height parameter
              ),
            ],
          ),
        ),
      ),
    );
  }
}