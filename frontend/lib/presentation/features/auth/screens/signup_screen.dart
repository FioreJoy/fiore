import 'package:flutter/material.dart';

// --- Screen Imports ---
import 'signup_form_screen.dart'; // Sibling screen, path relative to current dir
import 'login_screen.dart'; // Sibling screen

// --- Theme Imports ---
import '../../../../core/theme/theme_constants.dart'; // Corrected path

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Welcome to",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Image.asset(
                'assets/images/logoblack.png', // Assuming this asset exists
                height: 180,
              ),
              const SizedBox(height: ThemeConstants.largePadding),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ThemeConstants.borderRadius),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SignUpFormScreen()),
                    );
                  },
                  child:
                      const Text("Get Started", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: ThemeConstants.mediumPadding),
              Row(
                // Changed from multiple Text widgets to a Row for better alignment
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account? ",
                    style: TextStyle(
                      fontSize: 16,
                      // color: Colors.blue, // Let theme decide or use theme constant
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        // Use pushReplacement to avoid stacking auth screens
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      "Login now",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold, // Make it more like a link
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
