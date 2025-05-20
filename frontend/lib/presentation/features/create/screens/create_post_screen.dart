import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- Data Layer Imports ---
import '../../../../data/datasources/remote/post_api.dart'; // For PostApiService

// --- Presentation Layer Imports ---
import '../../../providers/auth_provider.dart';
import '../../../global_widgets/custom_text_field.dart';
import '../../../global_widgets/custom_button.dart';

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';

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

  List<File> _pickedImageFiles = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    try {
      final List<XFile> pickedXFiles =
          await picker.pickMultiImage(imageQuality: 80, maxWidth: 1080);
      if (pickedXFiles.isNotEmpty && mounted) {
        setState(() {
          for (var xfile in pickedXFiles) {
            if (_pickedImageFiles.length < 5) {
              _pickedImageFiles.add(File(xfile.path));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Maximum 5 images allowed.'),
                  backgroundColor: Colors.orange));
              break;
            }
          }
        });
      }
    } catch (e) {
      // print("Image picker error: $e"); // Debug print removed
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error picking images.'),
            backgroundColor: Colors.red));
    }
  }

  void _removeImage(int index) {
    if (mounted && index >= 0 && index < _pickedImageFiles.length) {
      setState(() => _pickedImageFiles.removeAt(index));
    }
  }

  Future<void> _submitPost() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    final postService = Provider.of<PostService>(context,
        listen: false); // Use typedef or actual class name
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (mounted)
        setState(() {
          _errorMessage = 'Authentication error.';
          _isLoading = false;
        });
      return;
    }

    try {
      final createdPostData = await postService.createPost(
        token: authProvider.token!,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        communityId: widget.communityId,
        images: _pickedImageFiles.isNotEmpty ? _pickedImageFiles : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Post "${createdPostData['title']}" created!'),
            backgroundColor: ThemeConstants.successColor));
        Navigator.pop(context, true);
      }
    } on Exception catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = "Unexpected error creating post.";
          _isLoading = false;
        });
      // print("CreatePostScreen: Unexpected error: $e"); // Debug print removed
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.communityId != null
              ? 'Post in ${widget.communityName ?? 'Community'}'
              : 'Create New Post'),
          elevation: 1),
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _contentController,
                labelText: 'Post Content *',
                maxLines: 8,
                minLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Content is required'
                    : null,
              ),
              const SizedBox(height: 20),
              Text("Attach Images (Optional, max 5)",
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_pickedImageFiles.isNotEmpty)
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImageFiles.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                                ThemeConstants.borderRadius),
                            child: Image.file(
                              _pickedImageFiles[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_pickedImageFiles.isEmpty
                    ? "Add Images"
                    : "Add More Images"),
                onPressed: _pickImages,
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white70 : Theme.of(context).primaryColor,
                  side: BorderSide(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: ThemeConstants.errorColor, fontSize: 14),
                      textAlign: TextAlign.center),
                ),
              CustomButton(
                text: 'Submit Post',
                onPressed: _isLoading ? () {} : _submitPost,
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
