// frontend/lib/screens/create/create_reply_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Updated Service Imports ---
import '../../services/api/reply_service.dart'; // Use specific ReplyService
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/custom_text_field.dart'; // Assuming path is correct
import '../../widgets/custom_button.dart'; // Assuming path is correct

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

class CreateReplyScreen extends StatefulWidget {
  final int postId;
  final int? parentReplyId; // ID of the reply being replied to (optional)
  final String? postTitle; // For display in AppBar (optional)
  final String? parentReplyContent; // For context (optional)

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

    // Still check if authenticated, ApiClient is needed
    if (!authProvider.isAuthenticated || authProvider.apiClient == null) {
      setState(() {
        _errorMessage = 'Authentication error or configuration issue. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      // <<< FIX: Removed explicit token parameter >>>
      // Assumes ReplyService uses an ApiClient that handles auth
      await replyService.createReply(
        // token: authProvider.token!, // REMOVED
        postId: widget.postId, // Use postId from widget constructor
        content: _contentController.text.trim(),
        parentReplyId: widget.parentReplyId, // Pass parentReplyId if provided
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply posted successfully!'), backgroundColor: ThemeConstants.successColor)
        );
        Navigator.pop(context, true); // Pop back and indicate success
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
    } finally {
      // Ensure loading state is always turned off if mounted
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.parentReplyId != null
        ? 'Reply to Reply'
        : (widget.postTitle != null ? 'Reply to "${widget.postTitle}"' : 'Create Reply');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 1,
      ),
      body: SingleChildScrollView( // Allow scrolling if keyboard appears
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Optionally display the content being replied to for context
              if (widget.parentReplyContent != null)
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

              CustomTextField( // Or TextFormField
                controller: _contentController,
                labelText: 'Your Reply *',
                hintText: 'Write your reply here...',
                maxLines: 6, // Allow ample space for reply content
                minLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Reply content cannot be empty' : null,
                // autofocus: true, // Focus field immediately?
              ),
              const SizedBox(height: 24),

              // Error Message Display
              if (_errorMessage != null)
                Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Text( _errorMessage!, style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14), textAlign: TextAlign.center,),),

              CustomButton( // Or ElevatedButton
                text: 'Post Reply',
                onPressed: _isLoading ? null : _submitReply,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
                //height: 50, // Removed if not a valid parameter for CustomButton
              ),
            ],
          ),
        ),
      ),
    );
  }
}