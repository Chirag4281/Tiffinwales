// lib/screens/subscription_order_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';

class SubscriptionOrderScreen extends StatefulWidget {
  final String locationName;
  final String userEmail;
  final String username;
  final SubscriptionPlan? selectedPlan;

  const SubscriptionOrderScreen({
    super.key,
    required this.locationName,
    required this.userEmail,
    required this.username,
    this.selectedPlan,
  });

  @override
  State<SubscriptionOrderScreen> createState() => _SubscriptionOrderScreenState();
}

class _SubscriptionOrderScreenState extends State<SubscriptionOrderScreen> with TickerProviderStateMixin {
  // Plan selection
  SubscriptionPlan? _selectedPlan;
  List<SubscriptionPlan> _plans = [];
  bool _isLoadingPlans = true;
  String? _plansError;

  // Order options
  String _mealType = 'both';
  String _breadType = 'naan';
  String _spiceLevel = 'mild';
  List<String> _selectedDishes = [];
  List<String> _allDishes = [];
  bool _isLoadingDishes = true;

  // Delivery
  String _deliveryOption = 'delivery';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '12:00PM to 1:00PM (Delivery Timing)';
  List<String> _timeSlots = [];
  String _specialInstructions = '';

  // Controllers
  final TextEditingController _instructionsController = TextEditingController();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Options with icons and colors
  final List<Map<String, dynamic>> _mealTypes = [
    {'value': 'veg', 'label': '🌱 Veg', 'icon': Icons.eco, 'color': Color(0xFF22C55E), 'bgColor': Color(0xFFDCFCE7)},
    {'value': 'nonveg', 'label': '🍗 Non-Veg', 'icon': Icons.restaurant, 'color': Color(0xFFEF4444), 'bgColor': Color(0xFFFEE2E2)},
    {'value': 'both', 'label': '🌟 Both', 'icon': Icons.food_bank, 'color': Color(0xFF8B5CF6), 'bgColor': Color(0xFFEDE9FE)},
  ];

  final List<Map<String, dynamic>> _breadTypes = [
    {'value': 'naan', 'label': '🫓 Naan', 'icon': Icons.circle, 'color': Color(0xFFF59E0B), 'bgColor': Color(0xFFFEF3C7)},
    {'value': 'roti', 'label': '🫓 Roti', 'icon': Icons.circle, 'color': Color(0xFF92400E), 'bgColor': Color(0xFFF5E6D3)},
    {'value': 'both', 'label': '🫓 Both', 'icon': Icons.circle, 'color': Color(0xFF14B8A6), 'bgColor': Color(0xFFCCFBF1)},
  ];

  final List<Map<String, dynamic>> _spiceLevels = [
    {'value': 'mild', 'label': '🌶️ Mild', 'color': Color(0xFF22C55E), 'bgColor': Color(0xFFDCFCE7)},
    {'value': 'medium', 'label': '🌶️🌶️ Medium', 'color': Color(0xFFF59E0B), 'bgColor': Color(0xFFFEF3C7)},
    {'value': 'hot', 'label': '🌶️🌶️🌶️ Hot', 'color': Color(0xFFEF4444), 'bgColor': Color(0xFFFEE2E2)},
  ];

  final Map<String, List<Color>> _planGradients = {
    '3days': [const Color(0xFF667EEA), const Color(0xFF764BA2)],
    '5days': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
    '7days': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
    '15days': [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
    '30days': [const Color(0xFFFA709A), const Color(0xFFFEE140)],
  };

  final Map<String, String> _planEmojis = {
    '3days': '🌿',
    '5days': '🔥',
    '7days': '⭐',
    '15days': '👑',
    '30days': '💎',
  };

  final String apiUrl = 'https://quantorra.co/tiffinwales/SubscriptionManager.php';

  @override
  void initState() {
    super.initState();
    _timeSlots = SubscriptionService.getDeliveryTimeSlots();
    _loadPlans();
    _loadDishesFromBackend();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

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

  Future<void> _loadPlans() async {
    setState(() {
      _isLoadingPlans = true;
      _plansError = null;
    });

    try {
      final response = await SubscriptionService.getSubscriptionPlans(
        locationName: widget.locationName,
      );

      if (response['status'] == 'success' && response['data'] != null) {
        final List<dynamic> data = response['data'];
        if (data.isNotEmpty) {
          setState(() {
            _plans = data.map((item) => SubscriptionPlan.fromBackend(item)).toList();
            _plans.sort((a, b) => a.durationDays.compareTo(b.durationDays));
            _selectInitialPlan();
            _isLoadingPlans = false;
          });
          return;
        }
      }
      setState(() {
        _isLoadingPlans = false;
        _plansError = 'No subscription plans available';
      });
    } catch (e) {
      setState(() {
        _isLoadingPlans = false;
        _plansError = 'Failed to load plans: ${e.toString()}';
      });
    }
  }

  void _selectInitialPlan() {
    if (_plans.isEmpty) {
      _selectedPlan = null;
      return;
    }
    if (widget.selectedPlan != null) {
      SubscriptionPlan? matchedPlan = _plans.firstWhere(
            (p) => p.id == widget.selectedPlan!.id,
        orElse: () => _plans.first,
      );
      if (matchedPlan.id != widget.selectedPlan!.id) {
        final typeMatch = _plans.firstWhere(
              (p) => p.planType == widget.selectedPlan!.planType,
          orElse: () => _plans.first,
        );
        matchedPlan = typeMatch;
      }
      _selectedPlan = matchedPlan;
    } else {
      _selectedPlan = _plans.first;
    }
    _selectedDishes = [];
  }

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
      await _loadDishesFromPlans();
    } catch (e) {
      await _loadDishesFromPlans();
    }
  }

  Future<void> _loadDishesFromPlans() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'get_all_plans',
          'location_name': widget.locationName,
        },
      ).timeout(const Duration(seconds: 15));

      var data = json.decode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        final List<dynamic> plansData = data['data'];
        Set<String> uniqueDishes = {};
        for (var plan in plansData) {
          if (plan['dishes'] != null && plan['dishes'] is List) {
            for (var dish in plan['dishes']) {
              if (dish is String && dish.isNotEmpty) uniqueDishes.add(dish);
            }
          }
        }
        if (uniqueDishes.isNotEmpty) {
          setState(() {
            _allDishes = uniqueDishes.toList();
            _isLoadingDishes = false;
          });
          return;
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
    final vegDishes = ['Chana Masala', 'Aloo Gobi', 'Dal Tadka', 'Aloo Methi',
      'Aloo Jeera', 'Punjabi Kadhi Pakora', 'Bhindi Masala', 'Malai Kofta',
      'Dal Makhani', 'Matar Paneer', 'Kadhai Paneer', 'Shahi Paneer', 'Chilli Paneer'];
    final nonVegDishes = ['Butter Chicken', 'Chicken Dhaiwal Korma', 'Chilli Chicken',
      'Chicken Achari Curry', 'Chicken Kadhai', 'Chicken Madras'];
    return _mealType == 'veg'
        ? _allDishes.where((d) => vegDishes.contains(d)).toList()
        : _allDishes.where((d) => nonVegDishes.contains(d)).toList();
  }

  void _toggleDishSelection(String dishName) {
    setState(() {
      final maxDishes = _selectedPlan?.maxDishes ?? 3;
      if (_selectedDishes.contains(dishName)) {
        _selectedDishes.remove(dishName);
      } else if (_selectedDishes.length < maxDishes) {
        _selectedDishes.add(dishName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only select up to $maxDishes dishes'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
  }

  double _calculateTotal() => _selectedPlan?.price ?? 0;

  void _showPlanSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    final isSelected = _selectedPlan?.id == plan.id;
                    final gradientColors = _planGradients[plan.planType] ??
                        [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
                    final emoji = _planEmojis[plan.planType] ?? '📦';

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPlan = plan;
                          _selectedDishes = [];
                        });
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          )
                              : null,
                          color: isSelected ? null : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? gradientColors[0] : Colors.grey[200]!,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: gradientColors[0].withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : gradientColors[0].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.planName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : const Color(0xFF1A202C),
                                    ),
                                  ),
                                  Text(
                                    '${plan.durationDays} Days • ${plan.maxDishes} Dishes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isSelected ? Colors.white70 : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              plan.formattedPrice,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFF6366F1),
                              ),
                            ),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a plan'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_selectedDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select ${_selectedPlan!.maxDishes} dishes'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      ),
    );

    try {
      final response = await SubscriptionService.createSubscription(
        userEmail: widget.userEmail,
        locationName: widget.locationName,
        planId: _selectedPlan!.id,
        mealType: _mealType,
        breadType: _breadType,
        spiceLevel: _spiceLevel,
        selectedDishes: _selectedDishes,
        totalPrice: _calculateTotal(),
        deliveryOption: _deliveryOption,
        deliveryDate: _selectedDate.toIso8601String().split('T').first,
        deliveryTimeSlot: _selectedTimeSlot,
        specialInstructions: _specialInstructions,
      );
      Navigator.pop(context);
      if (response['status'] == 'success') {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to create subscription'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 60),
              ),
              const SizedBox(height: 20),
              Text(
                'Subscription Created! 🎉',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${_selectedPlan!.planName} has been confirmed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            // Premium AppBar
            _buildPremiumAppBar(primaryColor),
            // Body
            Expanded(
              child: _isLoadingPlans
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : _plansError != null
                  ? _buildErrorState()
                  : _plans.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSelectedPlanCard(primaryColor, darkColor),
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
                    'Order Subscription',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.restaurant, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedDishes.length} dishes selected',
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
                '${_selectedPlan?.durationDays ?? 0}D',
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _plansError!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPlans,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Plans Available',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check back later',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPlanCard(Color primaryColor, Color darkColor) {
    if (_selectedPlan == null) return const SizedBox.shrink();
    final plan = _selectedPlan!;
    final gradientColors = _planGradients[plan.planType] ??
        [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
    final emoji = _planEmojis[plan.planType] ?? '📦';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
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
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.planName,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${plan.durationDays}D',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.maxDishes} Dishes • ${plan.formattedPrice}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _showPlanSelectionDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Change',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: gradientColors[0],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.swap_horiz, size: 16, color: gradientColors[0]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // MEAL TYPE SECTION - RADIO BUTTON STYLE
  // ==============================================
  // ==============================================
// MEAL TYPE SECTION - COMPACT VERTICAL
// ==============================================
  Widget _buildMealTypeSection(Color primaryColor) {
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
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Meal Type',
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
              children: _mealTypes.map((item) {
                final isSelected = _mealType == item['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _mealType = item['value'];
                        _selectedDishes = [];
                      });
                    },
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
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: item['color'].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item['icon'],
                            color: isSelected ? Colors.white : item['color'],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item['label'].replaceAll(' ', ''),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF1A202C),
                            ),
                          ),
                        ],
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
// BREAD TYPE SECTION - COMPACT VERTICAL
// ==============================================
  Widget _buildBreadSection(Color primaryColor) {
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
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bakery_dining, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Bread Type',
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
              children: _breadTypes.map((item) {
                final isSelected = _breadType == item['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _breadType = item['value']),
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
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: item['color'].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.circle,
                            color: isSelected ? Colors.white : item['color'],
                            size: 10,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item['label'].replaceAll(' ', ''),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF1A202C),
                            ),
                          ),
                        ],
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
// SPICE LEVEL SECTION - COMPACT VERTICAL
// ==============================================
  Widget _buildSpiceSection(Color primaryColor) {
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
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Spice Level',
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
              children: _spiceLevels.map((item) {
                final isSelected = _spiceLevel == item['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _spiceLevel = item['value']),
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
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: item['color'].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['label'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF1A202C),
                            ),
                          ),
                        ],
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
  // DISH SELECTOR - CHECKBOX STYLE
  // ==============================================
  // ==============================================
// DISH SELECTOR - PREMIUM REDESIGN (FIXED)
// ==============================================
  // ==============================================
// DISH SELECTOR - COMPLETE VERSION
// ==============================================
// ==============================================
// DISH SELECTOR - FIXED LAYOUT
// ==============================================
  Widget _buildDishSelector(Color primaryColor, Color darkColor) {
    final maxDishes = _selectedPlan?.maxDishes ?? 3;
    final filteredDishes = _filteredDishes;

    return Container(
      width: double.infinity,  // ✅ Ensure full width
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                        Row(
                          children: [
                            Text(
                              '${_selectedDishes.length} of $maxDishes selected',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedDishes.length == maxDishes
                                    ? Colors.green.shade100
                                    : primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedDishes.length == maxDishes
                                    ? 'Complete ✓'
                                    : '${maxDishes - _selectedDishes.length} left',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedDishes.length == maxDishes
                                      ? Colors.green.shade700
                                      : primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                if (_selectedDishes.length == maxDishes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.green],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
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

            const SizedBox(height: 14),

            // Progress Bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.grey[100],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    width: constraints.maxWidth *
                        (_selectedDishes.length / maxDishes).clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _selectedDishes.length == maxDishes
                            ? [Colors.green, Colors.green]
                            : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: (_selectedDishes.length == maxDishes
                              ? Colors.green
                              : const Color(0xFF6366F1)).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Content
            if (_isLoadingDishes)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
              )
            else if (filteredDishes.isEmpty)
              _buildEmptyDishState()
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dish Grid - FIXED with proper constraints
                  SizedBox(
                    width: double.infinity,
                    child: GridView.builder(
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
                        final isDisabled = !isSelected && _selectedDishes.length >= maxDishes;

                        return _buildDishTile(
                          dishName: dishName,
                          isSelected: isSelected,
                          isDisabled: isDisabled,
                          onTap: () => _toggleDishSelection(dishName),
                          primaryColor: primaryColor,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _selectedDishes.length == maxDishes
                              ? Colors.green.withOpacity(0.08)
                              : const Color(0xFF6366F1).withOpacity(0.06),
                          _selectedDishes.length == maxDishes
                              ? Colors.green.withOpacity(0.04)
                              : const Color(0xFF8B5CF6).withOpacity(0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDishes.length == maxDishes
                            ? Colors.green.withOpacity(0.2)
                            : const Color(0xFF6366F1).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                _selectedDishes.length == maxDishes
                                    ? Icons.emoji_events
                                    : Icons.restaurant,
                                color: _selectedDishes.length == maxDishes
                                    ? Colors.green.shade700
                                    : const Color(0xFF6366F1),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDishes.length == maxDishes
                                      ? '🎉 Perfect selection! Ready to order'
                                      : 'Select ${maxDishes - _selectedDishes.length} more dish${maxDishes - _selectedDishes.length > 1 ? 'es' : ''}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _selectedDishes.length == maxDishes
                                        ? Colors.green.shade700
                                        : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedDishes.length == maxDishes
                                ? Colors.green
                                : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (_selectedDishes.length == maxDishes
                                    ? Colors.green
                                    : const Color(0xFF6366F1)).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_selectedDishes.length}/$maxDishes',
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
          ],
        ),
      ),
    );
  }
  // ==============================================
// DISH TILE WIDGET - ADD THIS METHOD
// ==============================================
  Widget _buildDishTile({
    required String dishName,
    required bool isSelected,
    required bool isDisabled,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, primaryColor.withOpacity(0.85)],
          )
              : null,
          color: isSelected
              ? null
              : (isDisabled
              ? Colors.grey[50]
              : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDisabled
                ? Colors.grey[200]!
                : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : (isDisabled
              ? []
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Custom Checkbox
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                  colors: [Colors.white, Colors.white],
                )
                    : null,
                color: isSelected
                    ? Colors.white
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : (isDisabled
                      ? Colors.grey[400]!
                      : Colors.grey[500]!),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                    : null,
              ),
              child: isSelected
                  ? Icon(
                Icons.check,
                color: primaryColor,
                size: 14,
              )
                  : null,
            ),
            const SizedBox(width: 8),
            // Dish Name
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
                      : (isDisabled
                      ? Colors.grey[400]!
                      : const Color(0xFF1A202C)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Selection Indicator Dot
            if (isSelected) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// ==============================================
// EMPTY DISH STATE - ADD THIS METHOD
// ==============================================
  Widget _buildEmptyDishState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 50,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No dishes available',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try selecting a different meal type',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
  // ==============================================
  // DELIVERY SECTION
  // ==============================================
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
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
                Expanded(
                  child: _buildDeliveryOption('🚚 Delivery', 'delivery', primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDeliveryOption('🏪 Pickup', 'pickup', primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_deliveryOption == 'delivery' ? 'Delivery' : 'Pickup'} Date',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          _selectedDate.toIso8601String().split('T').first,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: darkColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(primary: primaryColor),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: Text(
                      'Change',
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTimeSlot,
              decoration: InputDecoration(
                labelText: '${_deliveryOption == 'delivery' ? 'Delivery' : 'Pickup'} Timing',
                labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
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
          gradient: isSelected
              ? LinearGradient(
            colors: [primaryColor, primaryColor.withOpacity(0.7)],
          )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.white : primaryColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1A202C),
              ),
            ),
          ],
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: _instructionsController,
                decoration: InputDecoration(
                  hintText: 'Enter special instructions...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 3,
                onChanged: (value) => _specialInstructions = value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalAndSubmit(Color primaryColor, Color darkColor) {
    final total = _calculateTotal();
    final canSubmit = _selectedPlan != null && _selectedDishes.isNotEmpty;

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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_selectedPlan?.durationDays ?? 0} Days',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: canSubmit ? 4 : 0,
                  shadowColor: canSubmit ? primaryColor.withOpacity(0.3) : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      canSubmit ? Icons.shopping_bag_outlined : Icons.lock_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      canSubmit ? 'Add to Cart' : 'Complete Selection',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canSubmit) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!canSubmit) ...[
              const SizedBox(height: 8),
              Text(
                _selectedPlan == null
                    ? 'Please select a plan first'
                    : 'Please select ${_selectedPlan!.maxDishes} dishes',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}