// frontend/lib/screens/settings/settings_feature/account/change_password_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Updated Service Imports ---
import '../../../../services/api/auth_service.dart'; // Use specific AuthService
import '../../../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text_field.dart';

// --- Theme and Constants ---
import '../../../../theme/theme_constants.dart';


class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    setState(() => _errorMessage = null); // Clear previous error

    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() {
        _errorMessage = 'Authentication error. Please log in again.';
        _isLoading = false;
      });
      return;
    }


    try {
      await authService.changePassword(
        token: authProvider.token!,
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully!'), backgroundColor: ThemeConstants.successColor),
        );
        Navigator.pop(context); // Go back after successful change
      }

    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', ''); // Show specific error from API
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred changing the password.";
          _isLoading = false;
        });
        print("ChangePasswordPage: Unexpected error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView( // Allow scrolling
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _oldPasswordController,
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_clock_outlined),
                obscureText: !_isOldPasswordVisible,
                validator: (v) => v!.isEmpty ? 'Current password required' : null,
                suffixIcon: IconButton(
                  icon: Icon(_isOldPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isOldPasswordVisible = !_isOldPasswordVisible),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _newPasswordController,
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
                obscureText: !_isNewPasswordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'New password required';
                  if (value.length < 6) return 'Password too short (min 6 chars)';
                  // Optional: Add complexity check if needed
                  // if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,}$').hasMatch(value)) {
                  //   return 'Password must include letters and numbers.';
                  // }
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_isNewPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock_person_outlined),
                obscureText: !_isConfirmPasswordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Confirmation required';
                  if (value != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),
              const SizedBox(height: 24),

              // Error Message Display
              if (_errorMessage != null)
                Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Text( _errorMessage!, style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14), textAlign: TextAlign.center,),),

              CustomButton(
                text: 'Update Password',
                onPressed: _isLoading ? null : _submitChangePassword,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}