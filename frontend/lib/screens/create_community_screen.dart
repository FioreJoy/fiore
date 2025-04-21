import 'dart:io'; // <--- ADDED Import for File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // <--- ADDED Import for ImagePicker
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/theme_constants.dart'; // <--- ADDED Import for ThemeConstants
import '../widgets/custom_button.dart'; // Assuming you have this
import '../widgets/custom_text_field.dart'; // Assuming you have this


class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  _CreateCommunityScreenState createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(); // For "(lon,lat)" input

  bool _isLoading = false;
  String? _selectedInterest; // Stores selected interest string
  File? _logoImage; // Stores the selected logo file

  // List of allowed interests (match backend/database if possible)
  final List<String> _interests = [
    "Gaming", "Tech", "Science", "Music", "Sports",
    "College Event", "Activities", "Social", "Other"
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickLogoImage() async {
    final picker = ImagePicker(); // Instantiate picker
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, // Use ImageSource
        imageQuality: 70 // Optional: compress image
    );
    if (pickedFile != null) {
      setState(() {
        _logoImage = File(pickedFile.path); // Create File object
      });
    }
  }

  void _createCommunity() async { // Removed ApiService/AuthProvider params, get them from context
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final apiService = Provider.of<ApiService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error. Please log in again.')));
        setState(() => _isLoading = false);
        return;
      }

      try {
        String formattedLocation = _locationController.text.trim();
        // Default location if empty, ensure format if not empty
        if (formattedLocation.isEmpty) {
          formattedLocation = '(0,0)';
        } else {
          // Basic validation for location format - improve if needed
          final pattern = r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$';
          if (!RegExp(pattern).hasMatch(formattedLocation)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid location format. Use (longitude,latitude) or leave blank for (0,0)'), backgroundColor: Colors.orange));
            setState(() => _isLoading = false);
            return; // Stop processing
          }
        }


        // Use named parameters for the API call
        await apiService.createCommunity(
          name: _nameController.text,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          primaryLocation: formattedLocation, // Pass the validated/defaulted string
          interest: _selectedInterest ?? "Other", // Send selected interest or default
          logo: _logoImage, // Pass the File object for the logo (can be null)
          token: authProvider.token!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community created successfully!')));
          Navigator.pop(context, true); // Pop with a success indicator
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create community: ${e.toString()}'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }


  // ---- UPDATE build method to include image picker and use theme constants ----
  @override
  Widget build(BuildContext context) {
    // Removed ApiService/AuthProvider from params, get from Provider
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Community'),
        elevation: 1, // Slight elevation
        backgroundColor: isDark ? ThemeConstants.backgroundDarker : Theme.of(context).appBarTheme.backgroundColor, // Use theme color
      ),
      body: SingleChildScrollView( // Wrap with SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- ADD LOGO PICKER ---
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      backgroundImage: _logoImage != null
                          ? FileImage(_logoImage!) // Use FileImage
                          : null, // No default image, just background
                      child: _logoImage == null
                          ? Icon(Icons.group_add, size: 50, color: Colors.grey.shade600)
                          : null,
                    ),
                    Material(
                      // Use ThemeConstants for color
                      color: ThemeConstants.accentColor, // Or Theme.of(context).primaryColor
                      shape: const CircleBorder(),
                      elevation: 2.0,
                      child: InkWell(
                        onTap: _pickLogoImage,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withOpacity(0.3),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.edit, color: Colors.white, size: 20),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // --- END ADD LOGO PICKER ---

              // Use CustomTextField if available and works, otherwise use TextFormField
              CustomTextField( // Or TextFormField
                controller: _nameController,
                labelText: 'Community Name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a community name';
                  }
                  if (value.length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField( // Or TextFormField
                controller: _descriptionController,
                labelText: 'Description (Optional)',
                hintText: 'What is this community about?',
                maxLines: 3,
                // No validator needed for optional field
              ),
              const SizedBox(height: 16),
              // Interest Dropdown
              DropdownButtonFormField<String>(
                value: _selectedInterest,
                hint: const Text('Select Interest Category'),
                // Use decoration consistent with CustomTextField or theme
                decoration: InputDecoration(
                    labelText: 'Interest Category',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0)
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0)
                ),
                items: _interests.map((String interest) {
                  return DropdownMenuItem<String>(
                    value: interest,
                    child: Text(interest),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedInterest = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select an interest' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField( // Or TextFormField
                controller: _locationController,
                labelText: 'Primary Location (Optional)',
                hintText: '(longitude,latitude) e.g., (-74.0060,40.7128)',
                // Add validation for the format if desired
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Basic regex for (number,number) - can be improved
                    final pattern = r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$';
                    if (!RegExp(pattern).hasMatch(value)) {
                      return 'Invalid format. Use (longitude,latitude)';
                    }
                  }
                  return null; // Allow empty
                },
              ),
              const SizedBox(height: 32),
              // Use CustomButton if available, otherwise ElevatedButton
              CustomButton( // Or ElevatedButton
                text: 'Create Community',
                onPressed: _isLoading ? null : _createCommunity, // Disable button when loading
                isLoading: _isLoading,
                type: ButtonType.primary, // Assuming ButtonType exists
              ),
            ],
          ),
        ),
      ),
    );
  }
// --- ADD MISSING CLOSING BRACE for the class ---
}