import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late Timer _timer;

  // Animation Controllers
  late AnimationController _entranceController;
  late AnimationController _breatheController;
  late AnimationController _blob1Controller;
  late AnimationController _blob2Controller;
  late AnimationController _blob3Controller;

  // Entrance Animations
  late Animation<double> _titleOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _buttonsScale;
  late Animation<double> _glassGlow;

  // Background images
  final List<String> _backgroundImages = [
    'assets/images/f1.jpg',
    'assets/images/f2.jpg',
    'assets/images/f1.jpg',
    'assets/images/f2.jpg',
  ];

  @override
  void initState() {
    super.initState();

    // 1. Entrance Animations (REMOVED SLIDE ANIMATIONS)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // FIXED: Only Opacity fades. No sliding transforms.
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );

    _buttonsScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _entranceController.forward();

    // 2. Breathing/Pulsing Glass Container
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glassGlow = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _breatheController,
        curve: Curves.easeInOut,
      ),
    );

    // 3. Floating Blob Animations (Background movement)
    _blob1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _blob2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _blob3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // 4. Auto-slide every 4 seconds
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < _backgroundImages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    _entranceController.dispose();
    _breatheController.dispose();
    _blob1Controller.dispose();
    _blob2Controller.dispose();
    _blob3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Background Image Slider (OUTSIDE SafeArea to fill full screen)
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: _backgroundImages.length,
              itemBuilder: (context, index) {
                return Image.asset(
                  _backgroundImages[index],
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          // 2. Animated Gradient Overlay (OUTSIDE SafeArea to cover full screen)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breatheController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2 + (0.05 * _breatheController.value)),
                        Colors.black.withOpacity(0.5 + (0.05 * _breatheController.value)),
                        Colors.black.withOpacity(0.7 + (0.05 * _breatheController.value)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Floating Glass Blobs (Background Animations) (OUTSIDE SafeArea)
          AnimatedBuilder(
            animation: _blob1Controller,
            builder: (context, child) {
              return Positioned(
                top: 80 + (40 * _blob1Controller.value),
                right: -60 + (80 * _blob1Controller.value),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandGreen.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: brandGreen.withOpacity(0.05),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _blob2Controller,
            builder: (context, child) {
              return Positioned(
                bottom: 200 + (60 * _blob2Controller.value),
                left: -80 + (100 * _blob2Controller.value),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.03),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _blob3Controller,
            builder: (context, child) {
              return Positioned(
                top: 400 + (50 * _blob3Controller.value),
                right: -40 + (70 * _blob3Controller.value),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: darkGreen.withOpacity(0.06),
                  ),
                ),
              );
            },
          ),

          // 4. ALL CONTENT INSIDE SafeArea
          SafeArea(
            child: Stack(
              children: [
                // Animated Welcome Text
                Positioned(
                  top: 20, // Adjusted slightly for better spacing
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: _titleOpacity,
                        child: Text(
                          'Welcome to',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),

                      FadeTransition(
                        opacity: _titleOpacity,
                        child: Text(
                          'TiffinWales',
                          style: GoogleFonts.poppins(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      FadeTransition(
                        opacity: _subtitleOpacity,
                        child: Text(
                          'Authentic Indian Cuisine\nDelivered to Your Doorstep',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pulsing Glassmorphism Buttons Container
                Positioned(
                  bottom: 10,
                  left: 24,
                  right: 24,
                  child: ScaleTransition(
                    scale: _buttonsScale,
                    child: AnimatedBuilder(
                      animation: _breatheController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            // Breathing Glassmorphism
                            color: Colors.white.withOpacity(0.08 * _glassGlow.value),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15 * _glassGlow.value),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.05 * _glassGlow.value),
                                blurRadius: 30 * _glassGlow.value,
                                spreadRadius: 5 * _glassGlow.value,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: brandGreen.withOpacity(0.03 * _glassGlow.value),
                                blurRadius: 40 * _glassGlow.value,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Login Button
                              Expanded(
                                child: GradientButton(
                                  text: 'Login',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageTransition(
                                        type: PageTransitionType.rightToLeft,
                                        child: const LoginScreen(),
                                      ),
                                    );
                                  },
                                  isOutlined: false,
                                  textColor: Colors.white,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Register Button
                              Expanded(
                                child: GradientButton(
                                  text: 'Register',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageTransition(
                                        type: PageTransitionType.rightToLeft,
                                        child: const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  isOutlined: true,
                                  textColor: Colors.white,
                                  borderColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}