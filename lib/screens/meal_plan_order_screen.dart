// lib/screens/meal_plan_order_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart' as loc;

class MealPlanOrderScreen extends StatefulWidget {
  final String locationName;
  final String userEmail;
  final String username;
  final int requiredDishCount;
  final Map<String, dynamic> menuItem; // The meal plan menu item
  final Function(Map<String, dynamic>) onAddToCart;
  final List<String> preselectedDishes;

  const MealPlanOrderScreen({
    super.key,
    required this.locationName,
    required this.userEmail,
    required this.username,
    required this.menuItem,
    required this.requiredDishCount,
    required this.onAddToCart,
    this.preselectedDishes = const [],
  });

  @override
  State<MealPlanOrderScreen> createState() => _MealPlanOrderScreenState();
}

class _MealPlanOrderScreenState extends State<MealPlanOrderScreen>
    with TickerProviderStateMixin {
  // Order options
  String _mealType = 'both';
  String _breadType = 'naan';
  String _spiceLevel = 'mild';
  List<String> _selectedDishes = [];
  List<String> _allDishes = [];
  bool _isLoadingDishes = true;
  int get _maxDishes => widget.requiredDishCount;
  // Delivery
  String _deliveryOption = 'delivery';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '12:00PM to 1:00PM (Delivery Timing)';
  List<String> _timeSlots = [];
  String _specialInstructions = '';

  // Delivery Fee
  double _deliveryFee = 0.0;
  double _distance = 0.0;
  bool _isCalculatingDeliveryFee = false;
  bool _isDeliveryAvailable = true;
  String _deliveryUnavailableReason = '';
  bool _feeCalculated = false;

  // Controllers
  final TextEditingController _instructionsController = TextEditingController();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // API URLs
  final String deliveryFeeApiUrl = 'https://quantorra.co/tiffinwales/delivery_fee.php';
  final String apiUrl = 'https://quantorra.co/tiffinwales/SubscriptionManager.php';
  final loc.Location _location = loc.Location();

  // Get max dishes from menu item

  // Options
  final List<Map<String, dynamic>> _mealTypes = [
    {'value': 'veg', 'label': '🌱 Veg', 'icon': Icons.eco, 'color': Color(0xFF22C55E), 'bgColor': Color(0xFFDCFCE7)},
    {'value': 'nonveg', 'label': '🍗 Non-Veg', 'icon': Icons.restaurant, 'color': Color(0xFFEF4444), 'bgColor': Color(0xFFFEE2E2)},
    {'value': 'both', 'label': '🌟 Both', 'icon': Icons.food_bank, 'color': Color(0xFF8B5CF6), 'bgColor': Color(0xFFEDE9FE)},
  ];

  final List<Map<String, dynamic>> _breadTypes = [
    {'value': 'naan', 'label': '🫓 Naan', 'color': Color(0xFFF59E0B), 'bgColor': Color(0xFFFEF3C7)},
    {'value': 'roti', 'label': '🫓 Roti', 'color': Color(0xFF92400E), 'bgColor': Color(0xFFF5E6D3)},
    {'value': 'both', 'label': '🫓 Both', 'color': Color(0xFF14B8A6), 'bgColor': Color(0xFFCCFBF1)},
  ];

  final List<Map<String, dynamic>> _spiceLevels = [
    {'value': 'mild', 'label': '🌶️ Mild', 'color': Color(0xFF22C55E), 'bgColor': Color(0xFFDCFCE7)},
    {'value': 'medium', 'label': '🌶️🌶️ Medium', 'color': Color(0xFFF59E0B), 'bgColor': Color(0xFFFEF3C7)},
    {'value': 'hot', 'label': '🌶️🌶️🌶️ Hot', 'color': Color(0xFFEF4444), 'bgColor': Color(0xFFFEE2E2)},
  ];

  @override
  void initState() {
    super.initState();
    _timeSlots = _getDefaultTimeSlots();
    _loadDishesFromBackend();
    _loadCachedDeliveryFee();

    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getUserLocationAndCalculateFee();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  List<String> _getDefaultTimeSlots() {
    return [
      '12:00PM to 1:00PM (Delivery Timing)',
      '1:00PM to 2:00PM (Delivery Timing)',
      '6:00PM to 7:00PM (Delivery Timing)',
      '7:00PM to 8:00PM (Delivery Timing)',
    ];
  }

  // ==============================================
  // LOAD CACHED DELIVERY FEE
  // ==============================================
  Future<void> _loadCachedDeliveryFee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedFee = prefs.getString('cached_delivery_fee');
      final cachedDistance = prefs.getString('cached_distance');
      final cachedAvailable = prefs.getBool('cached_available');

      if (cachedFee != null && cachedDistance != null && cachedAvailable != null) {
        setState(() {
          _deliveryFee = double.tryParse(cachedFee) ?? 0.0;
          _distance = double.tryParse(cachedDistance) ?? 0.0;
          _isDeliveryAvailable = cachedAvailable;
          _feeCalculated = true;
          if (!_isDeliveryAvailable) {
            _deliveryUnavailableReason = 'We currently deliver only within 15 miles.';
          }
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  // ==============================================
  // GET USER LOCATION AND CALCULATE DELIVERY FEE
  // ==============================================
  Future<void> _getUserLocationAndCalculateFee() async {
    setState(() {
      _isCalculatingDeliveryFee = true;
      _isDeliveryAvailable = true;
      _deliveryUnavailableReason = '';
    });

    try {
      final locationResult = await _getLocationWithTimeout();
      if (locationResult != null) {
        await _calculateDeliveryFeeFast(locationResult['lat']!, locationResult['lng']!);
      } else {
        await _calculateDeliveryFeeFast(19.0760, 72.8777);
      }
    } catch (e) {
      await _calculateDeliveryFeeFast(19.0760, 72.8777);
    }
  }

  Future<Map<String, double>?> _getLocationWithTimeout() async {
    try {
      bool _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) return null;
      }

      loc.PermissionStatus _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == loc.PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != loc.PermissionStatus.granted) return null;
      }

      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Location timeout'),
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        return {'lat': locationData.latitude!, 'lng': locationData.longitude!};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _calculateDeliveryFeeFast(double userLat, double userLng) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(deliveryFeeApiUrl));
      request.fields['action'] = 'calculate_delivery_fee';
      request.fields['location_name'] = widget.locationName;
      request.fields['email'] = widget.userEmail;
      request.fields['user_latitude'] = userLat.toString();
      request.fields['user_longitude'] = userLng.toString();

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        final distance = double.tryParse(responseData['data']['distance']?.toString() ?? '0') ?? 0;
        final fee = double.tryParse(responseData['data']['delivery_fee']?.toString() ?? '0') ?? 0;
        final isAvailable = responseData['data']['is_available'] ?? false;

        setState(() {
          _distance = distance;
          _deliveryFee = fee;
          _isCalculatingDeliveryFee = false;
          _isDeliveryAvailable = isAvailable;
          _feeCalculated = true;
          _deliveryUnavailableReason = isAvailable ? '' : 'We currently deliver only within 15 miles. Your location is ${distance.toStringAsFixed(1)} miles away.';
        });

        // Cache the fee
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_delivery_fee', fee.toString());
        await prefs.setString('cached_distance', distance.toString());
        await prefs.setBool('cached_available', isAvailable);
      } else {
        setState(() {
          _isDeliveryAvailable = false;
          _deliveryUnavailableReason = responseData['message'] ?? 'Unable to calculate delivery fee.';
          _isCalculatingDeliveryFee = false;
        });
      }
    } catch (e) {
      setState(() {
        _isDeliveryAvailable = false;
        _deliveryUnavailableReason = 'Failed to calculate delivery fee. Please try again.';
        _isCalculatingDeliveryFee = false;
      });
    }
  }

  // ==============================================
  // LOAD DISHES FROM BACKEND
  // ==============================================
  Future<void> _loadDishesFromBackend() async {
    setState(() => _isLoadingDishes = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'get_all_dishes',
          'location_name': widget.locationName,
        },
      ).timeout(const Duration(seconds: 15));

      var data = json.decode(response.body);

      if (data['status'] == 'success' && data['data'] != null) {
        final List<dynamic> dishesData = data['data'];
        if (dishesData.isNotEmpty) {
          List<String> loadedDishes = dishesData
              .map((item) => item['dish_name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
          if (loadedDishes.isNotEmpty) {
            setState(() {
              _allDishes = loadedDishes;
              _isLoadingDishes = false;
            });
            return;
          }
        }
      }
      _loadDefaultDishes();
    } catch (e) {
      _loadDefaultDishes();
    }
  }

  void _loadDefaultDishes() {
    setState(() {
      _allDishes = [
        'Chana Masala', 'Aloo Gobi', 'Dal Tadka', 'Aloo Methi', 'Aloo Jeera',
        'Punjabi Kadhi Pakora', 'Bhindi Masala', 'Malai Kofta', 'Dal Makhani',
        'Matar Paneer', 'Kadhai Paneer', 'Shahi Paneer', 'Chilli Paneer',
        'Butter Chicken', 'Chicken Dhaiwal Korma', 'Chilli Chicken',
        'Chicken Achari Curry', 'Chicken Kadhai', 'Chicken Madras',
      ];
      _isLoadingDishes = false;
    });
  }

  List<String> get _filteredDishes {
    if (_mealType == 'both') return _allDishes;
    final vegDishes = ['Chana Masala', 'Aloo Gobi', 'Dal Tadka', 'Aloo Methi', 'Aloo Jeera', 'Punjabi Kadhi Pakora', 'Bhindi Masala', 'Malai Kofta', 'Dal Makhani', 'Matar Paneer', 'Kadhai Paneer', 'Shahi Paneer', 'Chilli Paneer'];
    final nonVegDishes = ['Butter Chicken', 'Chicken Dhaiwal Korma', 'Chilli Chicken', 'Chicken Achari Curry', 'Chicken Kadhai', 'Chicken Madras'];
    return _mealType == 'veg'
        ? _allDishes.where((d) => vegDishes.contains(d)).toList()
        : _allDishes.where((d) => nonVegDishes.contains(d)).toList();
  }

  void _toggleDishSelection(String dishName) {
    setState(() {
      if (_selectedDishes.contains(dishName)) {
        _selectedDishes.remove(dishName);
      } else if (_selectedDishes.length < _maxDishes) {
        _selectedDishes.add(dishName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only select up to $_maxDishes dishes'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
  }

  // ==============================================
  // CALCULATE TOTAL
  // ==============================================
  double _calculateTotal() {
    final itemPrice = double.tryParse(widget.menuItem['price']?.toString() ?? '0') ?? 0;
    return itemPrice + _deliveryFee;
  }

  // ==============================================
  // SUBMIT ORDER - Add to cart as normal order
  // ==============================================
  // ==============================================
// SUBMIT ORDER - Add to cart as normal order
// ==============================================
  void _submitOrder() {
    if (_selectedDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select $_maxDishes dishes'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // ✅ Enforce exactly _maxDishes dishes (not just non-empty)
    if (_selectedDishes.length != _maxDishes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select exactly $_maxDishes dishes'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!_isDeliveryAvailable && _deliveryOption == 'delivery') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deliveryUnavailableReason),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // ✅ Copy ALL original menu item fields (image_url, image_base64, image, etc.)
    final orderItem = Map<String, dynamic>.from(widget.menuItem);

    // ==============================================
    // ✅ EXPLICITLY PRESERVE IMAGE FIELDS
    // ==============================================
    // Some menu items come with 'image_url', some with only 'image',
    // some with 'image_base64'. Preserve all of them so cart can display.
    orderItem['image_url'] =
        widget.menuItem['image_url'] ??
            widget.menuItem['image'] ??
            '';

    orderItem['image_base64'] =
        widget.menuItem['image_base64'] ?? '';

    orderItem['image'] =
        widget.menuItem['image'] ??
            widget.menuItem['image_url'] ??
            '';

    // Keep original metadata
    orderItem['image_metadata'] = widget.menuItem['image_metadata'];
    orderItem['alt_text'] = widget.menuItem['alt_text'] ?? '';

    // ==============================================
    // Meal plan selections
    // ==============================================
    orderItem['selected_dishes'] = _selectedDishes;
    orderItem['meal_type'] = _mealType;
    orderItem['bread_type'] = _breadType;
    orderItem['spice_level'] = _spiceLevel;
    orderItem['special_instructions'] = _specialInstructions;
    orderItem['delivery_option'] = _deliveryOption;
    orderItem['delivery_date'] = _selectedDate.toIso8601String().split('T').first;
    orderItem['delivery_time_slot'] = _selectedTimeSlot;
    orderItem['delivery_fee'] = _deliveryFee;
    orderItem['total_price'] = _calculateTotal();
    orderItem['required_dish_count'] = _maxDishes;
    orderItem['is_meal_plan'] = true;

    // Debug log (optional — remove in production)
    debugPrint('🧾 Meal Plan Order Item:');
    debugPrint('   name: ${orderItem['name']}');
    debugPrint('   image_url: ${orderItem['image_url']}');
    debugPrint('   image_base64 length: ${orderItem['image_base64'].toString().length}');
    debugPrint('   selected_dishes: ${orderItem['selected_dishes']}');
    debugPrint('   total_price: ${orderItem['total_price']}');

    // Call the onAddToCart callback with the modified item
    widget.onAddToCart(orderItem);

    // Show success and navigate back


    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildPremiumAppBar(primaryColor),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMealPlanInfoCard(primaryColor),
                        const SizedBox(height: 20),
                        _buildMealTypeSection(primaryColor),
                        const SizedBox(height: 20),
                        _buildBreadSection(primaryColor),
                        const SizedBox(height: 20),
                        _buildSpiceSection(primaryColor),
                        const SizedBox(height: 20),
                        _buildDishSelector(primaryColor, darkColor),
                        const SizedBox(height: 20),
                        _buildDeliverySection(primaryColor, darkColor),
                        const SizedBox(height: 20),
                        _buildInstructionsSection(primaryColor, darkColor),
                        const SizedBox(height: 20),
                        _buildTotalAndSubmit(primaryColor, darkColor),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar(Color primaryColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize Meal Plan',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.restaurant, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedDishes.length} of $_maxDishes dishes selected',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$${widget.menuItem['price'] ?? '0'}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlanInfoCard(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.menuItem['name'] ?? 'Meal Plan',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select $_maxDishes dishes for your meal plan',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSection(Color primaryColor) {
    return _buildOptionSection(
      title: 'Meal Type',
      icon: Icons.restaurant_menu,
      options: _mealTypes,
      selectedValue: _mealType,
      onSelect: (value) {
        setState(() {
          _mealType = value;
          _selectedDishes = [];
        });
      },
      primaryColor: primaryColor,
    );
  }

  Widget _buildBreadSection(Color primaryColor) {
    return _buildOptionSection(
      title: 'Bread Type',
      icon: Icons.bakery_dining,
      options: _breadTypes,
      selectedValue: _breadType,
      onSelect: (value) => setState(() => _breadType = value),
      primaryColor: primaryColor,
    );
  }

  Widget _buildSpiceSection(Color primaryColor) {
    return _buildOptionSection(
      title: 'Spice Level',
      icon: Icons.local_fire_department,
      options: _spiceLevels,
      selectedValue: _spiceLevel,
      onSelect: (value) => setState(() => _spiceLevel = value),
      primaryColor: primaryColor,
    );
  }

  Widget _buildOptionSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required String selectedValue,
    required Function(String) onSelect,
    required Color primaryColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: options.map((item) {
                final isSelected = selectedValue == item['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(item['value']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? item['color'] : item['bgColor'],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? item['color'] : Colors.grey[200]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          item['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF1A202C),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishSelector(Color primaryColor, Color darkColor) {
    final filteredDishes = _filteredDishes;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.food_bank, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Your Dishes',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                        Text(
                          '${_selectedDishes.length} of $_maxDishes selected',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_selectedDishes.length == _maxDishes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'DONE',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingDishes)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filteredDishes.length,
                itemBuilder: (context, index) {
                  final dishName = filteredDishes[index];
                  final isSelected = _selectedDishes.contains(dishName);
                  final isDisabled = !isSelected && _selectedDishes.length >= _maxDishes;

                  return GestureDetector(
                    onTap: isDisabled ? null : () => _toggleDishSelection(dishName),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : (isDisabled ? Colors.grey[50] : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.grey[500]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected ? Icon(Icons.check, color: primaryColor, size: 14) : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              dishName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF1A202C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySection(Color primaryColor, Color darkColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delivery_dining, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Delivery Options',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDeliveryOption('🚚 Delivery', 'delivery', primaryColor)),
                const SizedBox(width: 12),
                Expanded(child: _buildDeliveryOption('🏪 Pickup', 'pickup', primaryColor)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTimeSlot,
              decoration: InputDecoration(
                labelText: 'Delivery Timing',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.access_time, color: primaryColor),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _timeSlots.map((slot) {
                return DropdownMenuItem(
                  value: slot,
                  child: Text(slot, style: GoogleFonts.poppins(fontSize: 13)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedTimeSlot = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOption(String label, String value, Color primaryColor) {
    final isSelected = _deliveryOption == value;
    return GestureDetector(
      onTap: () => setState(() => _deliveryOption = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF1A202C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsSection(Color primaryColor, Color darkColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.note_add, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Special Instructions',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText: 'Enter special instructions...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
              onChanged: (value) => _specialInstructions = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalAndSubmit(Color primaryColor, Color darkColor) {
    final itemPrice = double.tryParse(widget.menuItem['price']?.toString() ?? '0') ?? 0;
    final total = itemPrice + _deliveryFee;
    final canSubmit = _selectedDishes.length == _maxDishes && _isDeliveryAvailable;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Price',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                ),
                Text(
                  '\$${itemPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: darkColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Delivery Fee',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                ),
                Text(
                  _isCalculatingDeliveryFee
                      ? 'Calculating...'
                      : _isDeliveryAvailable
                      ? '\$${_deliveryFee.toStringAsFixed(2)}'
                      : 'Not Available',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isDeliveryAvailable ? primaryColor : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: darkColor),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _submitOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? primaryColor : Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(canSubmit ? Icons.shopping_cart : Icons.lock_outline, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      canSubmit ? 'Add to Cart' : 'Select ${_maxDishes - _selectedDishes.length} more dishes',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}