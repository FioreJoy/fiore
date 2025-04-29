// frontend/lib/screens/settings/settings_feature/account/edit_profile.dart

import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Service Imports ---
import '../../../../services/api/auth_service.dart';
import '../../../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text_field.dart';
import '../../../../widgets/location_input_widget.dart'; // Import the new location widget

// --- Theme and Constants ---
import '../../../../theme/theme_constants.dart';
import '../../../../app_constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for editable fields
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _collegeController = TextEditingController();

  // State variables
  String? _selectedGender;
  List<String> _selectedInterests = [];
  File? _pickedImageFile;
  String? _currentImageUrl;
  Map<String, dynamic>? _initialUserData;
  String? _selectedLocationAddress; // Stores human-readable address
  String? _selectedLocationCoords;  // Stores "(lon,lat)" string

  bool _isLoadingData = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _allInterests = [
    'Gaming', 'Tech', 'Music', 'Sports', 'Art', 'Reading', 'Travel', 'Food',
    'Science', 'Movies', 'Coding', 'Other'
  ];
  final List<String> _genders = ['Male', 'Female', 'Other', 'PreferNotSay'];

  @override
  void initState() {
    super.initState();
    _loadInitialUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _collegeController.dispose();
    // Location search controller is inside LocationInputWidget, managed there
    super.dispose();
  }

  Future<void> _loadInitialUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (mounted) {
        setState(() { _isLoadingData = false; _errorMessage = "Not authenticated."; });
      }
      return;
    }

    try {
      final data = await authService.getCurrentUserProfile(authProvider.token!);
      if (!mounted) return;

      setState(() {
        _initialUserData = data;
        _nameController.text = data['name'] ?? '';
        _usernameController.text = data['username'] ?? '';
        _collegeController.text = data['college'] ?? '';
        _selectedGender = data['gender'];
        _currentImageUrl = data['image_url'];
        _selectedInterests = List<String>.from(data['interests'] ?? []);

        // Populate location state from fetched data
        _selectedLocationAddress = data['current_location_address']; // Get the stored address
        _selectedLocationCoords = formatCoords(data['current_location']); // Format coords map/string to string

        _isLoadingData = false;
      });
    } catch (e) {
      print("EditProfileScreen: Error loading user data: $e");
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = "Failed to load profile: ${e.toString().replaceFirst('Exception: ', '')}";
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (pickedFile != null && mounted) {
        setState(() {
          _pickedImageFile = File(pickedFile.path);
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

  Future<void> _saveProfile() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate() || _isLoading || _initialUserData == null) {
      return;
    }

    // Prepare data for update
    final fieldsToUpdate = <String, String>{};

    if (_nameController.text.trim() != (_initialUserData!['name'] ?? '')) {
      fieldsToUpdate['name'] = _nameController.text.trim();
    }
    if (_usernameController.text.trim() != (_initialUserData!['username'] ?? '')) {
      fieldsToUpdate['username'] = _usernameController.text.trim();
    }
    if (_collegeController.text.trim() != (_initialUserData!['college'] ?? '')) {
      fieldsToUpdate['college'] = _collegeController.text.trim();
    }
    if (_selectedGender != (_initialUserData!['gender'])) {
      if (_selectedGender != null) fieldsToUpdate['gender'] = _selectedGender!;
    }

    // Location Update Logic
    final initialCoordsString = formatCoords(_initialUserData!['current_location']);
    final initialAddressString = _initialUserData?['current_location_address'] as String?;

    bool coordsChanged = _selectedLocationCoords != null && _selectedLocationCoords != initialCoordsString;
    // Check if the new address is different from the old one (treat null and empty string as the same for "not set")
    bool addressChanged = (_selectedLocationAddress ?? '') != (initialAddressString ?? '');

    if (coordsChanged || addressChanged) {
      // Always send coordinates if they are set and different or if address changed (to keep coords synced)
      if (_selectedLocationCoords != null) {
        fieldsToUpdate['current_location'] = _selectedLocationCoords!;
      }
      // Send address if it's set, otherwise consider sending empty string or handle null based on backend
      if (_selectedLocationAddress != null && _selectedLocationAddress!.isNotEmpty) {
        fieldsToUpdate['current_location_address'] = _selectedLocationAddress!;
      } else if (initialAddressString != null && initialAddressString.isNotEmpty) {
        // If address was cleared, explicitly send empty string or handle NULL
        fieldsToUpdate['current_location_address'] = ''; // Send empty to clear it in DB
      }
    }

    // Interests Update Logic
    final initialInterestsSet = Set<String>.from(_initialUserData!['interests'] ?? []);
    final currentInterestsSet = Set<String>.from(_selectedInterests);
    if (initialInterestsSet != currentInterestsSet) {
      fieldsToUpdate['interest'] = _selectedInterests.join(','); // Send as comma-separated string
    }

    // Check if anything changed
    if (fieldsToUpdate.isEmpty && _pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() { _errorMessage = "Not authenticated."; _isLoading = false; });
      return;
    }
    print("--- Fields being sent to update profile ---");
    print(fieldsToUpdate);
    print("--- Picked Image File: ${_pickedImageFile?.path} ---");
    try {
      final updatedUserData = await authService.updateUserProfile(
        token: authProvider.token!,
        fieldsToUpdate: fieldsToUpdate,
        image: _pickedImageFile,
      );

      if (mounted) {
        _initialUserData = updatedUserData;
        _currentImageUrl = updatedUserData['image_url'];
        _pickedImageFile = null; // Clear picked image after upload
        _selectedLocationAddress = updatedUserData['current_location_address'];
        _selectedLocationCoords = formatCoords(updatedUserData['current_location']);
        await authProvider.updateUserImageUrl(_currentImageUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: ThemeConstants.successColor),
        );
        Navigator.pop(context, true); // Pop back and signal success
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
          _errorMessage = "An unexpected error occurred saving the profile.";
          _isLoading = false;
        });
        print("EditProfileScreen: Unexpected save error: $e");
      }
    }
  }

  // Helper to format coordinate map/string consistently for comparison/storage
  String formatCoords(dynamic locationData) {
    if (locationData is Map && locationData['longitude'] != null && locationData['latitude'] != null) {
      // Format to a consistent precision if needed
      double lon = (locationData['longitude'] as num).toDouble();
      double lat = (locationData['latitude'] as num).toDouble();
      return '(${lon.toStringAsFixed(6)},${lat.toStringAsFixed(6)})';
    } else if (locationData is String && RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$').hasMatch(locationData)){
      return locationData; // Already in correct format
    }
    return '(0,0)'; // Default format or consider returning null
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _initialUserData == null
          ? _buildErrorView()
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ImageProvider? displayImageProvider;
    if (_pickedImageFile != null) {
      displayImageProvider = FileImage(_pickedImageFile!);
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      displayImageProvider = CachedNetworkImageProvider(_currentImageUrl!);
    } else {
      displayImageProvider = const NetworkImage(AppConstants.defaultAvatar);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: displayImageProvider,
                  ),
                  Material(
                    color: Theme.of(context).primaryColor,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: _pickImage,
                      customBorder: const CircleBorder(),
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
            CustomTextField(
              controller: _nameController,
              labelText: 'Name *',
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _usernameController,
              labelText: 'Username *',
              prefixIcon: const Icon(Icons.alternate_email),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Username cannot be empty' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _collegeController,
              labelText: 'College *',
              prefixIcon: const Icon(Icons.school_outlined),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'College cannot be empty' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              hint: const Text('Select Gender *'),
              decoration: InputDecoration(
                labelText: 'Gender *',
                prefixIcon: const Icon(Icons.wc_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeConstants.borderRadius)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              ),
              items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
              validator: (v) => v == null ? 'Please select a gender' : null,
            ),
            const SizedBox(height: 24), // Increased spacing before location

            // Location Input Widget
            LocationInputWidget(
              initialAddress: _selectedLocationAddress,
              initialCoords: _selectedLocationCoords,
              onLocationSelected: (address, coords) {
                setState(() {
                  _selectedLocationAddress = address;
                  _selectedLocationCoords = coords;
                });
              },
            ),
            const SizedBox(height: 24), // Increased spacing after location

            // Interests Section
            Text('Select Your Interests', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                color: isDark ? ThemeConstants.backgroundDarker.withOpacity(0.5) : Colors.grey.shade100,
              ),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 6.0,
                children: _allInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (bool selected) => setState(() {
                      if (selected) { _selectedInterests.add(interest); }
                      else { _selectedInterests.remove(interest); }
                    }),
                    selectedColor: ThemeConstants.accentColor.withOpacity(0.8),
                    checkmarkColor: ThemeConstants.primaryColor,
                    labelStyle: TextStyle(
                        color: isSelected ? ThemeConstants.primaryColor : null,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: StadiumBorder(side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32), // Increased spacing before button

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

            // Save Button
            CustomButton(
              text: 'Save Changes',
              onPressed: _isLoading ? () {} : _saveProfile,
              isLoading: _isLoading,
              type: ButtonType.primary,
              isFullWidth: true,
            ),
            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: 16),
            Text(
                _errorMessage ?? 'Failed to load profile data.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: _loadInitialUserData,
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}