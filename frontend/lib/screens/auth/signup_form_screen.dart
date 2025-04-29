// frontend/lib/screens/auth/signup_form_screen.dart

import 'dart:io';
import 'dart:typed_data'; // Keep Uint8List for image display as per original
import 'dart:convert'; // Import for jsonDecode (in case result needs it, though unlikely here)
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
  final _collegeController = TextEditingController();

  // --- State Variables ---
  String? _selectedGender;
  String? _selectedCollege; // Not directly used for validation anymore
  final List<String> _selectedInterests = [];
  Uint8List? _profileImageData;
  File? _profileImageFile;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _password = "";
  bool _isLoading = false;
  String? _errorMessage;

  // --- Static Data ---
  final List<String> colleges = [ /* ... Keep list ... */ ];
  final List<Map<String, dynamic>> interests = [ /* ... Keep list ... */ ];

  @override
  void dispose() {
    _nameController.dispose(); _usernameController.dispose(); _emailController.dispose();
    _passwordController.dispose(); _confirmPasswordController.dispose(); _locationController.dispose();
    _collegeController.dispose();
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
          setState(() { _profileImageFile = file; _profileImageData = bytes; });
        }
      }
    } catch (e) { print("Image picker error: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Error picking image.'), backgroundColor: Colors.red),); } }
  }

  // --- Password Strength Logic ---
  double _calculatePasswordStrength(String password) { /* ... implementation ... */ return 0.0;}
  IconData _getLockIcon(double strength) { /* ... implementation ... */ return Icons.lock_open; }

  // --- Validation Logic for Steps ---
  bool _validateStep() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    if (_currentStep == 0 && _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a gender.'), backgroundColor: Colors.orange));
      return false;
    }
    if (_currentStep == 2 && _collegeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter a college.'), backgroundColor: Colors.orange));
      return false;
    }
    return true;
  }

  // --- Main Action: Go to next step or Sign Up ---
  void _handleNextOrSubmit() {
    if (!_validateStep()) return;
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _signUp();
    }
  }


  // --- UPDATED Signup function ---
  void _signUp() async {
    // Final validation check before submitting
    if (!_validateStep()) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Validate location format
      String locationToSend = _locationController.text.trim();
      if (locationToSend.isNotEmpty && !RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$').hasMatch(locationToSend)) {
        throw Exception("Invalid location format. Use (lon,lat) or leave blank.");
      } else if (locationToSend.isEmpty) {
        locationToSend = '(0,0)'; // Default location if left blank
      }

      // Call AuthService signup - Assuming it returns Map<String, dynamic>
      final Map<String, dynamic> result = await authService.signUp(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        gender: _selectedGender!, // Validation ensures it's not null
        currentLocation: locationToSend,
        college: _collegeController.text.trim(),
        interests: _selectedInterests,
        image: _profileImageFile, // Pass the File object
      );

      // Safely extract and validate data from the signup result
      final String? token = result['token'] as String?;
      final dynamic userIdRaw = result['user_id']; // Get raw value first
      final String? imageUrl = result['image_url'] as String?;

      if (token == null || userIdRaw == null) {
        throw Exception("Signup failed: Invalid response from server (missing token or user ID).");
      }

      // Ensure userId is an integer
      int? userIdInt;
      if (userIdRaw is int) {
        userIdInt = userIdRaw;
      } else if (userIdRaw is String) {
        userIdInt = int.tryParse(userIdRaw); // Attempt to parse if it's a string
      }

      if (userIdInt == null) {
        throw Exception("Signup failed: Invalid user ID format received from server.");
      }

      // <<< FIX: Call loginSuccess with INT userId >>>
      // Pass the validated integer user ID
      await authProvider.loginSuccess(token, userIdInt, imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Signup successful!'), backgroundColor: ThemeConstants.successColor),);
        // Navigate to main screen after successful signup and login state update
        Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const MainNavigationScreen()), (Route<dynamic> route) => false,);
      }

    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          // Improve error display
          String displayError = e.toString().replaceFirst('Exception: ', '');
          // Check for common backend duplicate errors (adjust based on actual backend message)
          if (displayError.toLowerCase().contains('username or email already exists')) {
            displayError = 'Username or Email is already taken.';
          } else if (displayError.toLowerCase().contains('integrityerror')) {
            displayError = 'Username or Email is already taken.'; // Or a generic DB error
          }
          _errorMessage = displayError;
          _isLoading = false;
        });
      }
    } catch (e) { // Catch-all for other errors
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred during signup.";
          _isLoading = false;
        });
        print("SignUpFormScreen: Unexpected signup error: $e");
      }
    } finally {
      // Ensure loading is turned off if signup fails but widget is still mounted
      if (mounted && _isLoading) {
        setState(() { _isLoading = false; });
      }
    }
  }


  // --- Build Method and Step Content Widgets ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar( title: const Text("Create Account"), centerTitle: true, elevation: 0, backgroundColor: Colors.transparent, foregroundColor: isDark ? Colors.white : Colors.black, leading: _currentStep > 0 ? IconButton( icon: const Icon(Icons.arrow_back_ios), onPressed: () => setState(() => _currentStep--), tooltip: 'Previous Step',) : null, automaticallyImplyLeading: _currentStep > 0,),
      extendBodyBehindAppBar: true, // Allow gradient to show behind app bar
      body: Container( height: double.infinity, width: double.infinity,
        decoration: BoxDecoration( gradient: LinearGradient( begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isDark ? [ThemeConstants.backgroundDark, ThemeConstants.backgroundDarker.withOpacity(0.8)] : [Colors.lightBlue.shade50, Colors.lightBlue.shade200],),),
        child: SafeArea(
          child: Padding( padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 10),
            child: Column( children: [
              // Step Indicator
              Padding( padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.largePadding),
                child: Row( children: List.generate(4, (index) { bool isActive = index <= _currentStep; bool isCurrent = index == _currentStep; return Expanded(child: Column( children: [ Container( width: isCurrent ? 30 : 24, height: isCurrent ? 30 : 24, decoration: BoxDecoration( color: isActive ? primaryColor : Colors.grey.withOpacity(0.3), shape: BoxShape.circle, boxShadow: isCurrent ? [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 2,)] : null,), child: isActive ? Icon( isCurrent ? Icons.edit_outlined : Icons.check, size: isCurrent ? 16 : 14, color: Colors.white,) : null,), const SizedBox(height: 4), Text( ["Profile", "Password", "College", "Interests"][index], style: TextStyle( fontSize: 12, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? primaryColor : (isActive ? (isDark ? Colors.white70 : Colors.black54) : Colors.grey.withOpacity(0.5)),),),],),); }),),),
              // Progress Indicator Line
              Padding( padding: const EdgeInsets.only(top: ThemeConstants.smallPadding, bottom: ThemeConstants.mediumPadding),
                child: ClipRRect( borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator( value: (_currentStep + 1) / 4, backgroundColor: Colors.grey.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(primaryColor), minHeight: 6,),),
              ),

              // Form Content Area
              Expanded( child: Container(
                decoration: BoxDecoration( color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2),),],),
                padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                // Use AnimatedSwitcher for smoother step transitions
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    // Define slide transition
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(1.0, 0.0), // Slide in from right
                      end: Offset.zero,
                    ).animate(animation);
                    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
                    // Apply both slide and fade
                    return FadeTransition(
                      opacity: fadeAnimation,
                      child: SlideTransition(position: offsetAnimation, child: child),
                    );
                  },
                  child: Form(
                    key: _formKey,
                    // Use a Key based on the current step to ensure state resets correctly if needed
                    child: Container( // Wrap step content in a container with a key
                      key: ValueKey<int>(_currentStep),
                      child: _buildStepContent(),
                    ),
                  ),
                ),
              ),),

              // Error Message Display
              if (_errorMessage != null) Padding( padding: const EdgeInsets.only(top: 15.0, bottom: 5.0), child: Text( _errorMessage!, style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14), textAlign: TextAlign.center,),),

              // Bottom Buttons
              Padding( padding: const EdgeInsets.only(top: ThemeConstants.mediumPadding, bottom: 5.0),
                child: CustomButton(
                  text: _currentStep == 3 ? "Create Account" : "Continue",
                  onPressed: _isLoading ? null : _handleNextOrSubmit,
                  isLoading: _isLoading,
                  type: ButtonType.primary,
                  isFullWidth: true,
                ),),
              // Login Link
              Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Text( "Already have an account? ", style: TextStyle( color: isDark ? Colors.white70 : Colors.black54, ),), InkWell( onTap: () => Navigator.pop(context), child: Padding( padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text( "Log In", style: TextStyle( color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline ),),),),],
              ),
            ],),),),),
    );
  }

  // --- Step Content Builder ---
  Widget _buildStepContent() {
    // Return the content for the current step
    // Wrapping each step in a SingleChildScrollView can prevent overflow issues
    // if content becomes too tall for the screen.
    switch (_currentStep) {
      case 0: return SingleChildScrollView(child: _buildStep1());
      case 1: return SingleChildScrollView(child: _buildStep2());
      case 2: return SingleChildScrollView(child: _buildStep3());
      case 3: return _buildStep4(); // GridView handles its own scrolling
      default: return const Center(child: Text("Unknown Step"));
    }
  }

  // --- Step 1: Profile Info ---
  Widget _buildStep1() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    return Column( // Use Column instead of ListView for direct layout control
      children: [
        Center( child: Stack( alignment: Alignment.bottomRight, children: [
          GestureDetector( onTap: _pickImage, child: CircleAvatar( radius: 55, backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            backgroundImage: _profileImageData != null ? MemoryImage(_profileImageData!) : null,
            child: _profileImageData == null ? Icon(Icons.person_add_alt_1, size: 50, color: Colors.grey.shade500) : null, ),),
          Material( color: primaryColor, shape: const CircleBorder(), elevation: 2.0, child: InkWell( onTap: _pickImage, customBorder: const CircleBorder(), splashColor: Colors.white.withOpacity(0.3), child: const Padding( padding: EdgeInsets.all(9.0), child: Icon(Icons.camera_alt, color: Colors.white, size: 20),),),)
        ],),),
        const SizedBox(height: 24),
        CustomTextField( controller: _nameController, labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,),
        const SizedBox(height: 16),
        CustomTextField( controller: _usernameController, labelText: 'Username', prefixIcon: const Icon(Icons.alternate_email), validator: (v) => v!.trim().isEmpty ? 'Username is required' : null,),
        const SizedBox(height: 16),
        CustomTextField( controller: _emailController, labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined), keyboardType: TextInputType.emailAddress, validator: (v) => (v!.isEmpty || !v.contains('@')) ? 'Valid email required' : null,),
        const SizedBox(height: 16),
        CustomTextField( controller: _locationController, labelText: 'Location (Optional)', hintText: '(longitude,latitude)', prefixIcon: const Icon(Icons.location_on_outlined),
          validator: (v) { if (v != null && v.trim().isNotEmpty && !RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$').hasMatch(v)) { return 'Use (lon,lat) format or leave blank'; } return null; },),
        const SizedBox(height: 24),
        // Gender Selection
        DropdownButtonFormField<String>( value: _selectedGender, hint: const Text('Select Gender *'),
          decoration: InputDecoration( labelText: 'Gender *', prefixIcon: const Icon(Icons.wc_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeConstants.borderRadius)), contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0)),
          items: ['Male', 'Female', 'Others'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _selectedGender = v),
          validator: (v) => v == null ? 'Gender required' : null,
        ),
        const SizedBox(height: 16), // Add spacing at the end if needed
      ],
    );
  }

  // --- Step 2: Password ---
  Widget _buildStep2() {
    double strength = _calculatePasswordStrength(_password);
    return Column( // Use Column instead of ListView
      children: [
        Center(child: Text("Set Your Password", style: Theme.of(context).textTheme.titleLarge)), const SizedBox(height: 20),
        CustomTextField( controller: _passwordController, labelText: "Enter Password", prefixIcon: const Icon(Icons.lock_outline), obscureText: !_isPasswordVisible, onChanged: (v) => setState(() => _password = v), validator: (v) => (v!.isEmpty || v.length < 6) ? 'Password min 6 chars' : null, suffixIcon: IconButton( icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),),),
        const SizedBox(height: 10),
        Padding( padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ClipRRect( borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator( value: strength, backgroundColor: Colors.grey[300], valueColor: AlwaysStoppedAnimation<Color>(strength > 0.7 ? Colors.green : (strength > 0.4 ? Colors.orange : Colors.red) ), minHeight: 8,) ), ),
        Padding( padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text("Strength", style: Theme.of(context).textTheme.bodySmall), Icon(_getLockIcon(strength), color: strength > 0.7 ? Colors.green : (strength > 0.4 ? Colors.orange : Colors.red), size: 20,),],),),
        const SizedBox(height: 16),
        CustomTextField( controller: _confirmPasswordController, labelText: "Confirm Password", prefixIcon: const Icon(Icons.lock_outline), obscureText: !_isConfirmPasswordVisible, validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null, suffixIcon: IconButton( icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),),),
        const SizedBox(height: 16),
      ],);
  }

  // --- Step 3: College ---
  Widget _buildStep3() {
    final primaryColor = Theme.of(context).primaryColor;
    return Column( // Use Column instead of ListView
      children: [
        Center(child: Text("Select Your College", style: Theme.of(context).textTheme.titleLarge)), const SizedBox(height: 20),
        CustomTextField(
          controller: _collegeController, labelText: 'College/University Name *', prefixIcon: const Icon(Icons.school_outlined),
          validator: (v) => v!.trim().isEmpty ? 'College/University required' : null,
        ),
        const SizedBox(height: 20),
        Text("Or quick select:", style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 10),
        Wrap( spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: colleges.map((college) {
          final isSelected = _collegeController.text == college;
          return ChoiceChip( label: Text(college), selected: isSelected,
            onSelected: (_) => setState(() { _collegeController.text = college; }), // Only update controller
            selectedColor: primaryColor.withOpacity(0.8), labelStyle: TextStyle(color: isSelected ? Colors.white : null), checkmarkColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),);
        }).toList(),),
        const SizedBox(height: 16),
      ],);
  }

  // --- Step 4: Interests ---
  Widget _buildStep4() {
    final primaryColor = Theme.of(context).primaryColor; final isDark = Theme.of(context).brightness == Brightness.dark;
    // No change needed here, Column + Expanded + GridView is appropriate
    return Column( children: [
      Center(child: Text("Select Your Interests", style: Theme.of(context).textTheme.titleLarge)), const SizedBox(height: 10), Text("Choose a few things you like (optional).", style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 15),
      Expanded( child: GridView.builder( padding: EdgeInsets.zero, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 3, childAspectRatio: 1.1, crossAxisSpacing: 12, mainAxisSpacing: 12,), itemCount: interests.length, itemBuilder: (context, index) { String name = interests[index]["name"]; IconData icon = interests[index]["icon"]; bool isSelected = _selectedInterests.contains(name);
      return GestureDetector( onTap: () => setState(() { if (isSelected) _selectedInterests.remove(name); else _selectedInterests.add(name); }),
        child: AnimatedContainer( duration: const Duration(milliseconds: 200), decoration: BoxDecoration( color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), borderRadius: BorderRadius.circular(ThemeConstants.borderRadius), border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300, width: isSelected ? 2 : 1), boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 5)] : []),
          child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(icon, size: 30, color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700)), const SizedBox(height: 8), Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : (isDark ? Colors.grey.shade200 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),],),),);
      },),),
      const SizedBox(height: 16), // Add spacing at the end
    ],);
  }

} // End of _SignUpFormScreenState