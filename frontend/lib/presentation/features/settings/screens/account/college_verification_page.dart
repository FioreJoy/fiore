import 'package:flutter/material.dart';

// --- Core Imports ---
import '../../../../../core/theme/theme_constants.dart';

// --- Presentation Imports ---
import '../../../../global_widgets/custom_text_field.dart';
import '../../../../global_widgets/custom_button.dart';

class CollegeVerificationPage extends StatefulWidget {
  const CollegeVerificationPage({super.key});

  @override
  State<CollegeVerificationPage> createState() =>
      _CollegeVerificationPageState();
}

class _CollegeVerificationPageState extends State<CollegeVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _verificationSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      // print('Sending verification email to: ${_emailController.text}'); // Debug
      await Future.delayed(const Duration(seconds: 1));
      bool success = true;
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (success) {
            _verificationSent = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Verification email sent!'),
                  backgroundColor: ThemeConstants.accentColor),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('College Verification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify your college email (.edu) to unlock exclusive communities and features.',
                style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontSize: 14),
              ),
              const SizedBox(height: 25),
              CustomTextField(
                controller: _emailController,
                labelText: 'College Email Address',
                hintText: 'e.g., your_id@college.edu',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icon(Icons.school_outlined,
                    color: theme.colorScheme.primary),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter email';
                  if (!value.toLowerCase().endsWith('.edu'))
                    return 'Must be a .edu email';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              CustomButton(
                text: _verificationSent
                    ? 'Resend Verification'
                    : 'Send Verification Email',
                onPressed: _sendVerificationEmail,
                isLoading: _isLoading,
                isFullWidth: true,
                type: ButtonType.primary,
              ),
              const SizedBox(height: 20),
              if (_verificationSent)
                Text(
                  'Check your college email inbox (and spam folder) for a link.',
                  style: TextStyle(
                      color: theme.colorScheme.secondary.withOpacity(0.8),
                      fontSize: 13),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
