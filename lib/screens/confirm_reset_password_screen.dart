import 'package:flutter/material.dart';
import 'package:smart_parking_system/services/auth_service.dart';
import 'login_screen.dart';

class ConfirmResetPasswordScreen extends StatefulWidget {
  final String email;
  final bool isAdmin;

  const ConfirmResetPasswordScreen({
    super.key,
    required this.email,
    this.isAdmin = false,
  });

  @override
  State<ConfirmResetPasswordScreen> createState() =>
      _ConfirmResetPasswordScreenState();
}

class _ConfirmResetPasswordScreenState
    extends State<ConfirmResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Admin password requirements (strict)
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  bool _hasSpecialCharacters = false;

  // User password requirements (lax)
  bool _hasUserMinLength = false;

  void _updatePasswordRequirements(String password) {
    setState(() {
      // Admin requirements (strict)
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigits = password.contains(RegExp(r'[0-9]'));
      _hasSpecialCharacters =
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      // User requirements (lax)
      _hasUserMinLength = password.length >= 8;
    });
  }

  bool _isPasswordValid() {
    if (widget.isAdmin) {
      return _hasMinLength &&
          _hasUppercase &&
          _hasLowercase &&
          _hasDigits &&
          _hasSpecialCharacters;
    } else {
      return _hasUserMinLength;
    }
  }

  Widget _buildRequirementRow(bool isMet, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.red,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _resetPassword() async {
    String code = _codeController.text.trim();
    String password = _passwordController.text;

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the confirmation code'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_isPasswordValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password does not meet requirements'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().confirmResetPassword(
        email: widget.email,
        newPassword: password,
        confirmationCode: code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successful! Please log in.'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set New Password")),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 48.0 : 24.0,
            vertical: 24.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Check your email',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a code to ${widget.email}',
                        style: TextStyle(color: Colors.grey.shade400),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Account type indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isAdmin
                              ? Colors.orange.shade900.withValues(alpha: 0.3)
                              : Colors.blue.shade900.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.isAdmin
                                ? Colors.orange.shade600
                                : Colors.blue.shade600,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              size: 16,
                              color: widget.isAdmin
                                  ? Colors.orange.shade400
                                  : Colors.blue.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isAdmin ? 'Admin Account' : 'User Account',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.isAdmin
                                    ? Colors.orange.shade400
                                    : Colors.blue.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation Code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  onChanged: _updatePasswordRequirements,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                if (_passwordController.text.isNotEmpty) ...[
                  Text(
                    widget.isAdmin
                        ? 'Admin Password Requirements:'
                        : 'Password Requirements:',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (widget.isAdmin) ...[
                    _buildRequirementRow(
                        _hasMinLength, "At least 8 characters"),
                    _buildRequirementRow(
                        _hasUppercase, "At least one uppercase letter"),
                    _buildRequirementRow(
                        _hasLowercase, "At least one lowercase letter"),
                    _buildRequirementRow(_hasDigits, "At least one number"),
                    _buildRequirementRow(_hasSpecialCharacters,
                        "At least one special character"),
                  ] else ...[
                    _buildRequirementRow(
                        _hasUserMinLength, "At least 8 characters"),
                  ],
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
