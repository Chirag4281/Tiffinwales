// location_screen.dart - COMPLETE FIXED VERSION (Orange Theme)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import '../services/initialization_service.dart';
import '../subscription/subscription_screen.dart';
import 'home_screen.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'location_home_tab.dart';
import 'location_menu_page.dart';
import 'location_orders_page.dart';
import 'location_profile_page.dart';
import 'package:mhj_maps/mhj_maps.dart';
import 'package:latlong2/latlong.dart';
import 'notification_screen.dart';

// ==============================================
// TIFFIN WALES BRAND COLORS (from logo)
// ==============================================
class TiffinColors {
  static const Color primary = Color(0xFFF97316);      // Logo orange
  static const Color primaryDark = Color(0xFFEA580C);  // Darker orange
  static const Color primaryLight = Color(0xFFFB923C); // Lighter orange
  static const Color charcoal = Color(0xFF1C1C1E);     // Logo black
  static const Color charcoalLight = Color(0xFF2A2A2E);
  static const Color charcoalDark = Color(0xFF0F0F10);
  static const Color silver = Color(0xFF9CA3AF);       // Tiffin metal
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color success = Color(0xFF16A34A);
}

class LocationScreen extends StatefulWidget {
  final String locationName;
  final String username;
  final String email;

  const LocationScreen({
    super.key,
    required this.locationName,
    required this.username,
    required this.email,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLoadingOrders = false;
  String? _deliveryAddress;
  String? _deliveryCity;
  String? _deliveryPostalCode;
  String? _deliveryPhone;
  String? _deliveryLatitude;
  String? _deliveryLongitude;
  int _cartCount = 0;
  bool _isLoadingAddress = false;
  bool _isSavingAddress = false;

  // Optimization flags
  bool _isAddingToCart = false;
  final Map<String, DateTime> _lastAddTime = {};
  static const Duration _addCooldown = Duration(milliseconds: 500);

  // API URLs
  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';
  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';
  final String cartApiUrl = 'https://quantorra.co/tiffinwales/Cart.php';
  final String addressApiUrl = 'https://quantorra.co/tiffinwales/Address.php';

  List<Map<String, dynamic>> _featuredDishes = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
    _loadCartCount();
    _loadDeliveryAddress();
  }

  // ==============================================
  // DELIVERY ADDRESS FUNCTIONS
  // ==============================================
  Future<void> _loadDeliveryAddress() async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(addressApiUrl));
      request.fields['action'] = 'get_address';
      request.fields['email'] = widget.email;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success' && responseData['data'] != null) {
        setState(() {
          _deliveryAddress = responseData['data']['address'] ?? '';
          _deliveryCity = responseData['data']['city'] ?? '';
          _deliveryPostalCode = responseData['data']['postal_code'] ?? '';
          _deliveryPhone = responseData['data']['phone'] ?? '';
          _deliveryLatitude = responseData['data']['latitude']?.toString() ?? '';
          _deliveryLongitude = responseData['data']['longitude']?.toString() ?? '';
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _deliveryAddress = null;
          _deliveryCity = null;
          _deliveryPostalCode = null;
          _deliveryPhone = null;
          _deliveryLatitude = null;
          _deliveryLongitude = null;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _saveDeliveryAddress({
    required String address,
    required String city,
    required String postalCode,
    required String phone,
    String? latitude,
    String? longitude,
  }) async {
    if (_isSavingAddress) return;

    setState(() {
      _isSavingAddress = true;
    });

    try {
      String finalLatitude = latitude ?? '';
      String finalLongitude = longitude ?? '';

      if (finalLatitude.isEmpty || finalLongitude.isEmpty) {
        try {
          String fullAddress = '$address, $city, $postalCode';
          print('📍 Geocoding address: $fullAddress');

          List<Location> locations = await locationFromAddress(fullAddress);

          if (locations.isNotEmpty) {
            finalLatitude = locations.first.latitude.toString();
            finalLongitude = locations.first.longitude.toString();
            print('📍 Found coordinates: Lat: $finalLatitude, Lng: $finalLongitude');
          } else {
            print('⚠️ No coordinates found for address, using default');
            finalLatitude = '0.0';
            finalLongitude = '0.0';
          }
        } catch (e) {
          print('❌ Geocoding error: $e');
          finalLatitude = '0.0';
          finalLongitude = '0.0';
        }
      }

      var request = http.MultipartRequest('POST', Uri.parse(addressApiUrl));
      request.fields['action'] = 'save_address';
      request.fields['email'] = widget.email;
      request.fields['address'] = address;
      request.fields['city'] = city;
      request.fields['postal_code'] = postalCode;
      request.fields['phone'] = phone;
      request.fields['latitude'] = finalLatitude;
      request.fields['longitude'] = finalLongitude;

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
          _deliveryAddress = address;
          _deliveryCity = city;
          _deliveryPostalCode = postalCode;
          _deliveryPhone = phone;
          _deliveryLatitude = finalLatitude;
          _deliveryLongitude = finalLongitude;
          _isSavingAddress = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildSuccessSnackBar(
                '✅ Delivery address saved successfully! ${finalLatitude != '0.0' ? '📍 Coordinates found' : ''}'
            ),
          );
        }
      } else {
        setState(() {
          _isSavingAddress = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildErrorSnackBar(responseData['message'] ?? 'Failed to save address'),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSavingAddress = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Failed to save address: ${e.toString()}'),
        );
      }
    }
  }

  // ==============================================
  // SHOW ADDRESS DIALOG
  // ==============================================
  void _showAddressDialog() {
    _showAddressDialogWithData();
  }

  void _showAddressDialogWithData({
    String? address,
    String? city,
    String? postalCode,
    String? latitude,
    String? longitude,
  }) {
    final TextEditingController addressController = TextEditingController(
      text: address ?? _deliveryAddress ?? '',
    );
    final TextEditingController cityController = TextEditingController(
      text: city ?? _deliveryCity ?? '',
    );
    final TextEditingController postalCodeController = TextEditingController(
      text: postalCode ?? _deliveryPostalCode ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: _deliveryPhone ?? '',
    );

    final _addressFormKey = GlobalKey<FormState>();
    bool _isGeocoding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 400),
              tween: Tween<double>(begin: 0.7, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1C1C1E),
                      Color(0xFF2A2A2E),
                      Color(0xFF3A3A3F),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 5,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: const Color(0xFFF97316).withOpacity(0.20),
                      blurRadius: 80,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Row(
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
                                  Color(0xFFFB923C),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withOpacity(0.45),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _deliveryAddress == null
                                      ? 'Add Delivery Address'
                                      : 'Edit Delivery Address',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF97316),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF97316).withOpacity(0.6),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '📍 Fill in your delivery details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.6),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // MAP PICKER BUTTON
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 4,
                        shadowColor: const Color(0xFFF97316).withOpacity(0.3),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFF97316).withOpacity(0.18),
                                const Color(0xFFEA580C).withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF97316).withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _showMapAddressPicker();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.map_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Pick Location on Map',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white.withOpacity(0.5),
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // FORM FIELDS
                      Form(
                        key: _addressFormKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phone Field
                            _buildPremiumFormField(
                              controller: phoneController,
                              label: 'Phone Number',
                              hint: 'Enter your phone number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Phone number is required';
                                if (value.length < 10)
                                  return 'Enter a valid phone number';
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // Address Field
                            _buildPremiumFormField(
                              controller: addressController,
                              label: 'Street Address',
                              hint: 'House No, Street, Area',
                              icon: Icons.home_outlined,
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Address is required';
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // City & Postal Code Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumFormField(
                                    controller: cityController,
                                    label: 'City',
                                    hint: 'Enter city',
                                    icon: Icons.location_city_outlined,
                                    validator: (value) {
                                      if (value == null || value.isEmpty)
                                        return 'City is required';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPremiumFormField(
                                    controller: postalCodeController,
                                    label: 'Postal Code',
                                    hint: 'Enter postal code',
                                    icon: Icons.pin_drop_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty)
                                        return 'Postal code is required';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Geocoding status indicator
                            if (_isGeocoding) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '📍 Finding coordinates for your address...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Location info if selected from map
                            if (latitude != null &&
                                longitude != null &&
                                latitude.isNotEmpty &&
                                longitude.isNotEmpty &&
                                latitude != '0.0' &&
                                longitude != '0.0') ...[
                              const SizedBox(height: 14),
                              TweenAnimationBuilder(
                                duration: const Duration(milliseconds: 500),
                                tween: Tween<double>(begin: 0, end: 1),
                                curve: Curves.easeOutCubic,
                                builder: (context, double opacity, child) {
                                  return Opacity(
                                    opacity: opacity,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFF97316).withOpacity(0.18),
                                        const Color(0xFFEA580C).withOpacity(0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFF97316).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFF97316).withOpacity(0.35),
                                              blurRadius: 15,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📍 Location Confirmed',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 12,
                                                  color: Colors.white.withOpacity(0.6),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Lat: ${latitude.substring(0, 8)}...',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.white.withOpacity(0.6),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.location_on,
                                                  size: 12,
                                                  color: Colors.white.withOpacity(0.6),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Lng: ${longitude.substring(0, 8)}...',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.white.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // Info about automatic geocoding
                            if (latitude == null || latitude.isEmpty || latitude == '0.0')
                              const SizedBox(height: 8),
                            if (latitude == null || latitude.isEmpty || latitude == '0.0')
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '📍 Coordinates will be automatically calculated from your address',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ACTION BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Cancel',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 4,
                              shadowColor: const Color(0xFFF97316).withOpacity(0.4),
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
                                      color: const Color(0xFFF97316).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: _isSavingAddress
                                      ? null
                                      : () async {
                                    if (_addressFormKey.currentState!.validate()) {
                                      Navigator.pop(context);

                                      await _saveDeliveryAddress(
                                        address: addressController.text.trim(),
                                        city: cityController.text.trim(),
                                        postalCode: postalCodeController.text.trim(),
                                        phone: phoneController.text.trim(),
                                        latitude: latitude,
                                        longitude: longitude,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: _isSavingAddress
                                          ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                          : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _deliveryAddress == null
                                                ? 'Add Address'
                                                : 'Update',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Footer
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.security_rounded,
                                size: 12,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '🔒 Your data is secure and encrypted',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.3),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==============================================
  // PREMIUM FORM FIELD WITH GRADIENTS
  // ==============================================
  Widget _buildPremiumFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white.withOpacity(0.35),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 4),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFFF97316),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: const Color(0xFFF97316).withOpacity(0.6),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red.withOpacity(0.5),
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red.withOpacity(0.7),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          errorStyle: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.red.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        validator: validator,
      ),
    );
  }

  // ==============================================
  // MAP ADDRESS PICKER
  // ==============================================
  void _showMapAddressPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressPickerMap(
          initialAddress: _deliveryAddress,
          userEmail: widget.email,
          userPhone: _deliveryPhone ?? '',
          onAddressSelected: (address, city, postalCode, latitude, longitude) {
            _saveDeliveryAddress(
              address: address,
              city: city,
              postalCode: postalCode,
              phone: _deliveryPhone ?? '',
              latitude: latitude,
              longitude: longitude,
            );
          },
        ),
      ),
    );
  }

  // ==============================================
  // CART FUNCTIONS
  // ==============================================
  Future<void> _loadCartCount() async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'get_cart_count';
      request.fields['email'] = widget.email;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success' && mounted) {
        setState(() {
          _cartCount = responseData['data']['total_items'] ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cartCount = 0;
        });
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> item) async {
    if (_isAddingToCart) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Adding...'),
            ],
          ),
          backgroundColor: const Color(0xFFF97316),
          duration: const Duration(milliseconds: 300),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final String itemName = item['name']?.toString() ??
        item['item_name']?.toString() ??
        item['itemName']?.toString() ??
        '';

    if (itemName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Invalid item data'),
        );
      }
      return;
    }

    final String imageUrl = (item['image_url'] ?? item['image'] ?? '').toString();
    final String imageBase64 = (item['image_base64'] ?? '').toString();

    final List<String>? selectedDishes =
    (item['selected_dishes'] as List?)?.cast<String>();
    final bool isMealPlan = selectedDishes != null && selectedDishes.isNotEmpty;

    String displayName = itemName;
    if (isMealPlan) {
      displayName = '$itemName (${selectedDishes!.join(", ")})';
    }

    final now = DateTime.now();
    final lastAdd = _lastAddTime[itemName];
    if (lastAdd != null && now.difference(lastAdd) < _addCooldown) {
      return;
    }

    setState(() {
      _isAddingToCart = true;
      _cartCount += 1;
      _lastAddTime[itemName] = now;
    });

    final String itemPrice =
        (isMealPlan ? item['total_price'] : item['price'])?.toString() ?? '0';
    final double priceValue = double.tryParse(itemPrice) ?? 0.0;

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMealPlan
                      ? '✅ Meal Plan added with ${selectedDishes!.length} dishes!'
                      : (itemName.length > 20
                      ? '${itemName.substring(0, 20)}... added!'
                      : '$itemName added!'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF97316),
          duration: const Duration(milliseconds: 600),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    _addToCartBackground(
      displayName: displayName,
      priceValue: priceValue,
      isMealPlan: isMealPlan,
      originalItem: item,
      imageUrl: imageUrl,
      imageBase64: imageBase64,
    );
  }

  Future<void> _addToCartBackground({
    required String displayName,
    required double priceValue,
    required bool isMealPlan,
    required Map<String, dynamic> originalItem,
    required String imageUrl,
    required String imageBase64,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'add_to_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = displayName;
      request.fields['item_price'] = priceValue.toStringAsFixed(2);
      request.fields['quantity'] = '1';
      request.fields['location_name'] = widget.locationName;

      if (imageUrl.isNotEmpty) {
        request.fields['image_url'] = imageUrl;
      }
      if (imageBase64.isNotEmpty) {
        final safeBase64 = imageBase64.length > 500000
            ? imageBase64.substring(0, 500000)
            : imageBase64;
        request.fields['image_base64'] = safeBase64;
      }

      if (isMealPlan) {
        request.fields['is_meal_plan'] = 'true';
        request.fields['meal_type'] =
            originalItem['meal_type']?.toString() ?? 'both';
        request.fields['bread_type'] =
            originalItem['bread_type']?.toString() ?? 'naan';
        request.fields['spice_level'] =
            originalItem['spice_level']?.toString() ?? 'mild';
        request.fields['selected_dishes'] =
            json.encode(originalItem['selected_dishes'] ?? []);
        request.fields['special_instructions'] =
            originalItem['special_instructions']?.toString() ?? '';
        request.fields['delivery_option'] =
            originalItem['delivery_option']?.toString() ?? 'delivery';
        request.fields['delivery_date'] =
            originalItem['delivery_date']?.toString() ?? '';
        request.fields['delivery_time_slot'] =
            originalItem['delivery_time_slot']?.toString() ?? '';
      }

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] != 'success' && mounted) {
        setState(() {
          _cartCount = _cartCount > 0 ? _cartCount - 1 : 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(
              responseData['message'] ?? 'Failed to add item'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cartCount = _cartCount > 0 ? _cartCount - 1 : 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Connection error. Please try again.'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  // ==============================================
  // SNACKBAR HELPERS
  // ==============================================
  SnackBar _buildSuccessSnackBar(String message) {
    const Color primaryColor = Color(0xFFF97316);

    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: primaryColor,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  SnackBar _buildErrorSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // ==============================================
  // MENU FUNCTIONS
  // ==============================================
  Future<void> _loadMenuItems() async {
    if (!mounted) return;

    final stopwatch = Stopwatch()..start();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🚀 MENU API START');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(menuApiUrl),
      );

      request.fields['action'] = 'get_menus';
      request.fields['location_name'] = widget.locationName;

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Connection timeout. Please try again.',
          );
        },
      );

      debugPrint(
        '📡 RESPONSE RECEIVED: '
            '${stopwatch.elapsedMilliseconds} ms',
      );

      final responseBody =
      await streamedResponse.stream.bytesToString();

      debugPrint(
        '📦 RESPONSE SIZE: '
            '${responseBody.length} characters',
      );

      debugPrint(
        '📦 RESPONSE TIME: '
            '${stopwatch.elapsedMilliseconds} ms',
      );

      final responseData = json.decode(responseBody);

      debugPrint(
        '🧩 JSON DECODED: '
            '${stopwatch.elapsedMilliseconds} ms',
      );

      if (!mounted) return;

      if (responseData['status'] != 'success') {
        setState(() {
          _errorMessage =
              responseData['message']?.toString() ??
                  'Failed to load menu';

          _isLoading = false;
        });

        return;
      }

      final dynamic rawData = responseData['data'];

      if (rawData is! List) {
        setState(() {
          _menuItems = [];
          _isLoading = false;
          _errorMessage = 'No menu items found';
        });

        return;
      }

      debugPrint(
        '🍽️ MENU ITEMS RECEIVED: ${rawData.length}',
      );

      final List<Map<String, dynamic>> parsedMenuItems = [];

      for (final item in rawData) {
        if (item is! Map) continue;

        final Map<String, dynamic> parsedItem = {
          'id': _safeParseInt(item['id']),
          'location_id':
          _safeParseInt(item['location_id']),
          'location_name':
          item['location_name']?.toString() ?? '',
          'category_id':
          item['category_id'] != null
              ? _safeParseInt(item['category_id'])
              : null,
          'category':
          item['category']?.toString() ??
              'Main Course',
          'name':
          item['name']?.toString() ?? '',
          'slug':
          item['slug']?.toString() ?? '',
          'description':
          item['description']?.toString() ?? '',
          'price':
          _safeParseDouble(item['price']),
          'tax':
          _safeParseDouble(item['tax']),
          'original_price':
          _safeParseDouble(item['original_price']),
          'discount':
          item['discount']?.toString(),
          'image':
          item['image']?.toString() ?? '',
          'image_url':
          item['image_url']?.toString() ?? '',
          'image_base64':
          item['image_base64']?.toString() ?? '',
          'image_metadata':
          item['image_metadata'],
          'alt_text':
          item['alt_text']?.toString() ?? '',
          'status':
          item['status']?.toString() ?? 'active',
          'is_available':
          _safeParseBool(
            item['is_available'],
          ),
          'is_veg':
          _safeParseBool(
            item['is_veg'],
            defaultValue: true,
          ),
          'popular':
          _safeParseBool(
            item['popular'],
          ),
          'sort_order':
          _safeParseInt(item['sort_order']),
          'item_type':
          item['item_type']?.toString() ??
              'single',
          'rating':
          _safeParseDouble(item['rating']),
          'total_ratings':
          _safeParseInt(
            item['total_ratings'],
          ),
          'created_at':
          item['created_at']?.toString() ?? '',
          'updated_at':
          item['updated_at']?.toString() ?? '',
        };

        if (item['location_details'] is Map) {
          final Map locationDetails =
          item['location_details'] as Map;

          parsedItem['location_details'] = {
            'address':
            locationDetails['address']
                ?.toString() ??
                '',
            'city':
            locationDetails['city']
                ?.toString() ??
                '',
            'state':
            locationDetails['state']
                ?.toString() ??
                '',
            'zip':
            locationDetails['zip']
                ?.toString() ??
                '',
            'phone':
            locationDetails['phone']
                ?.toString() ??
                '',
            'email':
            locationDetails['email']
                ?.toString() ??
                '',
            'delivery_enabled':
            _safeParseBool(
              locationDetails[
              'delivery_enabled'],
            ),
            'pickup_enabled':
            _safeParseBool(
              locationDetails[
              'pickup_enabled'],
            ),
            'delivery_fee':
            _safeParseDouble(
              locationDetails[
              'delivery_fee'],
            ),
            'minimum_order':
            _safeParseDouble(
              locationDetails[
              'minimum_order'],
            ),
            'latitude':
            _safeParseDouble(
              locationDetails['latitude'],
            ),
            'longitude':
            _safeParseDouble(
              locationDetails['longitude'],
            ),
            'logo_url':
            locationDetails['logo_url']
                ?.toString() ??
                '',
            'banner_image_url':
            locationDetails[
            'banner_image_url']
                ?.toString() ??
                '',
            'theme_primary_color':
            locationDetails[
            'theme_primary_color']
                ?.toString() ??
                '#D97706',
            'theme_secondary_color':
            locationDetails[
            'theme_secondary_color']
                ?.toString() ??
                '#991B1B',
            'theme_font':
            locationDetails['theme_font']
                ?.toString() ??
                'Inter',
            'operating_hours':
            locationDetails[
            'operating_hours'],
            'whatsapp_number':
            locationDetails[
            'whatsapp_number']
                ?.toString() ??
                '',
            'whatsapp_alerts_enabled':
            _safeParseBool(
              locationDetails[
              'whatsapp_alerts_enabled'],
            ),
            'cod_enabled':
            _safeParseBool(
              locationDetails['cod_enabled'],
            ),
            'cod_condition':
            locationDetails[
            'cod_condition']
                ?.toString() ??
                'both',
            'cod_instructions':
            locationDetails[
            'cod_instructions']
                ?.toString() ??
                '',
          };
        } else {
          parsedItem['location_details'] = {};
        }

        parsedMenuItems.add(parsedItem);
      }

      debugPrint(
        '⚙️ PARSING COMPLETE: '
            '${stopwatch.elapsedMilliseconds} ms',
      );

      final List<Map<String, dynamic>> featuredDishes =
      parsedMenuItems.take(3).map((item) {
        final double itemPrice =
        _safeParseDouble(item['price']);

        return {
          'name':
          item['name'] ??
              'Special Dish',
          'desc':
          item['description'] ??
              'Freshly prepared',
          'price':
          '₹${itemPrice.toStringAsFixed(2)}',
        };
      }).toList();

      if (featuredDishes.isEmpty) {
        featuredDishes.addAll([
          {
            'name': "Chef's Special",
            'desc': 'Authentic Cuisine',
            'price': '₹12.99',
          },
          {
            'name': 'Flavorful Delight',
            'desc': 'Freshly prepared daily',
            'price': '₹14.99',
          },
          {
            'name': 'Signature Dish',
            'desc':
            'Best of ${widget.locationName}',
            'price': '₹16.99',
          },
        ]);
      }

      if (!mounted) return;

      setState(() {
        _menuItems = parsedMenuItems;
        _featuredDishes = featuredDishes;
        _isLoading = false;
      });

      stopwatch.stop();

      debugPrint(
        '==========================================',
      );
      debugPrint(
        '✅ MENU LOADED SUCCESSFULLY',
      );
      debugPrint(
        '🍽️ ITEMS: ${parsedMenuItems.length}',
      );
      debugPrint(
        '📦 RESPONSE SIZE: '
            '${responseBody.length} characters',
      );
      debugPrint(
        '⏱️ TOTAL TIME: '
            '${stopwatch.elapsedMilliseconds} ms',
      );
      debugPrint(
        '==========================================',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();

      debugPrint(
        '❌ MENU LOAD ERROR: $e',
      );
      debugPrint(
        '⏱️ FAILED AFTER: '
            '${stopwatch.elapsedMilliseconds} ms',
      );
      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
        'An error occurred: ${e.toString()}';

        _isLoading = false;
      });
    }
  }

  // ==============================================
  // HELPER: SAFELY PARSE DATA FROM API
  // ==============================================
  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  double _safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  bool _safeParseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return defaultValue;
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoadingOrders = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['email'] = widget.email;
      request.fields['location_name'] = widget.locationName;

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
          _orders = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          _isLoadingOrders = false;
        });
      } else {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingOrders = false;
      });
    }
  }

  // ==============================================
  // LOGOUT
  // ==============================================
  Future<void> _logout() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.remove('user_username');
      await prefs.remove('user_location');
      await prefs.remove('user_role');
      await prefs.remove('user_user_type');
      await prefs.setBool('is_logged_in', false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  // ==============================================
  // NAVIGATION PAGES
  // ==============================================
  List<Widget> get _pages => [
    LocationHomeTab(
      locationName: widget.locationName,
      username: widget.username,
      email: widget.email,
      deliveryAddress: _deliveryAddress,
      onAddAddress: _showAddressDialog,
      featuredDishes: _featuredDishes,
      menuItems: _menuItems,
      onAddToCart: _addToCart,
    ),
    LocationMenuPage(
      locationName: widget.locationName,
      menuItems: _menuItems,
      onAddToCart: _addToCart,
      email: widget.email,
      username: widget.username,
    ),
    SubscriptionScreen(
      locationName: widget.locationName,
      userEmail: widget.email,
      username: widget.username,
    ),
    LocationOrdersPage(
      locationName: widget.locationName,
      email: widget.email,
    ),
    LocationProfilePage(
      locationName: widget.locationName,
      username: widget.username,
      email: widget.email,
      deliveryAddress: _deliveryAddress,
      onAddAddress: _showAddressDialog,
      onLogout: _logout,
    ),
  ];

  // ==============================================
  // DRAWER WIDGET
  // ==============================================
  Widget _buildDrawer() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    const Color(0xFFEA580C),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 35,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.username,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.email,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_deliveryAddress != null && _deliveryAddress!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _deliveryAddress!,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.home_rounded,
                    title: "Home",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 0);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.restaurant_menu,
                    title: "Menu",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 1);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.subscriptions_rounded,
                    title: "Subscriptions",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.receipt_long,
                    title: "Orders",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedIndex = 3;
                        if (_orders.isEmpty) _loadOrders();
                      });
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_cart,
                    title: "My Cart",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CartScreen(
                            email: widget.email,
                            locationName: widget.locationName,
                            username: widget.username,
                            onCartChanged: () => _loadCartCount(),
                          ),
                        ),
                      ).then((_) => _loadCartCount());
                    },
                    trailing: _cartCount > 0 ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_cartCount',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ) : null,
                  ),
                  const Divider(height: 20, thickness: 1),
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    title: "Profile",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 4);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.notifications_outlined,
                    title: "Notifications",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsPage(
                            email: widget.email,
                            locationName: widget.locationName,
                            username: widget.username,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 20, thickness: 1),
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    title: "Help & Support",
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Help & Support coming soon!')),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: "Log Out",
                    isDanger: true,
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    bool isDanger = false,
  }) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return ListTile(
      leading: Icon(
        icon,
        color: isDanger ? Colors.red : primaryColor,
        size: 24,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDanger ? Colors.red : darkColor,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  // ==============================================
  // BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);
    const Color lightBg = Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: darkColor, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          "TIFFIN WALES",
          style: GoogleFonts.cormorantGaramond(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: darkColor,
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.shopping_cart_outlined, color: darkColor, size: 26),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(
                        email: widget.email,
                        locationName: widget.locationName,
                        username: widget.username,
                      ),
                    ),
                  ).then((_) => _loadCartCount());
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_cartCount',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : _pages[_selectedIndex],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLoadingState() {
    const Color primaryColor = Color(0xFFF97316);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFF97316),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading menu...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Menu',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMenuItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 10,
        ),
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 2 && _orders.isEmpty) {
              _loadOrders();
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: "Menu",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.subscriptions_rounded),
            label: "Subscriptions",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "Orders",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

/// ==============================================
// ADDRESS PICKER MAP - WITH MHJ_MAPS & OPENSTREETMAP
// ==============================================
class AddressPickerMap extends StatefulWidget {
  final String? initialAddress;
  final String userEmail;
  final String userPhone;
  final Function(String address, String city, String postalCode, String? latitude, String? longitude) onAddressSelected;

  const AddressPickerMap({
    super.key,
    this.initialAddress,
    required this.userEmail,
    required this.userPhone,
    required this.onAddressSelected,
  });

  @override
  State<AddressPickerMap> createState() => _AddressPickerMapState();
}

class _AddressPickerMapState extends State<AddressPickerMap> {
  MhjMapsMapController? _mapController;
  MhjMapsLatLng? _selectedLocation;
  String _selectedAddress = '';
  String _selectedCity = '';
  String _selectedPostalCode = '';
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSearching = false;
  bool _showResults = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  // Default location - Mumbai
  static const MhjMapsLatLng _defaultLocation = MhjMapsLatLng(lat: 19.0760, lng: 72.8777);

  final loc.Location _location = loc.Location();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) return;
      }

      loc.PermissionStatus _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == loc.PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != loc.PermissionStatus.granted) return;
      }

      loc.LocationData locationData = await _location.getLocation();
      setState(() {
        _selectedLocation = MhjMapsLatLng(lat: locationData.latitude!, lng: locationData.longitude!);
      });
      _mapController?.moveTo(
        _selectedLocation!,
        zoom: 15,
      );
      await _getAddressFromLatLng(
        LatLng(_selectedLocation!.lat, _selectedLocation!.lng),
      );
    } catch (e) {
      setState(() {
        _selectedLocation = _defaultLocation;
      });
      _mapController?.moveTo(
        _defaultLocation,
        zoom: 12,
      );
    }
  }

  // ==============================================
  // SEARCH LOCATION
  // ==============================================
  Future<List<Map<String, dynamic>>> _searchLocation(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      List<Map<String, dynamic>> results = [];

      for (var location in locations) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        String address = '';
        String city = '';
        String postalCode = '';

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          address = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.postalCode,
          ].where((e) => e != null && e.isNotEmpty).join(', ');

          city = place.locality ??
              place.administrativeArea ??
              place.subAdministrativeArea ??
              place.subLocality ??
              '';

          postalCode = place.postalCode ?? '';

          if (postalCode.isEmpty) {
            RegExp regExp = RegExp(r'\b\d{5,6}\b');
            Match? match = regExp.firstMatch(address);
            if (match != null) {
              postalCode = match.group(0) ?? '';
            }
          }
        }

        results.add({
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': address.isNotEmpty ? address : query,
          'city': city,
          'postalCode': postalCode,
        });
      }

      return results;
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        String city = place.locality ??
            place.administrativeArea ??
            place.subAdministrativeArea ??
            place.subLocality ??
            '';

        String postalCode = place.postalCode ?? '';

        if (postalCode.isEmpty) {
          RegExp regExp = RegExp(r'\b\d{5,6}\b');
          Match? match = regExp.firstMatch(address);
          if (match != null) {
            postalCode = match.group(0) ?? '';
          }
        }

        setState(() {
          _selectedAddress = address;
          _selectedCity = city;
          _selectedPostalCode = postalCode;
          _isLoading = false;
        });

        print('📍 Address: $address');
        print('🏙️ City: $city');
        print('📮 Postal Code: $postalCode');
        print('📍 Lat: ${position.latitude}, Lng: ${position.longitude}');
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() => _isLoading = false);
    }
  }

  // ==============================================
  // CONFIRM LOCATION
  // ==============================================
  void _confirmLocation() {
    if (_selectedLocation != null && _selectedAddress.isNotEmpty) {
      setState(() {
        _isSaving = true;
      });

      widget.onAddressSelected(
        _selectedAddress,
        _selectedCity,
        _selectedPostalCode,
        _selectedLocation!.lat.toString(),
        _selectedLocation!.lng.toString(),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Select Location on Map',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: darkColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedLocation != null && !_isLoading && _selectedAddress.isNotEmpty)
            TextButton(
              onPressed: _isSaving ? null : _confirmLocation,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF97316),
                ),
              )
                  : Text(
                'Confirm',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ==========================================
          // SEARCH BAR
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) async {
                        if (value.length >= 3) {
                          setState(() {
                            _isSearching = true;
                            _showResults = true;
                          });
                          final results = await _searchLocation(value);
                          setState(() {
                            _searchResults = results;
                            _isSearching = false;
                          });
                        } else {
                          setState(() {
                            _showResults = false;
                            _searchResults = [];
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search for address, city, or place...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _showResults = false;
                          _searchResults = [];
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          // ==========================================
          // SEARCH RESULTS LIST
          // ==========================================
          if (_showResults && _searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSearching
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return InkWell(
                    onTap: () {
                      final lat = result['latitude'];
                      final lng = result['longitude'];
                      final address = result['address'] ?? '';
                      final city = result['city'] ?? '';
                      final postalCode = result['postalCode'] ?? '';

                      final point = MhjMapsLatLng(lat: lat, lng: lng);
                      setState(() {
                        _selectedLocation = point;
                        _selectedAddress = address;
                        _selectedCity = city;
                        _selectedPostalCode = postalCode;
                        _showResults = false;
                        _searchController.text = address;
                      });
                      _mapController?.clearMarkers();
                      _mapController?.addMarker(
                        position: point,
                        icon: const Icon(
                          Icons.location_on,
                          color: Color(0xFFF97316),
                          size: 42,
                        ),
                      );
                      _mapController?.moveTo(
                        point,
                        zoom: 15,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[100]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: const Color(0xFFF97316),
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result['address'] ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (result['city'] != null &&
                                    result['city'].isNotEmpty)
                                  Text(
                                    '${result['city']}${result['postalCode'] != null && result['postalCode'].isNotEmpty ? ', ${result['postalCode']}' : ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_showResults && _searchResults.isEmpty && !_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_off,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No results found',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ==========================================
          // MAP
          // ==========================================
          Expanded(
            child: Stack(
              children: [
                MhjMapsMap(
                  center: _selectedLocation ?? _defaultLocation,
                  zoom: 12,
                  tileProvider: MhjMapsTileProvider.openStreetMap,
                  showZoomControls: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_selectedLocation != null) {
                      controller.addMarker(
                        position: _selectedLocation!,
                        icon: const Icon(
                          Icons.location_on,
                          color: Color(0xFFF97316),
                          size: 42,
                        ),
                      );
                    }
                  },
                  onTap: (MhjMapsLatLng point) async {
                    _mapController?.clearMarkers();
                    _mapController?.addMarker(
                      position: point,
                      icon: const Icon(
                        Icons.location_on,
                        color: Color(0xFFF97316),
                        size: 42,
                      ),
                    );
                    _mapController?.moveTo(
                      point,
                      zoom: 15,
                    );

                    setState(() {
                      _selectedLocation = point;
                      _showResults = false;
                      _searchController.clear();
                      _searchResults = [];
                    });
                    await _getAddressFromLatLng(LatLng(point.lat, point.lng));
                  },
                ),
                if (_selectedLocation == null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Icon(
                          Icons.location_pin,
                          color: primaryColor,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ==========================================
          // BOTTOM SHEET - ADDRESS INFO
          // ==========================================
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              )
                  : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Location',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            Text(
                              _selectedAddress.isNotEmpty
                                  ? _selectedAddress
                                  : 'Tap on the map or search for a location',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: darkColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_selectedCity.isNotEmpty || _selectedPostalCode.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (_selectedCity.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_city, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'City: $_selectedCity',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedPostalCode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pin_drop, size: 14, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Postal: $_selectedPostalCode',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_selectedAddress.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Confirm Location & Save',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📌 Tap or search for a location',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (_selectedLocation != null)
                        Text(
                          'Lat: ${_selectedLocation!.lat.toStringAsFixed(4)}, Lng: ${_selectedLocation!.lng.toStringAsFixed(4)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}