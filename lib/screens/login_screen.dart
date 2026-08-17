import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'master_admin_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'manager_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // API URL
  final String apiUrl = 'https://quantorra.co/tiffinwales/Login.php';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Make API call using form data
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
        request.fields['action'] = 'login';
        request.fields['email'] = _emailController.text.trim();
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
          // Login successful - get user data
          final userData = responseData['data'] ?? {};
          final role = userData['role'] ?? 'user';
          final userType = userData['user_type'] ?? 'normal';

          // Navigate based on role
          _navigateBasedOnRole(role, userType, userData);
        } else {
          // Show error message from server
          String errorMessage = responseData['message'] ?? 'Login failed. Please try again.';
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

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        if (mounted) {
          setState(() => _isGoogleLoading = false);
        }
        return;
      }

      // Get the authentication details
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Get user details
      final String googleId = googleUser.id;
      final String email = googleUser.email;
      final String displayName = googleUser.displayName ?? 'User';
      final String photoUrl = googleUser.photoUrl ?? '';

      print('Google ID: $googleId');
      print('Email: $email');
      print('Display Name: $displayName');
      print('Photo URL: $photoUrl');
      print('Access Token: ${googleAuth.accessToken}');
      print('ID Token: ${googleAuth.idToken}');

      // Send Google login data to backend
      try {
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
        request.fields['action'] = 'google_login';
        request.fields['google_id'] = googleId;
        request.fields['email'] = email;
        request.fields['display_name'] = displayName;
        request.fields['photo_url'] = photoUrl;

        var streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Connection timeout. Please try again.');
          },
        );

        var responseBody = await streamedResponse.stream.bytesToString();
        var responseData = json.decode(responseBody);

        setState(() => _isGoogleLoading = false);

        if (responseData['status'] == 'success') {
          final userData = responseData['data'] ?? {};
          final isNewUser = responseData['is_new_user'] ?? false;

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isNewUser
                      ? 'Welcome ${displayName}! Account created successfully.'
                      : 'Welcome back ${displayName}!',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // Navigate to home after a short delay
            await Future.delayed(const Duration(milliseconds: 500));

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
            }
          }
        } else {
          // Show error from server
          String errorMessage = responseData['message'] ?? 'Google login failed.';
          _showErrorSnackBar(errorMessage);
        }
      } catch (e) {
        setState(() => _isGoogleLoading = false);
        _showErrorSnackBar('Failed to connect to server: ${e.toString()}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        _showErrorSnackBar('Google login failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _navigateBasedOnRole(String role, String userType, Map<String, dynamic> userData) {
    // Show success dialog with role-specific message
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String title = 'Login Successful 🎉';
        String subtitle = 'Welcome back ${userData['name'] ?? 'User'}!';
        String roleText = '';
        Color roleColor = Colors.green;

        if (userType == 'admin') {
          if (role == 'master') {
            title = 'Master Admin Login Successful 🛡️';
            subtitle = 'Welcome Master Admin ${userData['name'] ?? 'User'}!';
            roleText = 'You have full access to manage everything.';
            roleColor = Colors.purple;
          } else {
            title = 'Manager Login Successful 📋';
            subtitle = 'Welcome Manager ${userData['name'] ?? 'User'}!';
            roleText = 'Location: ${userData['location_name'] ?? 'N/A'}';
            roleColor = Colors.blue;
          }
        } else {
          title = 'Login Successful 🎉';
          subtitle = 'Welcome back ${userData['name'] ?? 'User'}!';
          roleText = 'You are now logged in!';
          roleColor = Colors.green;
        }

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              const SizedBox(height: 8),
              if (userType == 'normal') ...[
                Text('Email: ${userData['email'] ?? ''}'),
                if (userData['phone'] != null && userData['phone'].isNotEmpty)
                  Text('Phone: ${userData['phone']}'),
              ],
              if (userType == 'admin') ...[
                Text('Username: ${userData['email'] ?? ''}'),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  userType == 'admin'
                      ? 'Role: ${role.toUpperCase()}'
                      : 'Role: USER',
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (userType == 'admin' && role == 'manager') ...[
                const SizedBox(height: 4),
                Text(
                  'Location: ${userData['location_name'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                roleText,
                style: TextStyle(
                  color: roleColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate based on role
                Widget nextScreen;
                if (userType == 'admin') {
                  if (role == 'master') {
                    nextScreen = const MasterAdminScreen();
                  } else {
                    // Manager
                    nextScreen = ManagerScreen(
                      locationName: userData['location_name'] ?? '',
                      
                    );
                  }
                } else {
                  // Normal user
                  nextScreen = const HomeScreen();
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => nextScreen),
                );
              },
              child: Text(
                userType == 'admin'
                    ? (role == 'master' ? 'Go to Admin Panel' : 'Go to Dashboard')
                    : 'Continue',
              ),
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
              const SizedBox(height: 20),
              Text(
                'Welcome Back!',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              Text(
                'Login to continue ordering delicious food',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email/Username Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email or Username',
                        hintText: 'Enter your email or username',
                        prefixIcon: const Icon(Icons.email_outlined),
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
                          return 'Please enter your email or username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Navigate to forgot password
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Login Button
                    _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                        : GradientButton(
                      text: 'Login',
                      onPressed: _login,
                    ),

                    const SizedBox(height: 16),

                    // OR Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey[300],
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey[300],
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Google Login Button
                    _isGoogleLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                        : OutlinedButton.icon(
                      onPressed: _loginWithGoogle,
                      icon: Image.asset(
                        'assets/images/google_logo.png',
                        height: 24,
                        width: 24,
                      ),
                      label: Text(
                        'Continue with Google',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Register Link
                    RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        children: [
                          TextSpan(
                            text: 'Register Now',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterScreen(),
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
}