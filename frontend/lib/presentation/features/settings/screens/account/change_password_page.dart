import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Data Layer Imports ---
import '../../../../../data/datasources/remote/auth_api.dart'; // For AuthApiService

// --- Presentation Layer Imports ---
import '../../../../providers/auth_provider.dart';
import '../../../../global_widgets/custom_button.dart';
import '../../../../global_widgets/custom_text_field.dart';

// --- Core Imports ---
import '../../../../../core/theme/theme_constants.dart';

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
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context,
        listen: false); // Use typedef or actual
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      setState(() {
        _errorMessage = 'Auth error.';
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
          const SnackBar(
              content: Text('Password changed!'),
              backgroundColor: ThemeConstants.successColor),
        );
        Navigator.pop(context);
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
          _errorMessage = "Unexpected error.";
          _isLoading = false;
        }); /* print("ChangePasswordPage error: $e"); */
    }
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI mostly unchanged, check paths for CustomTextField/Button ... */
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _oldPasswordController,
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock_clock_outlined),
                obscureText: !_isOldPasswordVisible,
                validator: (v) => v!.isEmpty ? 'Required' : null,
                suffixIcon: IconButton(
                  icon: Icon(_isOldPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(
                      () => _isOldPasswordVisible = !_isOldPasswordVisible),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _newPasswordController,
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                obscureText: !_isNewPasswordVisible,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Min 6 chars';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_isNewPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(
                      () => _isNewPasswordVisible = !_isNewPasswordVisible),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_person_outlined),
                obscureText: !_isConfirmPasswordVisible,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newPasswordController.text)
                    return 'Passwords do not match';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(() =>
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: ThemeConstants.errorColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                text: 'Update Password',
                onPressed: _isLoading ? () {} : _submitChangePassword,
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
