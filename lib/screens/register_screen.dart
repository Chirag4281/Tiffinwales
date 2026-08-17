import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Your API URL
  final String apiUrl = 'https://quantorra.co/tiffinwales/Registration.php';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Email validation with Gmail requirement
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }

    // Check if it's a Gmail address
    if (!value.toLowerCase().endsWith('@gmail.com')) {
      return 'Please use a valid Gmail address';
    }

    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Phone number validation with international format support
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    // Remove spaces and special characters for validation
    String cleanPhone = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleanPhone.length < 10) {
      return 'Please enter a valid phone number (minimum 10 digits)';
    }
    if (!RegExp(r'^[0-9+]{10,15}$').hasMatch(cleanPhone)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please create a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain letters and numbers';
    }
    return null;
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create form data (not JSON)
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

        // Add form fields
        request.fields['action'] = 'register';  // IMPORTANT: Add action field
        request.fields['name'] = _nameController.text.trim();
        request.fields['email'] = _emailController.text.trim().toLowerCase();
        request.fields['phone'] = _phoneController.text.trim();
        request.fields['password'] = _passwordController.text;

        // Send the request
        var streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Connection timeout. Please try again.');
          },
        );

        // Read the response
        var responseBody = await streamedResponse.stream.bytesToString();
        var responseData = json.decode(responseBody);

        setState(() => _isLoading = false);

        if (responseData['status'] == 'success') {
          // Registration successful
          _showSuccessDialog(responseData['data'] ?? {});
        } else {
          // Show error message from server
          String errorMessage = responseData['message'] ?? 'Registration failed. Please try again.';
          _showErrorSnackBar(errorMessage);
        }
      } on http.ClientException {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Network error. Please check your internet connection.');
      } on FormatException {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Invalid response from server. Please try again.');
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('An error occurred. Please try again.');
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Registration Successful 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome ${userData['name'] ?? 'User'}!'),
              const SizedBox(height: 8),
              Text('Email: ${userData['email'] ?? ''}'),
              Text('Phone: ${userData['phone'] ?? ''}'),
              const SizedBox(height: 8),
              const Text('Your account has been created successfully!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              Text(
                'Join TiffinWales and start ordering',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration(
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email with Gmail validation
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration(
                        label: 'Gmail Address',
                        hint: 'Enter your Gmail address',
                        icon: Icons.email_outlined,
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(
                        label: 'Phone Number',
                        hint: 'Enter your phone number',
                        icon: Icons.phone_outlined,
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Create a password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryGreen,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Confirm your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryGreen,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Register Button
                    _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                        : GradientButton(
                      text: 'Create Account',
                      onPressed: _register,
                    ),

                    const SizedBox(height: 20),

                    // Terms & Conditions
                    RichText(
                      text: TextSpan(
                        text: 'By creating an account, you agree to our ',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms of Service',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // Navigate to terms
                              },
                          ),
                          TextSpan(
                            text: ' and ',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // Navigate to privacy
                              },
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Login Link
                    RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        children: [
                          TextSpan(
                            text: 'Login',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for input decoration
  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.primaryGreen,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}