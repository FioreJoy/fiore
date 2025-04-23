// frontend/lib/screens/create/create_post_screen.dart

import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- Updated Service Imports ---
import '../../services/api/post_service.dart'; // Use specific PostService
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/custom_text_field.dart'; // Assuming path is correct
import '../../widgets/custom_button.dart'; // Assuming path is correct

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

class CreatePostScreen extends StatefulWidget {
  // Optional: Pass communityId if creating post directly within a community context
  final int? communityId;
  final String? communityName; // Optional: For display

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

  File? _postImageFile; // Store the selected image file
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
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80); // Slightly higher quality for posts?
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
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    final postService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() {
        _errorMessage = 'Authentication error. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Call the specific service method
      final createdPostData = await postService.createPost(
        token: authProvider.token!,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        communityId: widget.communityId, // Pass communityId if provided
        image: _postImageFile, // Pass the File object
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post "${createdPostData['title']}" created!'), backgroundColor: ThemeConstants.successColor)
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
                maxLines: 8, // Allow more lines for content
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
                child: InkWell( // Make the area tappable
                  onTap: _pickImage,
                  child: _postImageFile == null
                      ? const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.grey))
                      : ClipRRect( // Show preview
                    borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius - 1), // Subtract border width
                    child: Image.file(_postImageFile!, fit: BoxFit.cover, width: double.infinity, height: 150,),
                  ),
                ),
              ),
              if (_postImageFile != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18, color: ThemeConstants.errorColor),
                  label: const Text("Remove Image", style: TextStyle(color: ThemeConstants.errorColor, fontSize: 12)),
                  onPressed: () => setState(() => _postImageFile = null),
                ),
              const SizedBox(height: 24),

              // Error Message Display
              if (_errorMessage != null)
                Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Text( _errorMessage!, style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14), textAlign: TextAlign.center,),),

              CustomButton(
                text: 'Submit Post',
                onPressed: _isLoading ? null : _submitPost,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
                height: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}