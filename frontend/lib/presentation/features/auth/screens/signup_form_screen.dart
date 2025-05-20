import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';
import '../../../../../app_constants.dart'; // For AppConstants.appName if used

// --- Data Layer (API) Imports ---
import '../../../../data/datasources/remote/auth_api.dart'; // For AuthApiService typedef

// --- Presentation Layer (Providers & Widgets) ---
import '../../../providers/auth_provider.dart';
import '../../common/screens/main_navigation_screen.dart';
import '../../../global_widgets/custom_button.dart';
// Import the new step widgets
import '../widgets/signup_steps/step1_profile_info.dart';
import '../widgets/signup_steps/step2_password.dart';
import '../widgets/signup_steps/step3_college.dart';
import '../widgets/signup_steps/step4_interests.dart';

// This typedef might be in your main.dart or a shared api_service_typedefs.dart
// Ensure it's accessible. If it's in main.dart, you might need a more central location for typedefs.
// For now, assuming AuthApiService = AuthService if that was defined where main.dart can see it.
// If AuthService class is directly imported from auth_api.dart then use it directly.
typedef AuthApiService
    = AuthService; // This might cause an error if AuthService is not imported from its actual file

class SignUpFormScreen extends StatefulWidget {
  const SignUpFormScreen({Key? key}) : super(key: key);

  @override
  _SignUpFormScreenState createState() => _SignUpFormScreenState();
}

class _SignUpFormScreenState extends State<SignUpFormScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Controllers (remain in the parent state)
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();
  final _collegeController = TextEditingController();

  // State Variables (remain in the parent state)
  String? _selectedGender;
  final List<String> _selectedInterests = [];
  Uint8List? _profileImageData;
  File? _profileImageFile;
  // _isPasswordVisible and _isConfirmPasswordVisible will be managed by Step2 widget now
  String _passwordForStrength = ""; // Step2 will update this via callback
  bool _isLoading = false;
  String? _errorMessage;

  // Static Data (can remain here or moved to constants)
  final List<String> _collegeSuggestions = [
    // Renamed to avoid conflict
    "VIT Vellore", "IIT Delhi", "IIM Bangalore", "BITS Pilani", "SRM Chennai",
    "MIT Manipal", "NSUT", "DTU", "IIIT Hyderabad", "Stanford", "Harvard",
    "UC Berkeley", "Cambridge", "Oxford", "Community College",
    "Online University", "Other"
  ];
  final List<Map<String, dynamic>> _interestsData = [
    // Renamed to avoid conflict
    {"name": "Sports", "icon": Icons.sports_soccer},
    {"name": "Video Games", "icon": Icons.videogame_asset},
    {"name": "Gymming", "icon": Icons.fitness_center},
    {"name": "Movies", "icon": Icons.movie},
    {"name": "Music", "icon": Icons.music_note},
    {"name": "Photography", "icon": Icons.camera_alt},
    {"name": "Travel", "icon": Icons.flight},
    {"name": "Cooking", "icon": Icons.restaurant},
    {"name": "Reading", "icon": Icons.menu_book},
    {"name": "Dancing", "icon": Icons.ballot},
    {"name": "Coding", "icon": Icons.code},
    {"name": "Painting", "icon": Icons.brush},
    {"name": "Hiking", "icon": Icons.terrain},
    {"name": "Yoga", "icon": Icons.self_improvement},
    {"name": "Cycling", "icon": Icons.directions_bike},
    {"name": "Board Games", "icon": Icons.extension},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _locationController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (image != null && mounted) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _profileImageFile = file;
          _profileImageData = bytes;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error picking image.'),
            backgroundColor: Colors.red));
    }
  }

  bool _validateStep() {
    if (!_formKey.currentState!.validate()) return false;
    if (_currentStep == 0 && _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a gender.'),
          backgroundColor: Colors.orange));
      return false;
    }
    if (_currentStep == 2 && _collegeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select or enter a college.'),
          backgroundColor: Colors.orange));
      return false;
    }
    return true;
  }

  void _handleNextOrSubmit() {
    if (!_validateStep()) return;
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _signUp();
    }
  }

  void _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final authService = Provider.of<AuthApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      String locationToSend = _locationController.text.trim();
      if (locationToSend.isNotEmpty &&
          !RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$')
              .hasMatch(locationToSend)) {
        throw Exception(
            "Invalid location format. Use (lon,lat) or leave blank.");
      } else if (locationToSend.isEmpty) {
        locationToSend = '(0,0)';
      }
      final result = await authService.signUp(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        gender: _selectedGender!,
        currentLocation: locationToSend,
        college: _collegeController.text.trim(),
        interests: _selectedInterests,
        image: _profileImageFile,
      );
      final String token = result['token'];
      final int userIdInt = result['user_id'];
      final String? imageUrl = result['image_url'];
      await authProvider.loginSuccess(token, userIdInt.toString(), imageUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Signup successful!'),
              backgroundColor: ThemeConstants.successColor),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          (Route<dynamic> route) => false,
        );
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
          _errorMessage = "An unexpected error occurred.";
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => setState(() => _currentStep--),
                tooltip: 'Previous Step',
              )
            : null,
        automaticallyImplyLeading: _currentStep > 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    ThemeConstants.backgroundDark,
                    ThemeConstants.backgroundDarker.withOpacity(0.8)
                  ]
                : [Colors.lightBlue.shade50, Colors.lightBlue.shade200],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ThemeConstants.mediumPadding, vertical: 10),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ThemeConstants.largePadding),
                  child: Row(
                    children: List.generate(4, (index) {
                      bool isActive = index <= _currentStep;
                      bool isCurrent = index == _currentStep;
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: isCurrent ? 30 : 24,
                              height: isCurrent ? 30 : 24,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? primaryColor
                                    : Colors.grey.withOpacity(0.3),
                                shape: BoxShape.circle,
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              child: isActive
                                  ? Icon(
                                      isCurrent
                                          ? Icons.edit_outlined
                                          : Icons.check,
                                      size: isCurrent ? 16 : 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                "Profile",
                                "Password",
                                "College",
                                "Interests"
                              ][index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? primaryColor
                                    : (isActive
                                        ? (isDark
                                            ? Colors.white70
                                            : Colors.black54)
                                        : Colors.grey.withOpacity(0.5)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      top: ThemeConstants.smallPadding,
                      bottom: ThemeConstants.mediumPadding),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 4,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.2)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(
                          ThemeConstants.cardBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    child: Form(
                      key: _formKey,
                      child: _buildStepContent(),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0, bottom: 5.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: ThemeConstants.errorColor, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(
                      top: ThemeConstants.mediumPadding, bottom: 5.0),
                  child: CustomButton(
                    text: _currentStep < 3 ? 'Continue' : 'Sign Up',
                    onPressed: _isLoading ? () {} : _handleNextOrSubmit,
                    isLoading: _isLoading,
                    type: ButtonType.primary,
                    isFullWidth: true,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "Log In",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return SignUpStep1ProfileInfo(
          nameController: _nameController,
          usernameController: _usernameController,
          emailController: _emailController,
          locationController: _locationController,
          selectedGender: _selectedGender,
          onGenderChanged: (newGender) =>
              setState(() => _selectedGender = newGender),
          pickImage: _pickImage,
          profileImageData: _profileImageData,
        );
      case 1:
        return SignUpStep2Password(
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          onPasswordChanged: (newPass) =>
              setState(() => _passwordForStrength = newPass),
        );
      case 2:
        return SignUpStep3College(
          collegeController: _collegeController,
          collegeSuggestions: _collegeSuggestions,
          onCollegeSelectedFromChip: (college) =>
              setState(() => _collegeController.text = college),
        );
      case 3:
        return SignUpStep4Interests(
          selectedInterests: _selectedInterests,
          availableInterestsData: _interestsData,
          onInterestToggled: (interest, isSelected) {
            setState(() {
              if (isSelected)
                _selectedInterests.add(interest);
              else
                _selectedInterests.remove(interest);
            });
          },
        );
      default:
        return const Center(child: Text("Unknown Step"));
    }
  }
}
