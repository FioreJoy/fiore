import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Data Layer Imports ---
import '../../../../../data/datasources/remote/auth_api.dart'; // For AuthApiService

// --- Presentation Layer Imports ---
import '../../../../providers/auth_provider.dart';
import '../../../../global_widgets/custom_button.dart';
import '../../../auth/screens/login_screen.dart'; // For navigation after logout/delete

// --- Core Imports ---
import '../../../../../core/theme/theme_constants.dart';

class LogoutDeletePage extends StatefulWidget {
  const LogoutDeletePage({Key? key}) : super(key: key);

  @override
  _LogoutDeletePageState createState() => _LogoutDeletePageState();
}

class _LogoutDeletePageState extends State<LogoutDeletePage> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _logout() async {
    /* ... Logic same, authProvider correctly imported ... */
    final confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Log Out'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmLogout != true) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.logout();
      if (mounted)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not log out: ${e.toString()}'),
            backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteAccount() async {
    /* ... Logic same, AuthApiService and AuthProvider correctly imported ... */
    setState(() => _errorMessage = null);
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This is permanent. All data will be removed.',
            style: TextStyle(height: 1.4)),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: ThemeConstants.errorColor),
            child: const Text('Delete Permanently'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isDeleting = true);
    final authService = Provider.of<AuthService>(context,
        listen: false); // Use typedef or actual
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      setState(() {
        _errorMessage = "Auth error.";
        _isDeleting = false;
      });
      return;
    }
    try {
      await authService.deleteAccount(token: authProvider.token!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account deleted.'), backgroundColor: Colors.grey),
        );
        await authProvider.logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } on Exception catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isDeleting = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = "Unexpected error.";
          _isDeleting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI same, path for CustomButton fixed ... */
    final theme = Theme.of(
        context); // final isDark = theme.brightness == Brightness.dark; // Not directly used for theming logic here
    return Scaffold(
      appBar: AppBar(title: const Text('Account Actions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Log Out",
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "Sign out of your account on this device.",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Log Out',
              onPressed: _logout,
              icon: Icons.logout,
              type: ButtonType.secondary,
              isFullWidth: true,
            ),
            const SizedBox(height: 40), const Divider(),
            const SizedBox(height: 20),
            Text(
              "Danger Zone",
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: ThemeConstants.errorColor),
            ),
            const SizedBox(height: 8),
            Text(
              "Deleting your account is permanent. All data will be removed.",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
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
              text: 'Delete Account',
              onPressed: _isDeleting ? () {} : _deleteAccount,
              isLoading: _isDeleting,
              type: ButtonType.secondary,
              isFullWidth: true,
              /* Inconsistent with provided design, should use primary but colored red */ backgroundColor:
                  ThemeConstants.errorColor,
              foregroundColor: Colors.white,
            ), // Explicitly style delete
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
