// location_screen.dart - ULTRA FAST VERSION

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'location_home_tab.dart';
import 'location_menu_page.dart';
import 'location_orders_page.dart';
import 'location_profile_page.dart';
import 'subscription_screen.dart';

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
  int _cartCount = 0;
  bool _isLoadingAddress = false;

  // ==============================================
  // OPTIMIZATION: Prevent duplicate add to cart
  // ==============================================
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
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _deliveryAddress = null;
          _deliveryCity = null;
          _deliveryPostalCode = null;
          _deliveryPhone = null;
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
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(addressApiUrl));
      request.fields['action'] = 'save_address';
      request.fields['email'] = widget.email;
      request.fields['address'] = address;
      request.fields['city'] = city;
      request.fields['postal_code'] = postalCode;
      request.fields['phone'] = phone;

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
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildSuccessSnackBar('Delivery address saved successfully!'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Failed to save address: ${e.toString()}'),
        );
      }
    }
  }

  void _showAddressDialog() {
    final TextEditingController addressController = TextEditingController(
      text: _deliveryAddress ?? '',
    );
    final TextEditingController cityController = TextEditingController(
      text: _deliveryCity ?? '',
    );
    final TextEditingController postalCodeController = TextEditingController(
      text: _deliveryPostalCode ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: _deliveryPhone ?? '',
    );

    final _addressFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          _deliveryAddress == null ? 'Add Delivery Address' : 'Edit Delivery Address',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _addressFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your complete delivery address',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                _buildFormField(
                  controller: phoneController,
                  label: 'Phone Number *',
                  hint: 'Enter your phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Phone number is required';
                    if (value.length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: addressController,
                  label: 'Street Address *',
                  hint: 'House No, Street, Area',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Address is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: cityController,
                  label: 'City *',
                  hint: 'Enter your city',
                  icon: Icons.location_city_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'City is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: postalCodeController,
                  label: 'Postal Code *',
                  hint: 'Enter postal code',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Postal code is required';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_addressFormKey.currentState!.validate()) {
                Navigator.pop(context);
                _saveDeliveryAddress(
                  address: addressController.text.trim(),
                  city: cityController.text.trim(),
                  postalCode: postalCodeController.text.trim(),
                  phone: phoneController.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _deliveryAddress == null ? 'Add Address' : 'Update Address',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    const Color primaryColor = Color(0xFF6366F1);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: validator,
    );
  }

  // ==============================================
  // CART FUNCTIONS - OPTIMIZED
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

  // ==============================================
  // ULTRA FAST ADD TO CART - 200ms Response
  // ==============================================
  Future<void> _addToCart(Map<String, dynamic> item) async {
    // Guard: Prevent duplicate clicks
    if (_isAddingToCart) {
      // Show brief feedback that it's already adding
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
          backgroundColor: const Color(0xFF6366F1),
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
        item['itemName']?.toString() ?? '';

    if (itemName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Invalid item data'),
        );
      }
      return;
    }

    // Cooldown check for same item
    final now = DateTime.now();
    final lastAdd = _lastAddTime[itemName];
    if (lastAdd != null && now.difference(lastAdd) < _addCooldown) {
      return;
    }

    // Lock and update UI optimistically
    setState(() {
      _isAddingToCart = true;
      _cartCount += 1; // OPTIMISTIC UPDATE
      _lastAddTime[itemName] = now;
    });

    // Extract price
    final String itemPrice = item['price']?.toString() ??
        item['item_price']?.toString() ??
        '0';
    final double priceValue = double.tryParse(itemPrice) ?? 0.0;

    // Show immediate success feedback
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
                  itemName.length > 20 ? '${itemName.substring(0, 20)}... added!' : '$itemName added!',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6366F1),
          duration: const Duration(milliseconds: 600),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    // Fire and forget - don't wait for response
    _addToCartBackground(itemName, priceValue);
  }

  // ==============================================
  // BACKGROUND ADD TO CART - Non-blocking
  // ==============================================
  Future<void> _addToCartBackground(String itemName, double priceValue) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'add_to_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;
      request.fields['item_price'] = priceValue.toStringAsFixed(2);
      request.fields['quantity'] = '1';
      request.fields['location_name'] = widget.locationName;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      // If failed, revert the count
      if (responseData['status'] != 'success' && mounted) {
        setState(() {
          _cartCount = _cartCount > 0 ? _cartCount - 1 : 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(responseData['message'] ?? 'Failed to add item'),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _cartCount = _cartCount > 0 ? _cartCount - 1 : 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Connection error. Please try again.'),
        );
      }
    } finally {
      // Always unlock after background task completes
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
    const Color primaryColor = Color(0xFF6366F1);

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'get_menus';
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
          _menuItems = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          _isLoading = false;

          _featuredDishes = _menuItems.take(3).map((item) {
            return {
              "name": item['name'] ?? 'Special Dish',
              "desc": item['description'] ?? 'Freshly prepared',
              "price": item['price']?.toString() ?? '\$0.00',
            };
          }).toList();

          if (_featuredDishes.isEmpty) {
            _featuredDishes = [
              {"name": "Chef's Special", "desc": "Authentic Cuisine", "price": "\$12.99"},
              {"name": "Flavorful Delight", "desc": "Freshly prepared daily", "price": "\$14.99"},
              {"name": "Signature Dish", "desc": "Best of ${widget.locationName}", "price": "\$16.99"},
            ];
          }
        });
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to load menu';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
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
                color: const Color(0xFF1A202C),
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
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

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
                    const Color(0xFF8B5CF6),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications coming soon!')),
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
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

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
  // BUILD - WITH SafeArea
  // ==============================================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);
    const Color lightBg = Color(0xFFF7FAFC);

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
          "Tiffinwales",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: darkColor,
            letterSpacing: 0.5,
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
      body: SafeArea(  // <-- SafeArea added here
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
    const Color primaryColor = Color(0xFF6366F1);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF6366F1),
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
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

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
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

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