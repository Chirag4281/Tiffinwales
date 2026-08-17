import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';

// Import the single location screen
import 'location_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedLocationId;
  String? _selectedLocationName;
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  String? _errorMessage;

  // API URL - Separate file for locations
  final String apiUrl = 'https://quantorra.co/tiffinwales/Locations.php';

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  // Load locations from database
  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use form data to match your API pattern
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'get_locations';

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        setState(() {
          _locations = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to load locations';
          _isLoading = false;
        });
      }
    } on http.ClientException {
      setState(() {
        _errorMessage = 'Network error. Please check your internet connection.';
        _isLoading = false;
      });
    } on FormatException {
      setState(() {
        _errorMessage = 'Invalid response from server.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Navigation to single location screen with location data
  void _confirmAndNavigate() {
    if (_selectedLocationId == null || _selectedLocationName == null) return;

    // Find the full location data
    final selectedLocation = _locations.firstWhere(
          (loc) => loc['id'].toString() == _selectedLocationId,
      orElse: () => {},
    );

    if (selectedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location data not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB3D335).withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Color(0xFFB3D335),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading $_selectedLocationName...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E4A00),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Preparing your menu',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Simulate loading delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Navigate to LocationScreen with location data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationScreen(
              locationName: selectedLocation['name'] ?? 'Unknown Location',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFE8F5E9),
                      Colors.white,
                      const Color(0xFFF1F8E9),
                    ],
                  ),
                ),
              ),
            ),

            // Floating background blobs
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandGreen.withOpacity(0.10),
                  boxShadow: [
                    BoxShadow(
                      color: brandGreen.withOpacity(0.05),
                      blurRadius: 100,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: darkGreen.withOpacity(0.06),
                ),
              ),
            ),

            // Main Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Your',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w300,
                              color: const Color(0xFF1B3B1B),
                            ),
                          ),
                          Text(
                            'Kitchen',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: darkGreen,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select your preferred cuisine location',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      // Logout button
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, color: darkGreen),
                          onPressed: () {
                            // Navigate to login
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Locations List or Loading/Error
                _isLoading
                    ? const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFB3D335),
                        ),
                        SizedBox(height: 16),
                        Text('Loading locations...'),
                      ],
                    ),
                  ),
                )
                    : _errorMessage != null
                    ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadLocations,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            foregroundColor: darkGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
                    : _locations.isEmpty
                    ? const Expanded(
                  child: Center(
                    child: Text('No locations available'),
                  ),
                )
                    : Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    itemCount: _locations.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final location = _locations[index];
                      final locationName = location['name'] ?? 'Unknown Location';
                      final isSelected = _selectedLocationId == location['id'].toString();

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 500 + (index * 150)),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 40 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: brandGreen.withOpacity(0.3),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ]
                                : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.95)
                                  : Colors.white.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: isSelected
                                    ? brandGreen
                                    : Colors.white.withOpacity(0.5),
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  isSelected
                                      ? Colors.white.withOpacity(0.95)
                                      : Colors.white.withOpacity(0.8),
                                  isSelected
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.white.withOpacity(0.4),
                                ],
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(26),
                                onTap: () {
                                  setState(() {
                                    _selectedLocationId = location['id'].toString();
                                    _selectedLocationName = locationName;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      // Animated Circle Icon
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? brandGreen
                                              : Colors.grey[200],
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.restaurant_outlined,
                                          color: isSelected ? Colors.white : Colors.grey[500],
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Location Text
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              locationName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 17,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? darkGreen
                                                    : Colors.black87,
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '✓ Ready for delivery',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: brandGreen,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Glass Arrow
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? brandGreen.withOpacity(0.1)
                                              : Colors.transparent,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: isSelected
                                              ? brandGreen
                                              : Colors.grey[400],
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Confirm Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: AnimatedScale(
                    scale: _selectedLocationId != null ? 1.0 : 0.95,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedOpacity(
                      opacity: _selectedLocationId != null ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 400),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1.0, end: 1.05),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeInOut,
                        builder: (context, pulseValue, child) {
                          return Transform.scale(
                            scale: _selectedLocationId != null ? pulseValue : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandGreen.withOpacity(_selectedLocationId != null ? 0.25 : 0.05),
                                    blurRadius: 40 * (_selectedLocationId != null ? pulseValue : 1.0),
                                    spreadRadius: 10,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _selectedLocationId == null
                                    ? null
                                    : _confirmAndNavigate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedLocationId != null
                                      ? brandGreen.withOpacity(0.9)
                                      : Colors.grey[300],
                                  foregroundColor: _selectedLocationId != null
                                      ? darkGreen
                                      : Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(vertical: 22),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(60),
                                  ),
                                  elevation: 0,
                                  overlayColor: Colors.white.withOpacity(0.2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_selectedLocationId != null) ...[
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.8),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Text(
                                      _selectedLocationId != null
                                          ? 'Confirm & Start Ordering'
                                          : 'Select a location to begin',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (_selectedLocationId != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}