// frontend/lib/screens/communities/create_community_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api/community_service.dart';
import '../../services/auth_provider.dart';

import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

import '../../theme/theme_constants.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  _CreateCommunityScreenState createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedInterest;
  File? _logoImageFile;

  final List<String> _interests = [
    "Gaming",
    "Tech",
    "Science",
    "Music",
    "Sports",
    "College Event",
    "Activities",
    "Social",
    "Other",
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickLogoImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _logoImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error picking image.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createCommunity() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate() || _isLoading) return;
    if (_selectedInterest == null) {
      setState(() => _errorMessage = 'Please select an interest.');
      return;
    }

    setState(() => _isLoading = true);

    final communityService = Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() {
        _errorMessage = 'Authentication error. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      String locationToSend = _locationController.text.trim();
      if (locationToSend.isNotEmpty) {
        const pattern = r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$';
        if (!RegExp(pattern).hasMatch(locationToSend)) {
          throw Exception("Invalid location format. Use (longitude,latitude) or leave blank.");
        }
      } else {
        locationToSend = '(0,0)';
      }

      final createdCommunityData = await communityService.createCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        primaryLocation: locationToSend,
        interest: _selectedInterest!,
        logo: _logoImageFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Community "${createdCommunityData['name']}" created!'),
            backgroundColor: ThemeConstants.successColor,
          ),
        );
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
          _errorMessage = "An unexpected error occurred.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Community'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: _pickLogoImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        backgroundImage: _logoImageFile != null
                            ? FileImage(_logoImageFile!)
                            : null,
                        child: _logoImageFile == null
                            ? Icon(
                          Icons.group_add,
                          size: 50,
                          color: Colors.grey.shade500,
                        )
                            : null,
                      ),
                    ),
                    Material(
                      color: Theme.of(context).primaryColor,
                      shape: const CircleBorder(),
                      elevation: 2.0,
                      child: InkWell(
                        onTap: _pickLogoImage,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withOpacity(0.3),
                        child: const Padding(
                          padding: EdgeInsets.all(9.0),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: _nameController,
                labelText: 'Community Name *',
                validator: (v) =>
                (v == null || v.trim().length < 3) ? 'Name too short' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _descriptionController,
                labelText: 'Description (Optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedInterest,
                hint: const Text('Select Interest Category *'),
                decoration: InputDecoration(
                  labelText: 'Interest Category *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                ),
                items: _interests
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedInterest = v),
                validator: (v) => v == null ? 'Please select an interest' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _locationController,
                labelText: 'Primary Location (Optional)',
                hintText: '(longitude,latitude)',
                prefixIcon: const Icon(Icons.location_on_outlined),
                validator: (v) {
                  if (v != null &&
                      v.isNotEmpty &&
                      !RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$')
                          .hasMatch(v)) {
                    return 'Invalid location format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: ThemeConstants.errorColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                text: 'Create Community',
                onPressed: _isLoading ? null : _createCommunity,
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
