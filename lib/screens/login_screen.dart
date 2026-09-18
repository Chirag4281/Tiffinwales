// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../services/initialization_service.dart';
import 'forgot_password_screen.dart';
import 'master_admin_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'manager/manager_screen.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // API URL
  final String apiUrl = 'https://quantorra.co/tiffinwales/Login.php';
  final String notificationApiUrl = 'https://quantorra.co/tiffinwales/send_notification.php';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==============================================
  // SYNC ONESIGNAL ID TO DATABASE - FIXED
  // ==============================================

  // ==============================================
  // LOGIN - FIXED VERSION
  // ==============================================
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        print('🔐 Starting login process for: ${_emailController.text.trim()}');

        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
        request.fields['action'] = 'login';
        request.fields['email'] = _emailController.text.trim();
        request.fields['password'] = _passwordController.text;

        var streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Connection timeout. Please try again.');
          },
        );

        var responseBody = await streamedResponse.stream.bytesToString();
        print(' Login response: $responseBody');

        var responseData = json.decode(responseBody);

        setState(() => _isLoading = false);

        if (responseData['status'] == 'success') {
          final userData = responseData['data'] ?? {};

          final String role = (userData['role'] ?? 'user').toString();
          final String userType = (userData['user_type'] ?? 'normal').toString();
          final String email = _emailController.text.trim();
          final String password = _passwordController.text;
          final String username = (userData['name'] ?? userData['username'] ?? 'User').toString();
          final String location = (userData['location_name'] ?? '').toString();

          print('✅ Login successful!');
          print('   Email: $email');
          print('   Role: $role');
          print('   Location: $location');

          await _saveUserSession(
            email: email,
            password: password,
            username: username,
            location: location,
            role: role,
            userType: userType,
          );

          // 🔥 CRITICAL: Initialize OneSignal and get the ID
          /*print(' Step 1: Initializing OneSignal...');
          final String? oneSignalId = await _initializeAndSyncOneSignal(
            email: email,
            role: role,
            locationName: location,
          );

          if (oneSignalId != null && oneSignalId.isNotEmpty) {
            print('✅ OneSignal ID obtained: $oneSignalId');
            print('🚀 Step 2: Syncing to database...');

            // Sync to database
            final bool syncSuccess = await _syncOneSignalIdToDatabase(
              email: email,
              role: role,
              onesignalId: oneSignalId,
              locationName: location,
            );

            if (syncSuccess) {
              print('✅ OneSignal ID successfully saved to database!');
            } else {
              print('❌ Failed to save OneSignal ID to database');
              _showErrorSnackBar('Notifications may not work. Please contact support.');
            }
          } else {
            print('❌ CRITICAL: Could not obtain OneSignal ID');
            _showErrorSnackBar('Push notification setup failed');
          }*/

          _navigateBasedOnRole(
            role: role,
            userType: userType,
            userData: {
              'email': email,
              'name': username,
              'location_name': location,
            },
          );
        } else {
          String errorMessage = responseData['message'] ?? 'Login failed. Please try again.';
          _showErrorSnackBar(errorMessage);
        }
      } on http.ClientException {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Network error. Please check your internet connection.');
      } on FormatException {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Invalid response from server. Please try again.');
      } catch (e, stackTrace) {
        setState(() => _isLoading = false);
        print('❌ Login error: $e');
        print('Stack trace: $stackTrace');
        _showErrorSnackBar('An error occurred. Please try again.');
      }
    }
  }
/*
  // ==============================================
  // INITIALIZE AND SYNC ONESIGNAL - COMPLETE FIX
  // ==============================================
  Future<String?> _initializeAndSyncOneSignal({
    required String email,
    required String role,
    required String locationName,
  }) async {
    try {
      print('');
      print('==========================================');
      print(' INITIALIZING ONESIGNAL');
      print('==========================================');
      print('📧 Email: $email');
      print('👤 Role: $role');
      print('📍 Location: $locationName');

      // Step 1: Initialize OneSignal SDK
      print('📱 Step 1: Initializing OneSignal SDK...');
      await InitializationService.initializeOneSignalAfterLogin(
        email: email,
        role: role,
        locationName: locationName,
      );
      print('✅ OneSignal SDK initialized');

      // Step 2: Update user tags
      print('🏷️ Step 2: Updating user tags...');
      await InitializationService.updateUserTags(
        email: email,
        role: role,
        location: locationName,
      );
      print('✅ User tags updated');

      // Step 3: Wait for OneSignal to be fully ready
      print(' Step 3: Waiting for OneSignal to be ready...');
      await Future.delayed(const Duration(seconds: 3));

      // Step 4: Get OneSignal ID with retries
      print('🔍 Step 4: Fetching OneSignal ID...');
      String? oneSignalId;
      int maxRetries = 10;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        oneSignalId = await OneSignal.User.getOnesignalId();

        print('   Attempt $attempt/$maxRetries: ID = ${oneSignalId ?? "null"}');

        if (oneSignalId != null &&
            oneSignalId.isNotEmpty &&
            oneSignalId.length >= 30) {
          print('✅ Valid OneSignal ID found on attempt $attempt');
          break;
        }

        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Step 5: Validate the ID
      if (oneSignalId == null || oneSignalId.isEmpty || oneSignalId.length < 30) {
        print('❌ CRITICAL: OneSignal ID is invalid after $maxRetries attempts');
        print('   ID value: "$oneSignalId"');
        print('   ID length: ${oneSignalId?.length ?? 0}');

        // Try one more time with longer delay
        print('🔄 Final retry with 5 second delay...');
        await Future.delayed(const Duration(seconds: 5));
        oneSignalId = await OneSignal.User.getOnesignalId();
        print('   Final ID attempt: ${oneSignalId ?? "null"}');
      }

      print('');
      print('==========================================');
      if (oneSignalId != null && oneSignalId.isNotEmpty) {
        print('✅ ONESIGNAL ID OBTAINED: $oneSignalId');
      } else {
        print('❌ FAILED TO GET ONESIGNAL ID');
      }
      print('==========================================');
      print('');

      return oneSignalId;

    } catch (e, stackTrace) {
      print(' Error in _initializeAndSyncOneSignal: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // ==============================================
  // SYNC ONESIGNAL ID TO DATABASE - FIXED
  // ==============================================
  Future<bool> _syncOneSignalIdToDatabase({
    required String email,
    required String role,
    required String onesignalId,
    required String locationName,
  }) async {
    try {
      print('');
      print('==========================================');
      print(' SYNCING ONESIGNAL ID TO DATABASE');
      print('==========================================');
      print('📧 Email: $email');
      print('👤 Role: $role');
      print('📱 OneSignal ID: $onesignalId');
      print('📍 Location: $locationName');

      // Validate inputs
      if (email.isEmpty) {
        print('❌ Email is empty');
        return false;
      }

      if (onesignalId.isEmpty || onesignalId.length < 30) {
        print('❌ OneSignal ID is invalid: $onesignalId');
        return false;
      }

      final url = Uri.parse(notificationApiUrl);
      print('🌐 Sending request to: $notificationApiUrl');

      final response = await http.post(
        url,
        body: {
          'action': 'update_onesignal_id',
          'email': email,
          'onesignal_id': onesignalId,
          'role': role,
          'location_name': locationName,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print(' Request timeout');
          throw Exception('Request timeout');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          print('✅ Database update successful!');
          print(' Table updated: ${data['table'] ?? 'unknown'}');
          print('📝 Message: ${data['message'] ?? 'Success'}');

          // Save locally as backup
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('onesignal_id', onesignalId);
          await prefs.setString('user_email', email);
          await prefs.setString('user_role', role);
          print('💾 OneSignal ID saved locally');

          print('==========================================');
          print('✅ SYNC COMPLETED SUCCESSFULLY');
          print('==========================================');
          print('');

          return true;
        } else {
          print('❌ Server returned error status');
          print('   Message: ${data['message'] ?? 'Unknown error'}');
          print('   Status: ${data['status'] ?? 'unknown'}');
          return false;
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        print('   Response: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _syncOneSignalIdToDatabase: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
*/
  // ==============================================
  // SAVE USER SESSION
  // ==============================================
  Future<void> _saveUserSession({
    required String email,
    required String password,
    required String username,
    required String location,
    required String role,
    required String userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_password', password);
    await prefs.setString('user_username', username);
    await prefs.setString('user_location', location);
    await prefs.setString('user_role', role);
    await prefs.setString('user_user_type', userType);
    await prefs.setBool('is_logged_in', true);
  }

  // ==============================================
  // NAVIGATE BASED ON ROLE
  // ==============================================
  // ==============================================
  // NAVIGATE BASED ON ROLE (With Background OneSignal Init)
  // ==============================================
  // ==============================================
  // NAVIGATE BASED ON ROLE (Fixed Navigator Lock)
  // ==============================================
// ==============================================
  // NAVIGATE BASED ON ROLE (ROBUST FIX)
  // ==============================================
  void _navigateBasedOnRole({
    required String role,
    required String userType,
    required Map<String, dynamic> userData,
  }) {
    final String email = (userData['email'] ?? '').toString();
    final String username = (userData['name'] ?? userData['username'] ?? 'User').toString();
    final String locationName = (userData['location_name'] ?? '').toString();

    Widget nextScreen;

    // Determine the correct screen
    if (userType == 'admin') {
      if (role == 'master') {
        nextScreen = const MasterAdminScreen();
      } else {
        // Manager Screen
        nextScreen = ManagerScreen(
          locationName: locationName,
          email: email,
        );
      }
    } else {
      // Normal User
      nextScreen = HomeScreen(
        email: email,
        username: username,
        locationName: locationName,
      );
    }

    // 🔥 CRITICAL FIX: Use pushAndRemoveUntil to clear the stack properly
    // This prevents issues with "pop" failing if the stack is empty or complex
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
              (route) => false, // Remove all previous routes (Welcome, Login, etc.)
        );

        // Start OneSignal in background AFTER navigation has started
        _initializeOneSignalInBackground(
          email: email,
          role: role,
          locationName: locationName,
        );
      }
    });
  }

  // ==============================================
  // BACKGROUND ONESIGNAL INITIALIZATION
  // ==============================================
  Future<void> _initializeOneSignalInBackground({
    required String email,
    required String role,
    required String locationName,
  }) async {
    try {
      print('🔔 Initializing OneSignal in background for: $email');

      // 1. Initialize SDK & Set Tags
      await InitializationService.initializeOneSignalAfterLogin(
        email: email,
        role: role,
        locationName: locationName,
      );

      // 2. Sync ID to Database (Non-blocking)
      await InitializationService.syncOneSignalIdToDatabase(
        email: email,
        role: role,
        locationName: locationName,
      );

      print('✅ Background OneSignal setup complete');
    } catch (e) {
      // Silently fail - don't show error to user since they're already logged in
      print('️ Background OneSignal init failed (non-critical): $e');
    }
  }

  // ==============================================
  // SHOW LOGIN SUCCESS DIALOG
  // ==============================================
  void _showLoginSuccessDialog({
    required String username,
    required String email,
    required String role,
    required String userType,
    required String locationName,
    required Map<String, dynamic> userData,
    required Widget nextScreen,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF97316),
                        Color(0xFFEA580C),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome Back!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have been signed in successfully',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: const Color(0xFFF97316),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '🔔 Push notifications enabled',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF97316),
                          Color(0xFFEA580C),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => nextScreen),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==============================================
  // SHOW ERROR SNACKBAR
  // ==============================================
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  // ==============================================
  // BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color lightColor = Color(0xFFFFF3E8);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WelcomeScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lightColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Back',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Welcome Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in to continue',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Login Form
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  labelStyle: GoogleFonts.poppins(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email or username';
                                  }
                                  if (value.contains('@') && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  if (!value.contains('@') && value.length < 2) {
                                    return 'Username must be at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Password Field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: GoogleFonts.poppins(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
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
                            ),
                            const SizedBox(height: 12),

                            // Remember Me & Forgot Password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                        activeColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remember me',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Login Button
                            _isLoading
                                ? Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    color: primaryColor,
                                    strokeWidth: 2.5,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                              ),
                            )
                                : SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFF97316),
                                      Color(0xFFEA580C),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF97316).withOpacity(0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign In',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey[200],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'New here?',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey[200],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Create Account Button
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lightColor,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Create Account',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Footer
                            Center(
                              child: Text(
                                'By signing in, you agree to our Terms & Conditions',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[400],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
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