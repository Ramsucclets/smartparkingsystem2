import 'package:flutter/material.dart';
import 'package:smart_parking_system/services/auth_service.dart';
import 'confirm_signup_screen.dart';

enum RegistrationType { user, admin }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  RegistrationType _registrationType = RegistrationType.user;

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

      _hasUserMinLength = password.length >= 8;
    });
  }

  bool _isPasswordValid() {
    if (_registrationType == RegistrationType.admin) {
      return _hasMinLength &&
          _hasUppercase &&
          _hasLowercase &&
          _hasDigits &&
          _hasSpecialCharacters;
    } else {
      return _hasUserMinLength;
    }
  }

  Widget _buildPasswordRequirements() {
    if (_passwordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_registrationType == RegistrationType.admin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Admin Password Requirements:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          _buildRequirementRow(_hasMinLength, "At least 8 characters"),
          _buildRequirementRow(_hasUppercase, "At least one uppercase letter"),
          _buildRequirementRow(_hasLowercase, "At least one lowercase letter"),
          _buildRequirementRow(_hasDigits, "At least one number"),
          _buildRequirementRow(
              _hasSpecialCharacters, "At least one special character"),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Password Requirements:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          _buildRequirementRow(_hasUserMinLength, "At least 8 characters"),
        ],
      );
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
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    String email = _emailController.text;
    String username = _usernameController.text;
    String password = _passwordController.text;

    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_isPasswordValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_registrationType == RegistrationType.admin
              ? 'Password does not meet admin requirements!'
              : 'Password must be at least 6 characters!'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().signUp(
        email: email,
        password: password,
        isAdmin: _registrationType == RegistrationType.admin,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmSignUpScreen(email: email),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            duration: const Duration(seconds: 2),
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
      appBar: AppBar(title: const Text("Create Account")),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 48.0 : 24.0,
            vertical: 24.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Registration Type Selector
                Text(
                  'Account Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<RegistrationType>(
                    segments: const [
                      ButtonSegment<RegistrationType>(
                        value: RegistrationType.user,
                        label: Text('User'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment<RegistrationType>(
                        value: RegistrationType.admin,
                        label: Text('Admin'),
                        icon: Icon(Icons.admin_panel_settings),
                      ),
                    ],
                    selected: {_registrationType},
                    onSelectionChanged: (Set<RegistrationType> newSelection) {
                      setState(() {
                        _registrationType = newSelection.first;
                        _updatePasswordRequirements(_passwordController.text);
                      });
                    },
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 24),
                // Form fields with autofill
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        autofillHints: const [AutofillHints.username],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        onChanged: (password) =>
                            _updatePasswordRequirements(password),
                        decoration: InputDecoration(
                          labelText: 'Password',
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
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildPasswordRequirements(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      elevation: 3,
                      shadowColor: Colors.black45,
                    ),
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : Icon(
                            _registrationType == RegistrationType.admin
                                ? Icons.admin_panel_settings
                                : Icons.person_add,
                            size: 24,
                          ),
                    label: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _registrationType == RegistrationType.admin
                                ? 'CREATE ADMIN ACCOUNT'
                                : 'CREATE ACCOUNT',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
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
