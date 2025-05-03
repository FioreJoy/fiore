// frontend/lib/screens/create/create_post_screen.dart

import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- Service Imports ---
import '../../services/api/post_service.dart';
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

class CreatePostScreen extends StatefulWidget {
  final int? communityId;
  final String? communityName;

  const CreatePostScreen({
    Key? key,
    this.communityId,
    this.communityName,
  }) : super(key: key);

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  File? _postImageFile;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null && mounted) {
        setState(() {
          _postImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Image picker error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error picking image.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    // Clear previous error and ensure form is valid
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    // Set loading state
    setState(() => _isLoading = true);

    final postService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check authentication
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
      final createdPostData = await postService.createPost(
        token: authProvider.token!,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        communityId: widget.communityId,
        image: _postImageFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post "${createdPostData['title']}" created!'), backgroundColor: ThemeConstants.successColor)
        );
        // Pop back and indicate success (true) to the previous screen
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
          _errorMessage = "An unexpected error occurred creating the post.";
          _isLoading = false;
        });
        print("CreatePostScreen: Unexpected error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.communityId != null ? 'Post in ${widget.communityName ?? 'Community'}' : 'Create New Post'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CustomTextField(
                controller: _titleController,
                labelText: 'Post Title *',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _contentController,
                labelText: 'Post Content *',
                maxLines: 8,
                minLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Content is required' : null,
              ),
              const SizedBox(height: 20),

              // Image Picker Section
              Text("Attach Image (Optional)", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                child: InkWell(
                  onTap: _pickImage,
                  child: _postImageFile == null
                      ? Center(child: Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.grey.shade500))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius - 1),
                    child: Image.file(_postImageFile!, fit: BoxFit.cover, width: double.infinity, height: 150),
                  ),
                ),
              ),
              if (_postImageFile != null)
                Align( // Align button to the right or center
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.clear, size: 18, color: ThemeConstants.errorColor),
                    label: const Text("Remove Image", style: TextStyle(color: ThemeConstants.errorColor, fontSize: 12)),
                    onPressed: () => setState(() => _postImageFile = null),
                  ),
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
                text: 'Submit Post',
                // Wrap the async call in a standard VoidCallback
                onPressed: _isLoading ? () {} : () => _submitPost(),
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