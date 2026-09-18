// lib/screens/meal_plan_order_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class MealPlanOrderScreen extends StatefulWidget {
  final String locationName;
  final String userEmail;
  final String username;
  final int requiredDishCount;
  final Map<String, dynamic> menuItem;
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
  String _spiceLevel = 'mild';
  List<String> _selectedDishes = [];
  List<String> _allDishes = [];
  bool _isLoadingDishes = true;
  int get _maxDishes => widget.requiredDishCount;

  // ✅ Bread allocation — how many tiffins get roti vs naan
  int _rotiTiffins = 0;
  int _naanTiffins = 0;
  bool _breadInitialized = false;
  int get _tiffinCount => widget.requiredDishCount;

  // Delivery date/time metadata (no fee)
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _specialInstructions = '';

  // Controllers
  final TextEditingController _instructionsController = TextEditingController();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // API URL
  final String apiUrl = 'https://quantorra.co/tiffinwales/SubscriptionManager.php';

  // ==============================================
  // MEAL TYPE OPTIONS
  // ==============================================
  final List<Map<String, dynamic>> _mealTypes = [
    {
      'value': 'veg',
      'label': '🌱 Veg',
      'icon': Icons.eco,
      'color': Color(0xFF22C55E),
      'bgColor': Color(0xFFDCFCE7),
    },
    {
      'value': 'nonveg',
      'label': '🍗 Non-Veg',
      'icon': Icons.restaurant,
      'color': Color(0xFFEF4444),
      'bgColor': Color(0xFFFEE2E2),
    },
    {
      'value': 'both',
      'label': '🌟 Both',
      'icon': Icons.food_bank,
      'color': Color(0xFFF97316),
      'bgColor': Color(0xFFFFEDD5),
    },
  ];

  // ==============================================
  // SPICE LEVEL OPTIONS
  // ==============================================
  final List<Map<String, dynamic>> _spiceLevels = [
    {
      'value': 'mild',
      'label': '🌶️ Mild',
      'color': Color(0xFF22C55E),
      'bgColor': Color(0xFFDCFCE7),
    },
    {
      'value': 'medium',
      'label': '🌶️🌶️ Medium',
      'color': Color(0xFFF59E0B),
      'bgColor': Color(0xFFFEF3C7),
    },
    {
      'value': 'hot',
      'label': '🌶️🌶️🌶️ Hot',
      'color': Color(0xFFEF4444),
      'bgColor': Color(0xFFFEE2E2),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDishesFromBackend();
    _initBreadAllocation();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // ==============================================
  // BREAD ALLOCATION HELPERS
  // ==============================================
  void _initBreadAllocation() {
    if (_breadInitialized) return;
    // Default: all tiffins with Roti (2 pcs each)
    _rotiTiffins = _tiffinCount;
    _naanTiffins = 0;
    _breadInitialized = true;
  }

  void _setRotiTiffins(int value) {
    if (value < 0 || value > _tiffinCount) return;
    setState(() {
      _rotiTiffins = value;
      _naanTiffins = _tiffinCount - value;
    });
  }

  void _setNaanTiffins(int value) {
    if (value < 0 || value > _tiffinCount) return;
    setState(() {
      _naanTiffins = value;
      _rotiTiffins = _tiffinCount - value;
    });
  }

  String _buildBreadSummary() {
    if (_rotiTiffins == 0 && _naanTiffins == 0) {
      return 'Select bread for your tiffins';
    }
    if (_naanTiffins == 0) {
      return '$_rotiTiffins ${_rotiTiffins == 1 ? "tiffin" : "tiffins"} '
          'with Roti (${_rotiTiffins * 2} pieces)';
    }
    if (_rotiTiffins == 0) {
      return '$_naanTiffins ${_naanTiffins == 1 ? "tiffin" : "tiffins"} '
          'with Naan (${_naanTiffins} pieces)';
    }
    return '$_rotiTiffins Roti tiffin${_rotiTiffins > 1 ? "s" : ""} '
        '(${_rotiTiffins * 2} pcs) • '
        '$_naanTiffins Naan tiffin${_naanTiffins > 1 ? "s" : ""} '
        '(${_naanTiffins} pcs)';
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
        'Chana Masala',
        'Aloo Gobi',
        'Dal Tadka',
        'Aloo Methi',
        'Aloo Jeera',
        'Punjabi Kadhi Pakora',
        'Bhindi Masala',
        'Malai Kofta',
        'Dal Makhani',
        'Matar Paneer',
        'Kadhai Paneer',
        'Shahi Paneer',
        'Chilli Paneer',
        'Butter Chicken',
        'Chicken Dhaiwal Korma',
        'Chilli Chicken',
        'Chicken Achari Curry',
        'Chicken Kadhai',
        'Chicken Madras',
      ];
      _isLoadingDishes = false;
    });
  }

  List<String> get _filteredDishes {
    if (_mealType == 'both') return _allDishes;
    final vegDishes = [
      'Chana Masala',
      'Aloo Gobi',
      'Dal Tadka',
      'Aloo Methi',
      'Aloo Jeera',
      'Punjabi Kadhi Pakora',
      'Bhindi Masala',
      'Malai Kofta',
      'Dal Makhani',
      'Matar Paneer',
      'Kadhai Paneer',
      'Shahi Paneer',
      'Chilli Paneer',
    ];
    final nonVegDishes = [
      'Butter Chicken',
      'Chicken Dhaiwal Korma',
      'Chilli Chicken',
      'Chicken Achari Curry',
      'Chicken Kadhai',
      'Chicken Madras',
    ];
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
            backgroundColor: const Color(0xFFF97316),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
  }

  // ==============================================
  // CALCULATE TOTAL (item price only — no delivery fee)
  // ==============================================
  double _calculateTotal() {
    return double.tryParse(widget.menuItem['price']?.toString() ?? '0') ?? 0;
  }

  // ==============================================
  // SUBMIT ORDER
  // ==============================================
  void _submitOrder() {
    if (_selectedDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select $_maxDishes dishes'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_selectedDishes.length != _maxDishes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select exactly $_maxDishes dishes'),
          backgroundColor: const Color(0xFFF97316),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // ✅ Validate bread allocation
    if ((_rotiTiffins + _naanTiffins) != _tiffinCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please allocate bread for all $_tiffinCount tiffins '
                '(currently ${_rotiTiffins + _naanTiffins})',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Copy ALL original menu item fields
    final orderItem = Map<String, dynamic>.from(widget.menuItem);

    // Preserve image fields
    orderItem['image_url'] =
        widget.menuItem['image_url'] ?? widget.menuItem['image'] ?? '';
    orderItem['image_base64'] = widget.menuItem['image_base64'] ?? '';
    orderItem['image'] =
        widget.menuItem['image'] ?? widget.menuItem['image_url'] ?? '';
    orderItem['image_metadata'] = widget.menuItem['image_metadata'];
    orderItem['alt_text'] = widget.menuItem['alt_text'] ?? '';

    // Meal plan selections (no delivery fee)
    orderItem['selected_dishes'] = _selectedDishes;
    orderItem['meal_type'] = _mealType;
    orderItem['spice_level'] = _spiceLevel;
    orderItem['special_instructions'] = _specialInstructions;
    orderItem['total_price'] = _calculateTotal();
    orderItem['required_dish_count'] = _maxDishes;
    orderItem['is_meal_plan'] = true;

    // ✅ Bread allocation (new)
    // ✅ Bread allocation — exact counts
    final int rotiPieces = _rotiTiffins * 2;   // 2 rotis per roti-tiffin
    final int naanPieces = _naanTiffins;       // 1 naan per naan-tiffin

    orderItem['bread_allocation'] = {
      'roti_tiffins': _rotiTiffins,
      'naan_tiffins': _naanTiffins,
      'total_tiffins': _tiffinCount,
      'roti_pieces': rotiPieces,
      'naan_pieces': naanPieces,
    };

// Human-readable summary
    orderItem['bread_summary'] = _buildBreadSummary();

// ✅ Legacy bread_type — now carries the counts so it's never ambiguous
    if (_rotiTiffins > 0 && _naanTiffins > 0) {
      orderItem['bread_type'] =
      '$rotiPieces Roti + $naanPieces Naan'; // e.g. "8 Roti + 1 Naan"
    } else if (_rotiTiffins > 0) {
      orderItem['bread_type'] =
      '$rotiPieces Roti';                   // e.g. "8 Roti"
    } else if (_naanTiffins > 0) {
      orderItem['bread_type'] =
      '$naanPieces Naan';                   // e.g. "1 Naan"
    } else {
      orderItem['bread_type'] = '';
    }

// ✅ Encode bread counts into the display name so the cart shows it too
//    Format: "5 Day Meal Plan (Dish1, Dish2, …) [4 Roti, 1 Naan]"
    final String baseName = widget.menuItem['name']?.toString() ?? 'Meal Plan';
    final String dishesPart = _selectedDishes.isEmpty
        ? ''
        : ' (${_selectedDishes.join(', ')})';
    final String breadPart = _buildBreadCartTag(); // "[4 Roti, 1 Naan]"
    orderItem['name'] = '$baseName$dishesPart $breadPart';
    orderItem['item_name'] = orderItem['name']; // convenience alias

    debugPrint('🧾 Meal Plan Order Item:');
    debugPrint('   name: ${orderItem['name']}');
    debugPrint('   image_url: ${orderItem['image_url']}');
    debugPrint(
        '   image_base64 length: ${orderItem['image_base64'].toString().length}');
    debugPrint('   selected_dishes: ${orderItem['selected_dishes']}');
    debugPrint('   bread_allocation: ${orderItem['bread_allocation']}');
    debugPrint('   bread_summary: ${orderItem['bread_summary']}');
    debugPrint('   total_price: ${orderItem['total_price']}');

    widget.onAddToCart(orderItem);
    Navigator.pop(context);
  }
  String _buildBreadCartTag() {
    final int rotiPieces = _rotiTiffins * 2;
    final int naanPieces = _naanTiffins;

    final List<String> parts = [];
    if (rotiPieces > 0) parts.add('$rotiPieces Roti');
    if (naanPieces > 0) parts.add('$naanPieces Naan');

    if (parts.isEmpty) return '';
    return '[${parts.join(', ')}]';
  }
  // ==============================================
  // BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316); // Orange
    const Color darkColor = Color(0xFF1C1C1E); // Charcoal

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
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
                        _buildMealPlanDescriptionCard(primaryColor, darkColor),
                        const SizedBox(height: 20),
                        _buildMealTypeSection(primaryColor),
                        const SizedBox(height: 20),
                        _buildBreadSection(primaryColor),
                        const SizedBox(height: 20),
                        _buildSpiceSection(primaryColor),
                        const SizedBox(height: 20),
                        _buildDishSelector(primaryColor, darkColor),
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

  // ==============================================
  // PREMIUM APP BAR
  // ==============================================
  Widget _buildPremiumAppBar(Color primaryColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
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
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
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
                      const Icon(Icons.restaurant,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedDishes.length} of $_maxDishes dishes selected',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
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

  // ==============================================
  // MEAL PLAN DESCRIPTION CARD
  // ==============================================
  Widget _buildMealPlanDescriptionCard(Color primaryColor, Color darkColor) {
    final String description = widget.menuItem['description']?.toString() ?? '';
    final String name = widget.menuItem['name']?.toString() ?? 'Meal Plan';
    final String category = widget.menuItem['category']?.toString() ?? '';
    final double price =
        double.tryParse(widget.menuItem['price']?.toString() ?? '0') ?? 0;

    if (description.isEmpty && name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
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
        border: Border.all(
          color: const Color(0xFFF97316).withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: darkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),

            // Description Box
            if (description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: primaryColor.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'About This Meal Plan',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor.withOpacity(0.9),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Progress Row
            const SizedBox(height: 14),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.08),
                    const Color(0xFFEA580C).withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose $_maxDishes dishes to complete your meal plan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: darkColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedDishes.length == _maxDishes
                          ? Colors.green
                          : primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedDishes.length}/$_maxDishes',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  // ==============================================
  // MEAL TYPE SECTION
  // ==============================================
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

  // ==============================================
  // BREAD SECTION — PER-TIFFIN SPLITTER
  // ==============================================
  Widget _buildBreadSection(Color primaryColor) {
    _initBreadAllocation();

    final bool isSingleTiffin = _tiffinCount == 1;
    final String summary = _buildBreadSummary();
    final bool isComplete = (_rotiTiffins + _naanTiffins) == _tiffinCount;

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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bakery_dining,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bread Selection',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      Text(
                        isSingleTiffin
                            ? '1 tiffin • Choose Roti (2 pcs) or Naan (1 pc)'
                            : '$_tiffinCount tiffins • Choose bread for each',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Roti row
            _buildBreadRow(
              emoji: '🫓',
              label: 'Roti',
              subtitle: '2 pieces per tiffin',
              color: const Color(0xFF92400E),
              bgColor: const Color(0xFFF5E6D3),
              count: _rotiTiffins,
              onDecrement: _rotiTiffins > 0
                  ? () => _setRotiTiffins(_rotiTiffins - 1)
                  : null,
              onIncrement: _rotiTiffins < _tiffinCount
                  ? () => _setRotiTiffins(_rotiTiffins + 1)
                  : null,
            ),

            const SizedBox(height: 10),

            // Naan row
            _buildBreadRow(
              emoji: '🫓',
              label: 'Naan',
              subtitle: '1 piece per tiffin',
              color: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFEF3C7),
              count: _naanTiffins,
              onDecrement: _naanTiffins > 0
                  ? () => _setNaanTiffins(_naanTiffins - 1)
                  : null,
              onIncrement: _naanTiffins < _tiffinCount
                  ? () => _setNaanTiffins(_naanTiffins + 1)
                  : null,
            ),

            const SizedBox(height: 14),

            // Summary strip
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.08),
                    const Color(0xFFEA580C).withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isComplete
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 18,
                    color: isComplete
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1C1C1E),
                        height: 1.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isComplete ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_rotiTiffins + _naanTiffins}/$_tiffinCount',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  // ==============================================
  // SINGLE BREAD ROW (stepper)
  // ==============================================
  Widget _buildBreadRow({
    required String emoji,
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required int count,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    final bool isSelected = count > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? bgColor : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? color.withOpacity(0.4) : Colors.grey[200]!,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Emoji badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),

          // Label + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : const Color(0xFF1C1C1E),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Stepper
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                isSelected ? color.withOpacity(0.4) : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepButton(
                  icon: Icons.remove_rounded,
                  onTap: onDecrement,
                  color: color,
                ),
                Container(
                  width: 44,
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.grey[400],
                    ),
                  ),
                ),
                _buildStepButton(
                  icon: Icons.add_rounded,
                  onTap: onIncrement,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? color : Colors.grey[300],
        ),
      ),
    );
  }

  // ==============================================
  // SPICE SECTION
  // ==============================================
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

  // ==============================================
  // GENERIC OPTION SECTION
  // ==============================================
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
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
                    color: const Color(0xFF1C1C1E),
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
                          color:
                          isSelected ? item['color'] : Colors.grey[200]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          item['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
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

  // ==============================================
  // DISH SELECTOR
  // ==============================================
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.food_bank,
                          color: Colors.white, size: 20),
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
                            color: const Color(0xFF1C1C1E),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 14),
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
                  child: CircularProgressIndicator(color: Color(0xFFF97316)),
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
                  final isDisabled =
                      !isSelected && _selectedDishes.length >= _maxDishes;

                  return GestureDetector(
                    onTap: isDisabled
                        ? null
                        : () => _toggleDishSelection(dishName),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor
                            : (isDisabled ? Colors.grey[50] : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                          isSelected ? primaryColor : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[500]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Icon(Icons.check,
                                color: primaryColor, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              dishName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1C1C1E),
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

  // ==============================================
  // INSTRUCTIONS SECTION
  // ==============================================
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.note_add,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Special Instructions',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText: 'Enter special instructions...',
                hintStyle:
                GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
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

  // ==============================================
  // TOTAL & SUBMIT (no delivery fee)
  // ==============================================
  Widget _buildTotalAndSubmit(Color primaryColor, Color darkColor) {
    final itemPrice =
        double.tryParse(widget.menuItem['price']?.toString() ?? '0') ?? 0;
    final total = itemPrice;
    final canSubmit = _selectedDishes.length == _maxDishes &&
        (_rotiTiffins + _naanTiffins) == _tiffinCount;

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
                  style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                ),
                Text(
                  '\$${itemPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkColor,
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
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: darkColor,
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(canSubmit ? Icons.shopping_cart : Icons.lock_outline,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(
                      canSubmit
                          ? 'Add to Cart'
                          : 'Select ${_maxDishes - _selectedDishes.length} more dishes',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700),
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