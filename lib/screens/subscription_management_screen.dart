// lib/screens/manager/subscription_management_screen.dart
// PROFESSIONAL UI/UX - NO APPBAR

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../models/subscription_models.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  final String locationName;
  final String email;

  const SubscriptionManagementScreen({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  List<SubscriptionPlanFull> _plans = [];
  List<String> _customDishes = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAdding = false;
  String _searchQuery = '';

  // Image picker
  File? _selectedImage;
  String? _imageBase64;
  final ImagePicker _picker = ImagePicker();

  // API URL
  final String apiUrl = 'https://quantorra.co/tiffinwales/SubscriptionManager.php';

  // Plan types
  final List<Map<String, dynamic>> _planTypes = [
    {'type': '3days', 'label': '3 Days', 'days': 3, 'dishes': 3, 'price': 44.97, 'icon': '🌿', 'color': Color(0xFF6366F1), 'gradient': [Color(0xFF6366F1), Color(0xFF8B5CF6)], 'description': 'Perfect for weekend getaways'},
    {'type': '5days', 'label': '5 Days', 'days': 5, 'dishes': 5, 'price': 74.95, 'icon': '🔥', 'color': Color(0xFFF093FB), 'gradient': [Color(0xFFF093FB), Color(0xFFF5576C)], 'description': 'Great for work weeks'},
    {'type': '7days', 'label': '7 Days', 'days': 7, 'dishes': 7, 'price': 99.99, 'icon': '⭐', 'color': Color(0xFF4FACFE), 'gradient': [Color(0xFF4FACFE), Color(0xFF00F2FE)], 'description': 'Full week of delicious meals'},
    {'type': '15days', 'label': '15 Days', 'days': 15, 'dishes': 15, 'price': 179.99, 'icon': '👑', 'color': Color(0xFF43E97B), 'gradient': [Color(0xFF43E97B), Color(0xFF38F9D7)], 'description': 'Half month premium plan'},
    {'type': '30days', 'label': '30 Days', 'days': 30, 'dishes': 30, 'price': 329.99, 'icon': '💎', 'color': Color(0xFFFA709A), 'gradient': [Color(0xFFFA709A), Color(0xFFFEE140)], 'description': 'Ultimate monthly feast'},
    {'type': 'custom', 'label': '✨ Custom', 'days': 0, 'dishes': 0, 'price': 0, 'icon': '🎯', 'color': Color(0xFFFF6B6B), 'gradient': [Color(0xFFFF6B6B), Color(0xFFFF8E53)], 'description': 'Build your own plan'},
  ];

  // Dish options with categories
  final Map<String, List<String>> _dishCategories = {
    '🌱 Vegetarian': [
      'Chana Masala', 'Aloo Gobi', 'Dal Tadka', 'Aloo Methi', 'Aloo Jeera',
      'Punjabi Kadhi Pakora', 'Bhindi Masala', 'Malai Kofta', 'Dal Makhani',
      'Matar Paneer', 'Kadhai Paneer', 'Shahi Paneer', 'Chilli Paneer',
    ],
    '🍗 Non-Vegetarian': [
      'Butter Chicken', 'Chicken Dhaiwal Korma', 'Chilli Chicken',
      'Chicken Achari Curry', 'Chicken Kadhai', 'Chicken Madras',
    ],
  };

  String _selectedCategory = '🌱 Vegetarian';

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _animationController.forward();
    _loadPlans();
    _loadCustomDishes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<String> get _allDishes {
    final all = <String>[];
    _dishCategories.values.forEach((list) => all.addAll(list));
    all.addAll(_customDishes);
    return all;
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'get_all_plans',
          'location_name': widget.locationName,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var data = json.decode(response.body);

      if (data['status'] == 'success') {
        final List<dynamic> plansData = data['data'] ?? [];
        setState(() {
          _plans = plansData.map((item) => SubscriptionPlanFull.fromJson(item)).toList();
          _plans.sort((a, b) => a.durationDays.compareTo(b.durationDays));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load plans';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomDishes() async {
    setState(() {
      _customDishes = [
        'Paneer Tikka Masala',
        'Mushroom Curry',
        'Soya Chaap',
        'Veg Biryani',
        'Chicken Biryani',
        'Fish Curry',
        'Egg Curry',
      ];
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        setState(() {
          _selectedImage = File(image.path);
          _imageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addCustomDish(String dishName) {
    if (dishName.trim().isNotEmpty && !_customDishes.contains(dishName.trim())) {
      setState(() {
        _customDishes.add(dishName.trim());
      });
    }
  }

  // ==================== CREATE/EDIT PLAN DIALOG ====================
  void _showAddEditPlanDialog({SubscriptionPlanFull? existingPlan}) {
    final bool isEditing = existingPlan != null;

    final TextEditingController nameController = TextEditingController(
      text: isEditing ? existingPlan.planName : '',
    );
    final TextEditingController descController = TextEditingController(
      text: isEditing ? existingPlan.description : '',
    );
    final TextEditingController priceController = TextEditingController(
      text: isEditing ? existingPlan.price.toString() : '',
    );
    final TextEditingController daysController = TextEditingController();
    final TextEditingController dishesCountController = TextEditingController();

    String selectedPlanType = isEditing ? existingPlan.planType : '3days';
    String selectedImageBase64 = isEditing ? existingPlan.imageBase64 ?? '' : '';
    List<String> selectedDishes = isEditing ? List.from(existingPlan.dishes) : [];
    String selectedCategory = _selectedCategory;
    bool isCustomPlan = selectedPlanType == 'custom';

    _selectedImage = null;
    _imageBase64 = null;

    if (isEditing && selectedPlanType == 'custom') {
      daysController.text = existingPlan.durationDays.toString();
      dishesCountController.text = existingPlan.maxDishes.toString();
    }

    TextEditingController customDishController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.94,
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================== GLASS HEADER ====================
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isCustomPlan
                                  ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                                  : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: (isCustomPlan ? const Color(0xFFFF6B6B) : const Color(0xFF6366F1)).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  isEditing ? Icons.edit : Icons.add,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEditing ? 'Edit Plan' : 'Create New Plan',
                                      style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      isEditing
                                          ? 'Update your subscription plan'
                                          : 'Add a new subscription plan',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ==================== BODY ====================
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                // Image Upload - Glass Style
                                GestureDetector(
                                  onTap: () async {
                                    await _pickImage();
                                    if (_imageBase64 != null) {
                                      setStateDialog(() {
                                        selectedImageBase64 = _imageBase64!;
                                      });
                                    }
                                  },
                                  child: Container(
                                    height: 160,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.5),
                                          Colors.white.withOpacity(0.2),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: selectedImageBase64.isNotEmpty
                                            ? const Color(0xFF6366F1).withOpacity(0.5)
                                            : Colors.white.withOpacity(0.3),
                                        width: selectedImageBase64.isNotEmpty ? 2 : 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: selectedImageBase64.isNotEmpty
                                        ? ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(
                                            base64Decode(selectedImageBase64),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(Icons.broken_image, size: 50);
                                            },
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black.withOpacity(0.6),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                            child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.5),
                                                    borderRadius: BorderRadius.circular(14),
                                                    border: Border.all(
                                                      color: Colors.white.withOpacity(0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.edit, color: Colors.white, size: 18),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Change Image',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
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
                                    )
                                        : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF6366F1).withOpacity(0.1),
                                                const Color(0xFF8B5CF6).withOpacity(0.1),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF6366F1).withOpacity(0.2),
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.add_photo_alternate,
                                            size: 40,
                                            color: const Color(0xFF6366F1),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Tap to upload image',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF1A202C),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'JPG, PNG • Max 800x800',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[400],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ==================== PLAN TYPE SELECTION ====================
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Plan Type',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A202C),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ..._planTypes.map((type) {
                                      final isSelected = selectedPlanType == type['type'];
                                      final isCustom = type['type'] == 'custom';
                                      final gradientColors = type['gradient'] as List<Color>;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: GestureDetector(
                                          onTap: () {
                                            setStateDialog(() {
                                              selectedPlanType = type['type'];
                                              if (!isCustom) {
                                                final planType = _planTypes.firstWhere((t) => t['type'] == type['type']);
                                                priceController.text = planType['price'].toString();
                                              } else {
                                                priceController.text = '';
                                              }
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOutCubic,
                                            decoration: BoxDecoration(
                                              gradient: isSelected
                                                  ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: gradientColors,
                                              )
                                                  : LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withOpacity(0.8),
                                                  Colors.white.withOpacity(0.5),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.transparent
                                                    : Colors.white.withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                BoxShadow(
                                                  color: (gradientColors[0]).withOpacity(0.3),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ]
                                                  : [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.04),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ListTile(
                                              leading: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white.withOpacity(0.2)
                                                      : gradientColors[0].withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? Colors.white.withOpacity(0.3)
                                                        : gradientColors[0].withOpacity(0.2),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  type['icon'],
                                                  style: const TextStyle(fontSize: 28),
                                                ),
                                              ),
                                              title: Text(
                                                type['label'],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                  color: isSelected ? Colors.white : const Color(0xFF1A202C),
                                                ),
                                              ),
                                              subtitle: Text(
                                                type['description'] ?? '',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: isSelected
                                                      ? Colors.white.withOpacity(0.8)
                                                      : Colors.grey[500],
                                                ),
                                              ),
                                              trailing: isSelected
                                                  ? Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  isCustom ? Icons.star : Icons.check,
                                                  color: gradientColors[0],
                                                  size: 18,
                                                ),
                                              )
                                                  : null,
                                              tileColor: Colors.transparent,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // ==================== PLAN DETAILS ====================
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.6),
                                        Colors.white.withOpacity(0.3),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      _buildGlassTextField(
                                        controller: nameController,
                                        label: 'Plan Name *',
                                        hint: 'e.g., 3 Days Meal Plan',
                                        icon: Icons.title,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildGlassTextField(
                                        controller: descController,
                                        label: 'Description',
                                        hint: 'Brief description of the plan',
                                        icon: Icons.description,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildGlassTextField(
                                        controller: priceController,
                                        label: 'Price *',
                                        hint: '0.00',
                                        icon: Icons.attach_money,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ==================== CUSTOM PLAN FIELDS ====================
                                if (isCustomPlan)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFFFF6B6B).withOpacity(0.1),
                                          const Color(0xFFFF8E53).withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
                                                ),
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.star, color: Colors.white, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Custom Plan Settings',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFFF6B6B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildGlassTextField(
                                                controller: daysController,
                                                label: 'Duration (Days) *',
                                                hint: 'e.g., 10',
                                                icon: Icons.calendar_today,
                                                keyboardType: TextInputType.number,
                                                customColor: const Color(0xFFFF6B6B),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _buildGlassTextField(
                                                controller: dishesCountController,
                                                label: 'Max Dishes *',
                                                hint: 'e.g., 10',
                                                icon: Icons.restaurant,
                                                keyboardType: TextInputType.number,
                                                customColor: const Color(0xFFFF6B6B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                // ==================== DISHES SECTION ====================
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.6),
                                        Colors.white.withOpacity(0.3),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.food_bank,
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
                                                  'Select Dishes',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF1A202C),
                                                  ),
                                                ),
                                                Text(
                                                  '${selectedDishes.length} dishes selected',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: const Color(0xFF6366F1),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Add Custom Dish - Glass Style
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withOpacity(0.5),
                                              Colors.white.withOpacity(0.2),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: customDishController,
                                                style: GoogleFonts.poppins(fontSize: 14),
                                                decoration: InputDecoration(
                                                  hintText: 'Add custom dish...',
                                                  hintStyle: GoogleFonts.poppins(
                                                    color: Colors.grey[400],
                                                    fontSize: 13,
                                                  ),
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                  prefixIcon: Icon(
                                                    Icons.add_circle_outline,
                                                    color: const Color(0xFFFF6B6B),
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              margin: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                                ),
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: IconButton(
                                                onPressed: () {
                                                  if (customDishController.text.isNotEmpty) {
                                                    final newDish = customDishController.text.trim();
                                                    if (!_customDishes.contains(newDish)) {
                                                      setState(() {
                                                        _customDishes.add(newDish);
                                                      });
                                                      if (!selectedDishes.contains(newDish)) {
                                                        selectedDishes.add(newDish);
                                                      }
                                                      customDishController.clear();
                                                      setStateDialog(() {});
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Added "$newDish"'),
                                                          backgroundColor: Colors.green,
                                                          behavior: SnackBarBehavior.floating,
                                                          duration: const Duration(seconds: 1),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                                icon: const Icon(Icons.add, color: Colors.white),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Category Tabs - Glass Style
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withOpacity(0.4),
                                              Colors.white.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          child: Row(
                                            children: [
                                              ..._dishCategories.keys.map((category) {
                                                final isSelected = selectedCategory == category;
                                                return Padding(
                                                  padding: const EdgeInsets.all(4),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setStateDialog(() {
                                                        selectedCategory = category;
                                                        _selectedCategory = category;
                                                      });
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 300),
                                                      curve: Curves.easeOutCubic,
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        gradient: isSelected
                                                            ? const LinearGradient(
                                                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                                        )
                                                            : null,
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? Colors.transparent
                                                              : Colors.white.withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                        boxShadow: isSelected
                                                            ? [
                                                          BoxShadow(
                                                            color: const Color(0xFF6366F1).withOpacity(0.3),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 4),
                                                          ),
                                                        ]
                                                            : [],
                                                      ),
                                                      child: Text(
                                                        category,
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 13,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                          color: isSelected ? Colors.white : Colors.grey[700],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                              // Custom Dishes Tab
                                              Padding(
                                                padding: const EdgeInsets.all(4),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setStateDialog(() {
                                                      selectedCategory = '⭐ Custom';
                                                    });
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeOutCubic,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      gradient: selectedCategory == '⭐ Custom'
                                                          ? const LinearGradient(
                                                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                                      )
                                                          : null,
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: selectedCategory == '⭐ Custom'
                                                            ? Colors.transparent
                                                            : Colors.white.withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                      boxShadow: selectedCategory == '⭐ Custom'
                                                          ? [
                                                        BoxShadow(
                                                          color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ]
                                                          : [],
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.star,
                                                          size: 16,
                                                          color: selectedCategory == '⭐ Custom'
                                                              ? Colors.white
                                                              : const Color(0xFFFF6B6B),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Custom (${_customDishes.length})',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 13,
                                                            fontWeight: selectedCategory == '⭐ Custom'
                                                                ? FontWeight.w600
                                                                : FontWeight.w500,
                                                            color: selectedCategory == '⭐ Custom'
                                                                ? Colors.white
                                                                : Colors.grey[700],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Dish Chips - Glass Style
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: (selectedCategory == '⭐ Custom'
                                            ? _customDishes
                                            : (_dishCategories[selectedCategory] ?? []))
                                            .map((dish) {
                                          final isSelected = selectedDishes.contains(dish);
                                          final isCustom = selectedCategory == '⭐ Custom';
                                          return AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOutCubic,
                                            child: FilterChip(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isCustom) ...[
                                                    Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color: isSelected ? Colors.white : const Color(0xFFFF6B6B),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Text(
                                                    dish,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setStateDialog(() {
                                                  if (selected) {
                                                    selectedDishes.add(dish);
                                                  } else {
                                                    selectedDishes.remove(dish);
                                                  }
                                                });
                                              },
                                              selectedColor: isCustom ? const Color(0xFFFF6B6B) : const Color(0xFF6366F1),
                                              backgroundColor: Colors.white.withOpacity(0.5),
                                              checkmarkColor: Colors.white,
                                              side: BorderSide(
                                                color: isSelected
                                                    ? (isCustom ? const Color(0xFFFF6B6B) : const Color(0xFF6366F1))
                                                    : Colors.white.withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: isSelected ? 4 : 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),

                        // ==================== ACTION BUTTONS ====================
                        Container(
                          padding: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.white.withOpacity(0.3),
                                    foregroundColor: Colors.grey[600],
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isCustomPlan
                                          ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                                          : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isCustomPlan ? const Color(0xFFFF6B6B) : const Color(0xFF6366F1)).withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      // Validation
                                      if (nameController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter plan name'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }
                                      if (priceController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter price'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }
                                      if (isCustomPlan) {
                                        if (daysController.text.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please enter duration'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }
                                        if (dishesCountController.text.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please enter max dishes'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }
                                      }

                                      Navigator.pop(context);
                                      await _savePlanToServer(
                                        id: isEditing ? existingPlan!.id : 0,
                                        planType: selectedPlanType,
                                        planName: nameController.text.trim(),
                                        description: descController.text.trim(),
                                        price: double.tryParse(priceController.text) ?? 0,
                                        durationDays: isCustomPlan
                                            ? int.tryParse(daysController.text) ?? 0
                                            : _planTypes.firstWhere((t) => t['type'] == selectedPlanType)['days'],
                                        maxDishes: isCustomPlan
                                            ? int.tryParse(dishesCountController.text) ?? 0
                                            : _planTypes.firstWhere((t) => t['type'] == selectedPlanType)['dishes'],
                                        imageBase64: selectedImageBase64,
                                        dishes: selectedDishes,
                                        isEditing: isEditing,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isEditing ? Icons.check : Icons.add,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isEditing ? 'Update Plan' : 'Create Plan',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== GLASS TEXT FIELD ====================
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Color customColor = const Color(0xFF6366F1),
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF1A202C)),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: customColor),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ==================== SAVE PLAN ====================
  Future<void> _savePlanToServer({
    required int id,
    required String planType,
    required String planName,
    required String description,
    required double price,
    required int durationDays,
    required int maxDishes,
    required String imageBase64,
    required List<String> dishes,
    required bool isEditing,
  }) async {
    setState(() => _isAdding = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'add_plan',
          'location_name': widget.locationName,
          'plan_type': planType,
          'plan_name': planName,
          'description': description,
          'price': price.toString(),
          'duration_days': durationDays.toString(),
          'max_dishes': maxDishes.toString(),
          'image_base64': imageBase64,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var data = json.decode(response.body);

      if (data['status'] == 'success') {
        if (dishes.isNotEmpty) {
          final planId = isEditing ? id : data['data']['id'];
          await _updatePlanDishes(planId, dishes);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(isEditing ? Icons.edit : Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isEditing ? 'Plan updated successfully!' : 'Plan added successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadPlans();
      } else {
        throw Exception(data['message'] ?? 'Failed to save plan');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _updatePlanDishes(int planId, List<String> dishes) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'update_plan_dishes',
          'plan_id': planId.toString(),
          'dishes': jsonEncode(dishes),
        },
      );

      var data = json.decode(response.body);
      if (data['status'] != 'success') {
        print('Failed to update dishes: ${data['message']}');
      }
    } catch (e) {
      print('Error updating dishes: $e');
    }
  }

  // ==================== DELETE PLAN ====================
  Future<void> _deletePlan(int planId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 14),
            Text(
              'Delete Plan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${_plans.firstWhere((p) => p.id == planId).planName}"? This action cannot be undone.',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isAdding = true);

              try {
                final response = await http.post(
                  Uri.parse(apiUrl),
                  body: {
                    'action': 'delete_plan',
                    'plan_id': planId.toString(),
                  },
                );

                var data = json.decode(response.body);

                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Plan deleted successfully!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _loadPlans();
                } else {
                  throw Exception(data['message'] ?? 'Failed to delete plan');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                setState(() => _isAdding = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);
    const Color bgColor = Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ==================== HEADER SECTION ====================

          // ==================== BODY ====================
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                strokeWidth: 3,
              ),
            )
                : _errorMessage != null
                ? _buildErrorState()
                : _plans.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadPlans,
              color: primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _plans.where((plan) =>
                    plan.planName.toLowerCase().contains(_searchQuery)).length,
                itemBuilder: (context, index) {
                  final filteredPlans = _plans.where((plan) =>
                      plan.planName.toLowerCase().contains(_searchQuery)).toList();
                  final plan = filteredPlans[index];
                  return _buildGlassPlanCard(plan);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditPlanDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'New Plan',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== GLASS PLAN CARD ====================
  Widget _buildGlassPlanCard(SubscriptionPlanFull plan) {
    final Map<String, dynamic> planTypeData = _planTypes.firstWhere(
          (t) => t['type'] == plan.planType,
      orElse: () => _planTypes[0],
    );
    final List<Color> gradientColors = planTypeData['gradient'] ?? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
    final bool isCustom = plan.planType == 'custom';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: gradientColors[0].withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Card Header with gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        planTypeData['icon'] ?? '📦',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan.planName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (isCustom) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '⭐ CUSTOM',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            plan.description.isNotEmpty
                                ? plan.description
                                : '${plan.durationDays} Days • ${plan.maxDishes} Dishes',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                            onPressed: () => _showAddEditPlanDialog(existingPlan: plan),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                            onPressed: () => _deletePlan(plan.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildGlassDetailItem(
                          icon: Icons.calendar_today,
                          label: 'Duration',
                          value: '${plan.durationDays} Days',
                          color: gradientColors[0],
                        ),
                        _buildGlassDetailItem(
                          icon: Icons.restaurant,
                          label: 'Dishes',
                          value: '${plan.maxDishes} Items',
                          color: gradientColors[1],
                        ),
                        _buildGlassDetailItem(
                          icon: Icons.attach_money,
                          label: 'Price',
                          value: plan.formattedPrice,
                          color: gradientColors[0],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (plan.dishes.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Included Dishes:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: plan.dishes.take(5).map((dish) {
                          final isCustomDish = _customDishes.contains(dish);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCustomDish
                                    ? [const Color(0xFFFF6B6B).withOpacity(0.1), const Color(0xFFFF8E53).withOpacity(0.1)]
                                    : [const Color(0xFF6366F1).withOpacity(0.1), const Color(0xFF8B5CF6).withOpacity(0.1)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCustomDish
                                    ? const Color(0xFFFF6B6B).withOpacity(0.2)
                                    : const Color(0xFF6366F1).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCustomDish)
                                  const Icon(
                                    Icons.star,
                                    size: 10,
                                    color: Color(0xFFFF6B6B),
                                  ),
                                if (isCustomDish) const SizedBox(width: 4),
                                Text(
                                  dish,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: isCustomDish
                                        ? const Color(0xFFFF6B6B)
                                        : const Color(0xFF6366F1),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (plan.dishes.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${plan.dishes.length - 5} more dishes',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A202C),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            'Oops! Something went wrong',
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
              _errorMessage!,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.08),
                  const Color(0xFF8B5CF6).withOpacity(0.08),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.subscriptions,
              size: 80,
              color: const Color(0xFF6366F1).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Subscription Plans',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get started by creating your first plan',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditPlanDialog(),
              icon: const Icon(Icons.add),
              label: Text(
                'Create Plan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}