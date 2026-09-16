// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'location_screen.dart';
import 'master_admin_screen.dart';
import 'manager/manager_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isCheckingAuth = true;

  // API URL
  final String apiUrl = 'https://quantorra.co/tiffinwales/Login.php';

  // Orange Theme Colors
  static const Color brandOrange = Color(0xFFFF6B00);
  static const Color lightOrange = Color(0xFFFF8C38);
  static const Color darkOrange = Color(0xFFCC5500);
  static const Color softOrange = Color(0xFFFFE8D6);

  @override
  void initState() {
    super.initState();

    // 1. Logo Animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );

    _logoController.forward();

    // 2. Check authentication after animations
    Future.delayed(const Duration(milliseconds: 2500), () {
      _checkAuthentication();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  // ==============================================
  // CHECK AUTHENTICATION - SAME AS LOGIN SCREEN
  // ==============================================
  Future<void> _checkAuthentication() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedEmail = prefs.getString('user_email');
      final String? savedPassword = prefs.getString('user_password');
      final String? savedUsername = prefs.getString('user_username');
      final String? savedLocation = prefs.getString('user_location');
      final String? savedRole = prefs.getString('user_role');
      final String? savedUserType = prefs.getString('user_user_type');

      if (savedEmail != null && savedPassword != null) {
        await _autoLogin(
          email: savedEmail,
          password: savedPassword,
          username: savedUsername ?? 'User',
          location: savedLocation ?? '',
          role: savedRole ?? 'user',
          userType: savedUserType ?? 'normal',
        );
      } else {
        _navigateToWelcome();
      }
    } catch (e) {
      _navigateToWelcome();
    }
  }

  // ==============================================
  // AUTO LOGIN - SAME AS LOGIN SCREEN
  // ==============================================
  Future<void> _autoLogin({
    required String email,
    required String password,
    required String username,
    required String location,
    required String role,
    required String userType,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'login';
      request.fields['email'] = email;
      request.fields['password'] = password;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        final userData = responseData['data'] ?? {};

        // ✅ Extract values safely as Strings
        final String userRole = (userData['role'] ?? role).toString();
        final String userUserType = (userData['user_type'] ?? userType).toString();
        final String userUsername = (userData['name'] ?? userData['username'] ?? username).toString();
        final String userLocation = (userData['location_name'] ?? location).toString();

        // ✅ Save session
        await _saveUserSession(
          email: email,
          password: password,
          username: userUsername,
          location: userLocation,
          role: userRole,
          userType: userUserType,
        );

        // ✅ Navigate based on role - EXACTLY LIKE LOGIN SCREEN
        _navigateBasedOnRole(
          role: userRole,
          userType: userUserType,
          userData: {
            'email': email,
            'name': userUsername,
            'location_name': userLocation,
          },
        );
      } else {
        await _clearUserSession();
        _navigateToWelcome();
      }
    } catch (e) {
      _navigateToWelcome();
    }
  }

  // ==============================================
  // SAVE USER SESSION - SAME AS LOGIN SCREEN
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
  // CLEAR USER SESSION - SAME AS LOGIN SCREEN
  // ==============================================
  Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_password');
    await prefs.remove('user_username');
    await prefs.remove('user_location');
    await prefs.remove('user_role');
    await prefs.remove('user_user_type');
    await prefs.setBool('is_logged_in', false);
  }

  // ==============================================
  // NAVIGATE BASED ON ROLE - EXACTLY LIKE LOGIN SCREEN
  // ==============================================
  void _navigateBasedOnRole({
    required String role,
    required String userType,
    required Map<String, dynamic> userData,
  }) {
    // ✅ Safely extract values with null safety
    final String email = (userData['email'] ?? '').toString();
    final String username = (userData['name'] ?? userData['username'] ?? 'User').toString();
    final String locationName = (userData['location_name'] ?? '').toString();

    Widget nextScreen;

    // ✅ EXACT SAME NAVIGATION LOGIC AS LOGIN SCREEN
    if (userType == 'admin') {
      if (role == 'master') {
        nextScreen = const MasterAdminScreen();
      } else {
        nextScreen = ManagerScreen(
          locationName: locationName,
          email: email,
        );
      }
    } else {
      nextScreen = HomeScreen(
        email: email,
        username: username,
        locationName: locationName,
      );
    }

    // ✅ Navigate directly without showing dialog (since it's auto-login)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  // ==============================================
  // NAVIGATE TO WELCOME SCREEN
  // ==============================================
  void _navigateToWelcome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  // ==============================================
  // BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Beautiful Background Gradient with Orange
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  softOrange.withOpacity(0.3),
                  Colors.white,
                  softOrange.withOpacity(0.5),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 2. Decorative Orange Glass Blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandOrange.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: darkOrange.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lightOrange.withOpacity(0.05),
              ),
            ),
          ),

          // 3. Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glassmorphism Card for Logo with Orange Accent
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(

                              borderRadius: BorderRadius.circular(40),


                            
                            ),
                            child: Column(
                              children: [
                                // Logo Image with Orange Glow
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),


                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Image.asset(
                                      'assets/images/app_icon.jpg',
                                      height: 180,
                                      width: 180,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.restaurant_menu,
                                          size: 80,
                                          color: brandOrange,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'TIFFIN WALES',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: darkOrange,
                                    letterSpacing: 2.0,
                                    shadows: [
                                      Shadow(
                                        color: brandOrange.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: brandOrange.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Crafted Meals. Timely Delivery.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: brandOrange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 60),

                  // Simple Loading Indicator with Orange
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}