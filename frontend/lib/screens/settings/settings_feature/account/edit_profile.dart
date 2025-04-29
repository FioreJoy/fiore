import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Updated Service Imports ---
import '../../../../services/api/auth_service.dart'; // Use specific AuthService
import '../../../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text_field.dart';

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
  final _locationController = TextEditingController(); // Assuming location is editable "(lon,lat)"
  String? _selectedGender;
  List<String> _selectedInterests = []; // Example: Manage interests if editable

  File? _pickedImageFile; // Store the selected image file for upload
  String? _currentImageUrl; // Store the current image URL for display
  Map<String, dynamic>? _initialUserData; // Store initial data to compare changes

  bool _isLoadingData = true; // Loading state for initial fetch
  bool _isSaving = false; // Loading state for saving profile
  String? _errorMessage; // To display errors

  // Example interest options (should ideally be consistent across app)
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
    _locationController.dispose();
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
      setState(() { _isLoadingData = false; _errorMessage = "Not authenticated."; });
      return;
    }

    try {
      final data = await authService.getCurrentUserProfile();
      if (!mounted) return;

      setState(() {
        _initialUserData = data; // Store initial data
        // Populate controllers and state variables
        _nameController.text = data['name'] ?? '';
        _usernameController.text = data['username'] ?? '';
        _collegeController.text = data['college'] ?? '';
        _selectedGender = data['gender'];
        _currentImageUrl = data['image_url']; // Store current image URL
        // Format location map back to string for editing, or handle differently
        final locationMap = data['current_location'];
        if (locationMap is Map && locationMap['longitude'] != null && locationMap['latitude'] != null) {
          _locationController.text = '(${locationMap['longitude']}, ${locationMap['latitude']})';
        } else {
          _locationController.text = ''; // Or default value like '(0,0)'
        }
        _selectedInterests = List<String>.from(data['interests'] ?? []);

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
          _pickedImageFile = File(pickedFile.path); // Store File object
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
    setState(() => _errorMessage = null); // Clear error

    if (!_formKey.currentState!.validate() || _isSaving || _initialUserData == null) {
      return;
    }

    // --- Prepare data for update ---
    final fieldsToUpdate = <String, String>{};
    // Only include fields that have actually changed
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
    // Format location back if changed
    final initialLocationString = formatLocation(_initialUserData!['current_location']);
    final currentLocationString = _locationController.text.trim();
    if (currentLocationString.isNotEmpty && currentLocationString != initialLocationString) {
      // Validate format before adding
      final pattern = r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$';
      if (!RegExp(pattern).hasMatch(currentLocationString)) {
        setState(() => _errorMessage = "Invalid location format. Use (lon,lat).");
        return;
      }
      fieldsToUpdate['current_location'] = currentLocationString;
    }
    // Compare interest lists (convert to sets for easy comparison)
    final initialInterestsSet = Set<String>.from(_initialUserData!['interests'] ?? []);
    final currentInterestsSet = Set<String>.from(_selectedInterests);
    if (initialInterestsSet != currentInterestsSet) {
      fieldsToUpdate['interests'] = _selectedInterests.join(','); // Send as comma-separated string
    }

    // Check if anything changed (text fields or image)
    if (fieldsToUpdate.isEmpty && _pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected.'), duration: Duration(seconds: 2)),
      );
      return; // No changes to save
    }
    // --- End Prepare data ---

    setState(() => _isSaving = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() { _errorMessage = "Not authenticated."; _isSaving = false; });
      return;
    }

    try {
      final updatedUserData = await authService.updateUserProfile(
        fieldsToUpdate: fieldsToUpdate,
        image: _pickedImageFile, // Pass selected File or null
      );

      if (mounted) {
        // Update local state and AuthProvider with new data
        _initialUserData = updatedUserData; // Store new data as initial for next edit
        _currentImageUrl = updatedUserData['image_url']; // Update displayed image URL
        _pickedImageFile = null; // Clear picked image after successful upload
        await authProvider.updateUserImageUrl(_currentImageUrl); // Update image in AuthProvider

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: ThemeConstants.successColor),
        );
        Navigator.pop(context); // Optionally pop back after saving
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred saving the profile.";
          _isSaving = false;
        });
        print("EditProfileScreen: Unexpected save error: $e");
      }
    }
  }

  // Reusing formatter from ProfileScreen - consider moving to a utils file
  String formatLocation(dynamic locationData) {
    if (locationData is Map) {
      final lon = locationData['longitude']; final lat = locationData['latitude'];
      if (lon is num && lat is num) return '(${lon.toStringAsFixed(4)}, ${lat.toStringAsFixed(4)})';
    } else if (locationData is String && locationData.isNotEmpty) return locationData;
    return ''; // Return empty string instead of N/A for editing
  }

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _initialUserData == null // Show error only if initial load failed
          ? _buildErrorView()
          : _buildForm(), // Build the form once initial data is loaded or if load failed but we allow editing anyway
    );
  }

  Widget _buildForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Determine image provider based on picked file or current URL
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
            // Profile Picture
            Center( child: Stack( alignment: Alignment.bottomRight, children: [
              CircleAvatar( radius: 60, backgroundColor: Colors.grey.shade300, backgroundImage: displayImageProvider,),
              Material( color: Theme.of(context).primaryColor, shape: const CircleBorder(), elevation: 2, child: InkWell( onTap: _pickImage, customBorder: const CircleBorder(), child: const Padding( padding: EdgeInsets.all(8.0), child: Icon(Icons.edit, color: Colors.white, size: 20),),),)
            ],),),
            const SizedBox(height: 24),

            // Form Fields
            CustomTextField( controller: _nameController, labelText: 'Name', validator: (v) => v!.isEmpty ? 'Required' : null,),
            const SizedBox(height: 16),
            CustomTextField( controller: _usernameController, labelText: 'Username', validator: (v) => v!.isEmpty ? 'Required' : null,),
            const SizedBox(height: 16),
            CustomTextField( controller: _collegeController, labelText: 'College', validator: (v) => v!.isEmpty ? 'Required' : null,),
            const SizedBox(height: 16),
            // Gender Dropdown
            DropdownButtonFormField<String>(
              value: _selectedGender, hint: const Text('Select Gender'),
              decoration: InputDecoration( labelText: 'Gender', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
              items: _genders.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _selectedGender = val),
            ),
            const SizedBox(height: 16),
            // Interests (checkboxes/multiselect)
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _allInterests.map((interest) => ChoiceChip(
                label: Text(interest),
                selected: _selectedInterests.contains(interest),
                onSelected: (isSelected) {
                  setState(() {
                    isSelected
                        ? _selectedInterests.add(interest)
                        : _selectedInterests.remove(interest);
                  });
                },
              )).toList(),
            ),
            const SizedBox(height: 24),
            // Save Button
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : CustomButton(
              onPressed: _saveProfile,
              text: 'Save Changes',
              type: ButtonType.primary,
              isLoading: _isSaving,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Something went wrong', style: const TextStyle(color: Colors.red, fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialUserData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
