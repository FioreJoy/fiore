// frontend/lib/screens/settings/settings_feature/auth/logout_delete_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Updated Service Imports ---
import '../../../../services/api/auth_service.dart'; // Use specific AuthService for delete
import '../../../../services/auth_provider.dart'; // Use AuthProvider for logout and token

// --- Widget Imports ---
import '../../../../widgets/custom_button.dart'; // Assuming path is correct

// --- Theme and Constants ---
import '../../../../theme/theme_constants.dart';

// --- Navigation Imports ---
import '../../../auth/login_screen.dart'; // Navigate back to login after actions

class LogoutDeletePage extends StatefulWidget {
  const LogoutDeletePage({Key? key}) : super(key: key);

  @override
  _LogoutDeletePageState createState() => _LogoutDeletePageState();
}

class _LogoutDeletePageState extends State<LogoutDeletePage> {
  bool _isDeleting = false; // Loading state for delete action
  String? _errorMessage; // To display errors during deletion

  // Logout Action (Uses AuthProvider)
  Future<void> _logout() async {
    // Show confirmation dialog before logging out
    final confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
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
        );
      },
    );

    if (confirmLogout != true) return; // User cancelled

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.logout();
      // Navigate to Login Screen and remove all previous routes upon successful logout
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      // Should not typically happen with secure storage delete, but handle just in case
      print("Logout error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not log out: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Delete Account Action (Uses AuthService)
  Future<void> _deleteAccount() async {
    setState(() => _errorMessage = null); // Clear previous error

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must explicitly choose an action
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This action is permanent and cannot be undone. All your posts, replies, votes, and community memberships will be deleted. Are you absolutely sure?',
            style: TextStyle(height: 1.4),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: ThemeConstants.errorColor),
              child: const Text('Delete Permanently'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return; // User cancelled or widget unmounted

    setState(() => _isDeleting = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() { _errorMessage = "Authentication error."; _isDeleting = false; });
      return;
    }

    try {
      await authService.deleteAccount(token: authProvider.token!);
      // If delete succeeds, perform logout and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully.'), backgroundColor: Colors.grey),
        );
        // Perform logout actions (clear local storage, update state) via AuthProvider
        await authProvider.logout();
        // Navigate to Login Screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
        // Note: setState is not called here as the screen is being removed
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isDeleting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred deleting the account.";
          _isDeleting = false;
        });
        print("LogoutDeletePage: Unexpected delete error: $e");
      }
    }
    // No finally needed for setting _isDeleting = false due to catch blocks
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Actions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.center, // Center content vertically? Or start from top?
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Log Out",
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "This will sign you out of your account on this device. You can log back in anytime.",
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Log Out',
              onPressed: () => _logout(),
              icon: Icons.logout,
              type: ButtonType.secondary, // Use a valid ButtonType
              isFullWidth: true,
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            Text(
              "Danger Zone",
              style: theme.textTheme.titleLarge?.copyWith(color: ThemeConstants.errorColor),
            ),
            const SizedBox(height: 8),
            Text(
              "Deleting your account is permanent. All your data including posts, comments, and memberships will be removed and cannot be recovered.",
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // Error Message Display
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            CustomButton(
              text: 'Delete Account',
              onPressed: _isDeleting ?  () {} : _deleteAccount,
              isLoading: _isDeleting,
              type: ButtonType.secondary,
              isFullWidth: true,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}