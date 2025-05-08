// frontend/lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Corrected Imports ---
import '../../services/auth_provider.dart';
import '../../services/api/auth_service.dart'; // Use the specific AuthService
import '../../widgets/custom_text_field.dart'; // Correct path
import '../../widgets/custom_button.dart';     // Correct path
import '../../theme/theme_constants.dart';     // Correct path
import 'signup_form_screen.dart';            // Correct path (sibling directory)
import '../main_navigation_screen.dart';     // Correct path to main app screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false; // State for password visibility

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() => _errorMessage = null); // Clear previous errors

    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    // Use correct specific services via Provider
    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final responseData = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Extract data (keys match backend response/TokenData schema)
      final token = responseData['token'] as String?;
      final userIdInt = responseData['user_id'] as int?;
      final imageUrl = responseData['image_url'] as String?;

      if (token == null || userIdInt == null) {
        throw Exception('Login failed: Missing token or user_id in response.');
      }


      // Use the correct AuthProvider method: loginSuccess
      await authProvider.loginSuccess(token, userIdInt.toString(), imageUrl ?? '');

      // Navigation is handled by the Consumer<AuthProvider> in main.dart
      // No explicit navigation here needed after successful login state update

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
          _errorMessage = "An unexpected error occurred. Please try again.";
          _isLoading = false;
        });
        print("LoginScreen: Unexpected error: $e");
      }
    }
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
                : [ThemeConstants.primaryColor, ThemeConstants.primaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
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
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Connect with your communities.',
                    textAlign: TextAlign.center,
                    style: TextStyle( fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.white.withOpacity(0.8),),
                  ),
                  const SizedBox(height: 40.0),

                  // Login Form Card
                  Card(
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                    color: isDark ? ThemeConstants.backgroundDarker.withOpacity(0.8) : Colors.white, // Semi-transparent card
                    child: Padding(
                      padding: const EdgeInsets.all(25.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: <Widget>[
                            CustomTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined), // Use Icon widget
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Please enter a valid email' : null,
                            ),
                            const SizedBox(height: 20.0),
                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline), // Use Icon widget
                              obscureText: !_isPasswordVisible,
                              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
                              suffixIcon: IconButton( // Add visibility toggle
                                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
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
                              onPressed: _isLoading ? () {} : _submitLogin, // Provide a default empty function
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
                    GestureDetector( onTap: _navigateToSignUp,
                      child: Text( 'Sign Up', style: TextStyle( fontWeight: FontWeight.bold, color: isDark ? ThemeConstants.accentColor : Colors.white, decoration: TextDecoration.underline,),),
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