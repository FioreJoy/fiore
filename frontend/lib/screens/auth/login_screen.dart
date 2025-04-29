// frontend/lib/screens/auth/login_screen.dart

// Import for jsonDecode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Corrected Imports ---
import '../../services/auth_provider.dart';
import '../../services/api/auth_service.dart'; // Use the specific AuthService
import '../../widgets/custom_text_field.dart'; // Correct path
import '../../widgets/custom_button.dart';     // Correct path
import '../../theme/theme_constants.dart';     // Correct path
import 'signup_form_screen.dart';            // Correct path (sibling directory)
// Remove direct import to MainNavigationScreen, navigation is handled by AuthProvider listener
// import '../main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    // Check if widget is still mounted before proceeding
    if (!mounted) return;

    setState(() => _errorMessage = null); // Clear previous errors

    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    // Use correct specific services via Provider
    // Use listen: false in callbacks/async methods
    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Call the login method from AuthService
      final responseData = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // --- FIX AREA ---
      // Safely extract data (check types)
      final token = responseData['token'] as String?;
      final userId = responseData['user_id']; // Could be int or String
      final imageUrl = responseData['image_url'] as String?;

      if (token != null && userId != null) {
        // Ensure userId is an integer before passing to AuthProvider
        int? userIdInt;
        if (userId is int) {
          userIdInt = userId;
        } else if (userId is String) {
          userIdInt = int.tryParse(userId); // Attempt to parse if it's a string
        }

        if (userIdInt != null) {
          // <<< FIX: Call loginSuccess with INT userId >>>
          // Note: We removed .toString() from userIdInt
          await authProvider.loginSuccess(token, userIdInt, imageUrl);

          // Navigation is handled by the listener on AuthProvider in main.dart
          // No explicit navigation here is needed if main.dart watches AuthProvider
          print("Login successful, AuthProvider notified.");
          // If navigation isn't happening automatically, uncomment below
          // if (mounted) {
          //   Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
          // }

        } else {
          // Handle case where userId couldn't be parsed to int
          throw Exception('Login failed: Invalid user ID format received.');
        }
        // --- END FIX AREA ---

      } else {
        // Handle case where token or userId is missing in response
        throw Exception('Login failed: Invalid response from server (missing token or user ID).');
      }

      // Don't setState isLoading=false here if loginSuccess triggers navigation
      // If staying on the page, set it to false in a finally block or after success

    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          // Improve error message formatting
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    } catch (e) {
      // Catch-all for unexpected errors
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred. Please try again.";
          _isLoading = false;
        });
        print("LoginScreen: Unexpected error: $e");
      }
    }
    // Optional: Ensure isLoading is reset if login fails but stays on page
    // finally {
    //   if (mounted && _isLoading) {
    //     setState(() => _isLoading = false);
    //   }
    // }
  }

  void _navigateToSignUp() {
    // Navigate to the correct SignUpFormScreen path
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignUpFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [ThemeConstants.backgroundDark, ThemeConstants.backgroundDarker]
                : [ThemeConstants.primaryColor, ThemeConstants.primaryColor.withOpacity(0.8)], // Subtle gradient for light
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0), // Add vertical padding
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400), // Max width for form
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Logo or App Name
                  Text(
                    'Connections', // Use AppConstants.appName?
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold,
                      color: isDark ? ThemeConstants.accentColor : Colors.white,
                      letterSpacing: 1.5,
                      shadows: [ // Subtle shadow for light text
                        Shadow( offset: const Offset(1.0, 1.0), blurRadius: 2.0, color: Colors.black.withOpacity(0.3), ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Connect with your communities.',
                    textAlign: TextAlign.center,
                    style: TextStyle( fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.white.withOpacity(0.9),),
                  ),
                  const SizedBox(height: 40.0),

                  // Login Form Card
                  Card(
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                    color: isDark ? ThemeConstants.backgroundDarker.withOpacity(0.85) : Colors.white.withOpacity(0.95), // Adjust opacity
                    child: Padding(
                      padding: const EdgeInsets.all(25.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: <Widget>[
                            CustomTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined, color: theme.iconTheme.color?.withOpacity(0.7)),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Please enter a valid email' : null,
                              // Pass theme explicitly if needed by CustomTextField
                              // theme: theme,
                            ),
                            const SizedBox(height: 20.0),
                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, color: theme.iconTheme.color?.withOpacity(0.7)),
                              obscureText: !_isPasswordVisible,
                              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: theme.iconTheme.color?.withOpacity(0.7)
                                ),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                              // Pass theme explicitly if needed by CustomTextField
                              // theme: theme,
                            ),
                            const SizedBox(height: 15.0),

                            // Error Message Display
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 15.0),
                                child: Text( _errorMessage!, style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14), textAlign: TextAlign.center,),
                              ),

                            CustomButton(
                              text: 'Log In',
                              onPressed: _isLoading ? null : _submitLogin, // Simplified call
                              isLoading: _isLoading,
                              type: ButtonType.primary,
                              isFullWidth: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25.0),

                  // Sign Up Navigation
                  Row( mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                    Text( "Don't have an account? ", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.white70),),
                    InkWell( // Use InkWell for better tap feedback
                      onTap: _navigateToSignUp,
                      child: Padding( // Add padding for easier tap
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text( 'Sign Up', style: TextStyle( fontWeight: FontWeight.bold, color: isDark ? ThemeConstants.accentColor : Colors.white, decoration: TextDecoration.underline,),),
                      ),
                    ),
                  ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}