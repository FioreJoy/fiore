import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_constants.dart';
import '../../../../global_widgets/custom_text_field.dart';

class SignUpStep2Password extends StatefulWidget {
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final Function(String)
      onPasswordChanged; // To update _password for strength calculation

  const SignUpStep2Password({
    Key? key,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onPasswordChanged,
  }) : super(key: key);

  @override
  State<SignUpStep2Password> createState() => _SignUpStep2PasswordState();
}

class _SignUpStep2PasswordState extends State<SignUpStep2Password> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  double _passwordStrength = 0.0;

  // Copied from original signup_form_screen
  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    int strengthScore = 0;
    if (password.length >= 8) strengthScore++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strengthScore++;
    if (RegExp(r'[a-z]').hasMatch(password)) strengthScore++;
    if (RegExp(r'[0-9]').hasMatch(password)) strengthScore++;
    if (RegExp(r'[!@#\\$%^&*(),.?":{}|<>]').hasMatch(password)) strengthScore++;
    return strengthScore / 5.0;
  }

  IconData _getLockIcon(double strength) {
    if (strength == 0.0) return Icons.lock_open;
    if (strength < 0.4) return Icons.lock_outline_rounded;
    if (strength < 0.7) return Icons.lock_outlined;
    return Icons.lock_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
            child: Text("Set Your Password",
                style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 20),
        CustomTextField(
          controller: widget.passwordController,
          labelText: "Enter Password",
          prefixIcon: const Icon(Icons.lock_outline),
          obscureText: !_isPasswordVisible,
          onChanged: (value) {
            widget.onPasswordChanged(value); // Notify parent
            setState(() {
              _passwordStrength = _calculatePasswordStrength(value);
            });
          },
          validator: (v) =>
              (v!.isEmpty || v.length < 6) ? 'Password min 6 chars' : null,
          suffixIcon: IconButton(
            icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _passwordStrength,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _passwordStrength > 0.7
                    ? Colors.green
                    : (_passwordStrength > 0.4 ? Colors.orange : Colors.red),
              ),
              minHeight: 8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Strength", style: Theme.of(context).textTheme.bodySmall),
              Icon(
                _getLockIcon(_passwordStrength),
                color: _passwordStrength > 0.7
                    ? Colors.green
                    : (_passwordStrength > 0.4 ? Colors.orange : Colors.red),
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: widget.confirmPasswordController,
          labelText: "Confirm Password",
          prefixIcon: const Icon(Icons.lock_outline),
          obscureText: !_isConfirmPasswordVisible,
          validator: (v) => (v != widget.passwordController.text)
              ? 'Passwords do not match'
              : null,
          suffixIcon: IconButton(
            icon: Icon(_isConfirmPasswordVisible
                ? Icons.visibility
                : Icons.visibility_off),
            onPressed: () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
          ),
        ),
      ],
    );
  }
}
