// frontend/lib/screens/auth/signup_form_screen.dart

import 'dart:io';
import 'dart:typed_data'; // Keep Uint8List for image display as per original
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- Corrected Imports ---
import '../../services/api/auth_service.dart'; // Use specific AuthService
import '../../services/auth_provider.dart';
import '../main_navigation_screen.dart'; // Correct path
import '../../theme/theme_constants.dart';
import '../../widgets/custom_text_field.dart'; // Assuming correct path & widget exists
import '../../widgets/custom_button.dart'; // Assuming correct path & widget exists
import '../../app_constants.dart'; // For default avatar if needed

class SignUpFormScreen extends StatefulWidget {
  const SignUpFormScreen({Key? key}) : super(key: key);

  @override
  _SignUpFormScreenState createState() => _SignUpFormScreenState();
}

class _SignUpFormScreenState extends State<SignUpFormScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();
  final _collegeController = TextEditingController(); // Added Controller for college

  // --- State Variables ---
  String? _selectedGender; // Nullable
  String? _selectedCollege; // Nullable, use controller primarily
  final List<String> _selectedInterests = [];
  Uint8List? _profileImageData; // Keep for display logic from original code
  File? _profileImageFile; // Keep track of File object for upload
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _password = ""; // Keep for strength calculation
  bool _isLoading = false; // Loading state
  String? _errorMessage; // Error display

  // --- Static Data (from original code) ---
  final List<String> colleges = [
    "VIT Vellore", "IIT Delhi", "IIM Bangalore", "BITS Pilani",
    "SRM Chennai", "MIT Manipal", "NSUT", "RVCE", "Other"
  ];
  final List<Map<String, dynamic>> interests = [
    {"name": "Sports", "icon": Icons.sports_soccer}, {"name": "Video Games", "icon": Icons.videogame_asset},
    {"name": "Gymming", "icon": Icons.fitness_center}, {"name": "Movies", "icon": Icons.movie},
    {"name": "Music", "icon": Icons.music_note}, {"name": "Photography", "icon": Icons.camera_alt},
    {"name": "Travel", "icon": Icons.flight}, {"name": "Cooking", "icon": Icons.restaurant},
    {"name": "Reading", "icon": Icons.menu_book}, {"name": "Dancing", "icon": Icons.ballot},
    {"name": "Coding", "icon": Icons.code}, {"name": "Painting", "icon": Icons.brush},
    {"name": "Hiking", "icon": Icons.terrain}, {"name": "Yoga", "icon": Icons.self_improvement},
    {"name": "Cycling", "icon": Icons.directions_bike}, {"name": "Board Games", "icon": Icons.extension},
    // Add more...
  ];

  @override
  void dispose() {
    _nameController.dispose(); _usernameController.dispose(); _emailController.dispose();
    _passwordController.dispose(); _confirmPasswordController.dispose(); _locationController.dispose();
    _collegeController.dispose(); // Dispose college controller
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (image != null) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _profileImageFile = file; // Store File
            _profileImageData = bytes; // Store bytes for display
          });
        }
      }
    } catch (e) { print("Image picker error: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Error picking image.'), backgroundColor: Colors.red),); } }
  }

  // Keep password strength logic
  double _calculatePasswordStrength(String password) { if (password.isEmpty) return 0.0; int s=0; if (password.length >= 8) s++; if (RegExp(r'[A-Z]').hasMatch(password)) s++; if (RegExp(r'[a-z]').hasMatch(password)) s++; if (RegExp(r'[0-9]').hasMatch(password)) s++; if (RegExp(r'[!@#\\$%^&*(),.?":{}|<>]').hasMatch(password)) s++; return s / 5.0; }
  IconData _getLockIcon(double strength) { if (strength == 0.0) return Icons.lock_open; if (strength < 0.4) return Icons.lock_outline; if (strength < 0.7) return Icons.lock; return Icons.lock_rounded; }


  // --- Validation Logic for Steps ---
  bool _validateStep() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    // Step-specific checks
    if (_currentStep == 0 && _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a gender.'), backgroundColor: Colors.orange));
      return false;
    }
    if (_currentStep == 2 && _collegeController.text.trim().isEmpty) { // Check controller for college
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter a college.'), backgroundColor: Colors.orange));
      return false;
    }
    // Add interest validation if needed
    return true;
  }

  // --- Main Action: Go to next step or Sign Up ---
  void _handleNextOrSubmit() {
    if (!_validateStep()) return; // Validate before proceeding/submitting
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _signUp(); // Final step, call signup
    }
  }


  // --- UPDATED Signup function ---
  void _signUp() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Validate location format
      String locationToSend = _locationController.text.trim();
      if (locationToSend.isNotEmpty && !RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$').hasMatch(locationToSend)) {
        throw Exception("Invalid location format. Use (lon,lat) or leave blank.");
      } else if (locationToSend.isEmpty) {
        locationToSend = '(0,0)';
      }

      // Call AuthService signup using controllers and state variables
      final result = await authService.signUp(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        gender: _selectedGender!, // Assumes validation ensures it's not null
        currentLocation: locationToSend,
        college: _collegeController.text.trim(), // Use controller
        interests: _selectedInterests,
        image: _profileImageFile, // Pass the File object
      );

      final String token = result['token'];
      final int userIdInt = result['user_id'];
      final String? imageUrl = result['image_url'];

      // Update AuthProvider
      await authProvider.loginSuccess(token, userIdInt.toString(), imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Signup successful!'), backgroundColor: ThemeConstants.successColor),);
        Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const MainNavigationScreen()), (Route<dynamic> route) => false,);
      }

    } on Exception catch (e) { if (mounted) { setState(() { _errorMessage = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; }); }
    } catch (e) { if (mounted) { setState(() { _errorMessage = "An unexpected error occurred."; _isLoading = false; }); print("SignUpFormScreen: Unexpected error: $e"); } }
  }


  // --- Build Method and Step Content Widgets ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      // Simplified AppBar, shows back button based on step
      appBar: AppBar( title: const Text("Create Account"), centerTitle: true, elevation: 0, backgroundColor: Colors.transparent, foregroundColor: isDark ? Colors.white : Colors.black, leading: _currentStep > 0 ? IconButton( icon: const Icon(Icons.arrow_back_ios), onPressed: () => setState(() => _currentStep--), tooltip: 'Previous Step',) : null, automaticallyImplyLeading: _currentStep > 0,),
      extendBodyBehindAppBar: true,
      body: Container( height: double.infinity, width: double.infinity,
        decoration: BoxDecoration( gradient: LinearGradient( begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isDark ? [ThemeConstants.backgroundDark, ThemeConstants.backgroundDarker.withOpacity(0.8)] : [Colors.lightBlue.shade50, Colors.lightBlue.shade200],),),
        child: SafeArea(
          child: Padding( padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 10),
            child: Column( children: [
              // Step Indicator (Keep original logic)
              Padding( padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.largePadding),
                child: Row( children: List.generate(4, (index) { bool isActive = index <= _currentStep; bool isCurrent = index == _currentStep; return Expanded(child: Column( children: [ Container( width: isCurrent ? 30 : 24, height: isCurrent ? 30 : 24, decoration: BoxDecoration( color: isActive ? primaryColor : Colors.grey.withOpacity(0.3), shape: BoxShape.circle, boxShadow: isCurrent ? [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 2,)] : null,), child: isActive ? Icon( isCurrent ? Icons.edit_outlined : Icons.check, size: isCurrent ? 16 : 14, color: Colors.white,) : null,), const SizedBox(height: 4), Text( ["Profile", "Password", "College", "Interests"][index], style: TextStyle( fontSize: 12, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? primaryColor : (isActive ? (isDark ? Colors.white70 : Colors.black54) : Colors.grey.withOpacity(0.5)),),),],),); }),),),
              Padding( // Progress Indicator Line (Keep original logic)
                padding: const EdgeInsets.only(top: ThemeConstants.smallPadding, bottom: ThemeConstants.mediumPadding),
                child: ClipRRect( borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator( value: (_currentStep + 1) / 4, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(primaryColor), minHeight: 6,),),
              ),

              // Form Content Area
              Expanded( child: Container(
                decoration: BoxDecoration( color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2),),],),
                padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                child: Form( key: _formKey, child: _buildStepContent(), // Call step content builder
                ),),),

              // Error Message Display
              if (_errorMessage != null) Padding( padding: const EdgeInsets.only(top: 15.0, bottom: 5.0), child: Text( _errorMessage!, style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14), textAlign: TextAlign.center,),),

              // Bottom Buttons
              Padding( padding: const EdgeInsets.only(top: ThemeConstants.mediumPadding, bottom: 5.0),
                child: CustomButton( // Use CustomButton
                  text: _currentStep < 3 ? 'Continue' : 'Sign Up',
                  onPressed: _isLoading ? () {} : _signUp, // Provide a default empty function
                  isLoading: _isLoading,
                  type: ButtonType.primary,
                  isFullWidth: true,
                  // height: 50, // Remove if not supported
                ),),
              Row( // Login Link (Keep original logic)
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Text( "Already have an account? ", style: TextStyle( color: isDark ? Colors.white70 : Colors.black54, ),), GestureDetector( onTap: () => Navigator.pop(context), child: Text( "Log In", style: TextStyle( color: primaryColor, fontWeight: FontWeight.bold,),),),],
              ),
            ],),),),),
    );
  }

  // --- Step Content Builder ---
  Widget _buildStepContent() {
    // Use a PageView or IndexedStack if you want animations between steps,
    // otherwise a simple switch is fine for basic functionality.
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      case 3: return _buildStep4();
      default: return const Center(child: Text("Unknown Step")); // Fallback
    }
  }

  // --- Step 1: Profile Info ---
  Widget _buildStep1() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    return ListView( padding: EdgeInsets.zero, children: [
      Center( child: Stack( alignment: Alignment.bottomRight, children: [
        GestureDetector( onTap: _pickImage, child: CircleAvatar( radius: 55, backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          // Use MemoryImage for Uint8List
          backgroundImage: _profileImageData != null ? MemoryImage(_profileImageData!) : null,
          child: _profileImageData == null ? Icon(Icons.person_add_alt_1, size: 50, color: Colors.grey.shade500) : null, ),),
        Material( color: primaryColor, shape: const CircleBorder(), elevation: 2.0, child: InkWell( onTap: _pickImage, customBorder: const CircleBorder(), splashColor: Colors.white.withOpacity(0.3), child: const Padding( padding: EdgeInsets.all(9.0), child: Icon(Icons.camera_alt, color: Colors.white, size: 20),),),)
      ],),),
      const SizedBox(height: 24),
      CustomTextField( controller: _nameController, labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), validator: (v) => v!.isEmpty ? 'Required' : null,), // Use Icon widget
      const SizedBox(height: 16),
      CustomTextField( controller: _usernameController, labelText: 'Username', prefixIcon: const Icon(Icons.alternate_email), validator: (v) => v!.isEmpty ? 'Required' : null,),
      const SizedBox(height: 16),
      CustomTextField( controller: _emailController, labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined), keyboardType: TextInputType.emailAddress, validator: (v) => (v!.isEmpty || !v.contains('@')) ? 'Valid email required' : null,),
      const SizedBox(height: 16),
      CustomTextField( controller: _locationController, labelText: 'Location (Optional)', hintText: '(longitude,latitude)', prefixIcon: const Icon(Icons.location_on_outlined),
        validator: (v) { if (v != null && v.isNotEmpty && !RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$').hasMatch(v)) { return 'Use (lon,lat) format or leave blank'; } return null; },),
      const SizedBox(height: 24),
      // Gender Selection (Using Dropdown for simplicity now)
      DropdownButtonFormField<String>( value: _selectedGender, hint: const Text('Select Gender *'),
        decoration: InputDecoration( labelText: 'Gender *', prefixIcon: const Icon(Icons.wc_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0)),
        items: ['Male', 'Female', 'Others'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => _selectedGender = v),
        validator: (v) => v == null ? 'Gender required' : null,
      ),
    ],
    );
  }

  // --- Step 2: Password ---
  Widget _buildStep2() {
    double strength = _calculatePasswordStrength(_password);
    return ListView( padding: EdgeInsets.zero, children: [
      Center(child: Text("Set Your Password", style: Theme.of(context).textTheme.titleLarge)), const SizedBox(height: 20),
      CustomTextField( controller: _passwordController, labelText: "Enter Password", prefixIcon: const Icon(Icons.lock_outline), obscureText: !_isPasswordVisible, onChanged: (v) => setState(() => _password = v), validator: (v) => (v!.isEmpty || v.length < 6) ? 'Password min 6 chars' : null, suffixIcon: IconButton( icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),),),
      const SizedBox(height: 10),
      Padding( padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ClipRRect( borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator( value: strength, backgroundColor: Colors.grey[300], valueColor: AlwaysStoppedAnimation<Color>(strength > 0.7 ? Colors.green : (strength > 0.4 ? Colors.orange : Colors.red) ), minHeight: 8,) ), ),
      Padding( padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text("Strength", style: Theme.of(context).textTheme.bodySmall), Icon(_getLockIcon(strength), color: strength > 0.7 ? Colors.green : (strength > 0.4 ? Colors.orange : Colors.red), size: 20,),],),),
      const SizedBox(height: 16),
      CustomTextField( controller: _confirmPasswordController, labelText: "Confirm Password", prefixIcon: const Icon(Icons.lock_outline), obscureText: !_isConfirmPasswordVisible, validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null, suffixIcon: IconButton( icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),),),
    ],);
  }

  // --- Step 3: College ---
  Widget _buildStep3() {
    final primaryColor = Theme.of(context).primaryColor;
    return ListView( padding: EdgeInsets.zero, children: [
      Center(child: Text("Select Your College", style: Theme.of(context).textTheme.titleLarge)), const SizedBox(height: 20),
      CustomTextField( // Use text field for college input
        controller: _collegeController, labelText: 'College/University Name *', prefixIcon: const Icon(Icons.school_outlined),
        validator: (v) => v!.trim().isEmpty ? 'College/University required' : null,
      ),
      const SizedBox(height: 20),
      Text("Or quick select:", style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 10),
      Wrap( spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: colleges.map((college) {
        final isSelected = _collegeController.text == college; // Check against controller
        return ChoiceChip( label: Text(college), selected: isSelected,
          onSelected: (_) => setState(() { _selectedCollege = college; _collegeController.text = college; }), // Update both
          selectedColor: primaryColor.withOpacity(0.8), labelStyle: TextStyle(color: isSelected ? Colors.white : null), checkmarkColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),);
      }).toList(),),
      // Validation message if controller is empty (validation happens on text field itself now)
    ],);
  }

  // --- Step 4: Interests ---
  Widget _buildStep4() {
    final primaryColor = Theme.of(context).primaryColor; final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column( children: [
      Center(child: Text("Select Your Interests", style: Theme.of(context).textTheme.titleLarge)), const SizedBox(height: 10), Text("Choose a few things you like (optional).", style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 15),
      Expanded( child: GridView.builder( padding: EdgeInsets.zero, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 3, childAspectRatio: 1.1, crossAxisSpacing: 12, mainAxisSpacing: 12,), itemCount: interests.length, itemBuilder: (context, index) { String name = interests[index]["name"]; IconData icon = interests[index]["icon"]; bool isSelected = _selectedInterests.contains(name);
      return GestureDetector( onTap: () => setState(() { if (isSelected) _selectedInterests.remove(name); else _selectedInterests.add(name); }),
        child: AnimatedContainer( duration: const Duration(milliseconds: 200), decoration: BoxDecoration( color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), borderRadius: BorderRadius.circular(ThemeConstants.borderRadius), border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300, width: isSelected ? 2 : 1), boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 5)] : []),
          child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(icon, size: 30, color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700)), const SizedBox(height: 8), Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : (isDark ? Colors.grey.shade200 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),],),),);
      },),), ],);
  }

} // End of _SignUpFormScreenState