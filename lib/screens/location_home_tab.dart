// location_home_tab.dart - IMAGE CACHING FIX

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiffinwales/screens/subscription_list_screen.dart';
import 'home_screen.dart';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_order_screen.dart';

// Cache manager for images

class LocationHomeTab extends StatefulWidget {
  final String locationName;
  final String username;
  final String email;
  final String? deliveryAddress;
  final VoidCallback onAddAddress;
  final List<Map<String, dynamic>> featuredDishes;
  final List<Map<String, dynamic>> menuItems;
  final Function(Map<String, dynamic>) onAddToCart;

  const LocationHomeTab({
    super.key,
    required this.locationName,
    required this.username,
    required this.email,
    this.deliveryAddress,
    required this.onAddAddress,
    required this.featuredDishes,
    required this.menuItems,
    required this.onAddToCart,
  });

  @override
  State<LocationHomeTab> createState() => _LocationHomeTabState();
}

class _LocationHomeTabState extends State<LocationHomeTab>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMenuItems = [];
  bool _isSearching = false;
  late AnimationController _animationController;
  late PageController _pageController;
  int _currentPage = 0;
  late Timer _timer;

  // Subscription plans from backend
  List<SubscriptionPlan> _subscriptionPlans = [];
  bool _isLoadingPlans = true;
  String? _plansError;

  // Image cache map to prevent reloading
  final Map<String, Uint8List> _imageCache = {};
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredMenuItems = widget.menuItems;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();

    _searchController.addListener(_filterMenuItems);

    _pageController = PageController(viewportFraction: 0.85);
    _loadSubscriptionPlans();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMenuItems);
    _searchController.dispose();
    _animationController.dispose();
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ==============================================
  // LOAD SUBSCRIPTION PLANS FROM BACKEND
  // ==============================================
  Future<void> _loadSubscriptionPlans() async {
    setState(() {
      _isLoadingPlans = true;
      _plansError = null;
    });

    try {
      final response = await SubscriptionService.getSubscriptionPlans(
        locationName: widget.locationName,
      );
      print('🔍 Loading plans for location: ${widget.locationName}');

      if (response['status'] == 'success' && response['data'] != null) {
        final List<dynamic> data = response['data'];
        if (data.isNotEmpty) {
          final List<SubscriptionPlan> loadedPlans = data.map((item) {
            return SubscriptionPlan.fromBackend(item);
          }).toList();

          loadedPlans.sort((a, b) => a.durationDays.compareTo(b.durationDays));

          // Pre-cache images
          for (var plan in loadedPlans) {
            if (plan.hasImage && plan.imageBase64 != null) {
              try {
                final bytes = base64Decode(plan.imageBase64!);
                _imageCache[plan.id.toString()] = bytes;
              } catch (e) {
                // Ignore decode errors
              }
            }
          }

          setState(() {
            _subscriptionPlans = loadedPlans;
            _isLoadingPlans = false;
          });
          return;
        }
      }

      setState(() {
        _subscriptionPlans = [];
        _isLoadingPlans = false;
        if (response['message'] != null) {
          _plansError = response['message'];
        }
      });
    } catch (e) {
      setState(() {
        _subscriptionPlans = [];
        _isLoadingPlans = false;
        _plansError = 'Failed to load subscription plans: ${e.toString()}';
      });
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_subscriptionPlans.isEmpty) return;
      if (_currentPage < _subscriptionPlans.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _filterMenuItems() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredMenuItems = widget.menuItems;
        _isSearching = false;
      } else {
        _filteredMenuItems = widget.menuItems.where((item) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          final description = (item['description'] ?? '').toString().toLowerCase();
          return name.contains(query) || description.contains(query);
        }).toList();
        _isSearching = true;
      }
    });
  }

  void _navigateToSubscriptionOrder(SubscriptionPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionOrderScreen(
          locationName: widget.locationName,
          userEmail: widget.email,
          username: widget.username,
          selectedPlan: plan,
        ),
      ),
    );
  }

  void _navigateToSubscriptionList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionListScreen(
          locationName: widget.locationName,
          userEmail: widget.email,
          username: widget.username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color lightPurple = Color(0xFFEEF2FF);
    const Color darkColor = Color(0xFF1A202C);
    const Color lightBg = Color(0xFFF7FAFC);

    return Scaffold(
      backgroundColor: lightBg,
      body: CustomScrollView(
        slivers: [
          _buildHeader(darkColor, primaryColor),
          _buildSearchBar(primaryColor),
          if (!_isSearching) _buildSubscriptionPlansSection(primaryColor),
          _buildMenuHeader(darkColor),
          _buildMenuGrid(primaryColor, lightPurple),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ==============================================
  // HEADER
  // ==============================================
  Widget _buildHeader(Color darkColor, Color primaryColor) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Good ${_getTimeOfDay()}!",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[500],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.username,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: widget.onAddAddress,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.deliveryAddress != null &&
                                widget.deliveryAddress!.isNotEmpty
                                ? widget.deliveryAddress!
                                : 'Add delivery address',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      email: widget.email,
                      username: widget.username,
                      locationName: widget.locationName,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // SEARCH BAR
  // ==============================================
  Widget _buildSearchBar(Color primaryColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search for delicious food...",
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: primaryColor,
                size: 24,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: () {
                  _searchController.clear();
                },
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // SUBSCRIPTION PLANS SECTION
  // ==============================================
  Widget _buildSubscriptionPlansSection(Color primaryColor) {
    if (_isLoadingPlans) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading subscription plans...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_subscriptionPlans.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.subscriptions_outlined,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  _plansError ?? 'No subscription plans available',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadSubscriptionPlans,
                  child: Text(
                    'Retry',
                    style: GoogleFonts.poppins(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📋 Subscription Plans",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                GestureDetector(
                  onTap: _navigateToSubscriptionList,
                  child: Text(
                    "See All",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 380,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: _subscriptionPlans.length,
              itemBuilder: (context, index) {
                final plan = _subscriptionPlans[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSubscriptionCard(plan, primaryColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // SUBSCRIPTION CARD - WITH CACHED IMAGES
  // ==============================================
  Widget _buildSubscriptionCard(SubscriptionPlan plan, Color primaryColor) {
    final Map<String, List<Color>> planGradients = {
      '3days': [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      '5days': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      '7days': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      '15days': [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      '30days': [const Color(0xFFFA709A), const Color(0xFFFEE140)],
    };

    final List<Color> gradientColors = planGradients[plan.planType] ??
        [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];

    final bool hasImage = plan.hasImage;

    final Map<String, String> planEmojis = {
      '3days': '🌿',
      '5days': '🔥',
      '7days': '⭐',
      '15days': '👑',
      '30days': '💎',
    };
    final String emoji = planEmojis[plan.planType] ?? '📦';

    // Get cached image bytes
    Uint8List? cachedImage;
    if (hasImage && plan.imageBase64 != null) {
      try {
        // Check cache first
        if (_imageCache.containsKey(plan.id.toString())) {
          cachedImage = _imageCache[plan.id.toString()];
        } else {
          // Decode and cache
          final bytes = base64Decode(plan.imageBase64!);
          _imageCache[plan.id.toString()] = bytes;
          cachedImage = bytes;
        }
      } catch (e) {
        cachedImage = null;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================
              // TOP SECTION: IMAGE WITH PREMIUM OVERLAY
              // ============================================
              Stack(
                children: [
                  // Image Container - USING CACHED IMAGE
                  Container(
                    height: 155,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: hasImage && cachedImage != null
                          ? null
                          : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: hasImage && cachedImage != null
                        ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      child: Image.memory(
                        cachedImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImageFallback(plan, gradientColors);
                        },
                      ),
                    )
                        : _buildImageFallback(plan, gradientColors),
                  ),

                  // Premium Gradient Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.6),
                            Colors.black.withOpacity(0.85),
                          ],
                          stops: const [0.0, 0.2, 0.4, 0.7, 1.0],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                    ),
                  ),

                  // Premium Shine Effect
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.transparent,
                            Colors.white.withOpacity(0.03),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badges
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            plan.isPopular ? Icons.star_rounded : Icons.verified_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            plan.tag,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${plan.durationDays} Days',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restaurant,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${plan.maxDishes} Items',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            plan.planName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A202C),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors[0].withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            plan.formattedPrice,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.description.isNotEmpty
                          ? plan.description
                          : '${plan.durationDays} Days Meal Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[500],
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildPremiumFeature(
                          icon: Icons.restaurant,
                          label: '${plan.maxDishes} Dishes',
                          color: gradientColors[0],
                        ),
                        const SizedBox(width: 12),
                        _buildPremiumFeature(
                          icon: Icons.calendar_today,
                          label: '${plan.durationDays} Days',
                          color: gradientColors[1],
                        ),
                        const SizedBox(width: 12),
                        _buildPremiumFeature(
                          icon: Icons.schedule,
                          label: 'Flexible',
                          color: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            gradientColors[0].withOpacity(0.15),
                            gradientColors[1].withOpacity(0.15),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '100% Secure',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors[0].withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _navigateToSubscriptionOrder(plan),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              minimumSize: const Size(90, 38),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Order Now",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 10,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Secure payment • One-time charge',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.grey[400],
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
    );
  }

  // ==============================================
  // IMAGE FALLBACK
  // ==============================================
  Widget _buildImageFallback(SubscriptionPlan plan, List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              plan.planName.substring(0, 1).toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Text(
              '${plan.durationDays} Days',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // PREMIUM FEATURE WIDGET
  // ==============================================
  Widget _buildPremiumFeature({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // MENU HEADER
  // ==============================================
  Widget _buildMenuHeader(Color darkColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isSearching ? "Search Results" : "Our Menu",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
            ),
            if (!_isSearching)
              Text(
                "${_filteredMenuItems.length} items",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // MENU GRID - WITH CACHED IMAGES
  // ==============================================
  Widget _buildMenuGrid(Color primaryColor, Color lightPurple) {
    final items = _filteredMenuItems;

    if (items.isEmpty && _isSearching) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                "No results found",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Try searching for something else",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index >= items.length) return null;
            final item = items[index];
            return _buildMenuItemCard(item, primaryColor, lightPurple, index);
          },
          childCount: items.length,
        ),
      ),
    );
  }

  // ==============================================
  // MENU ITEM CARD - WITH CACHED IMAGES
  // ==============================================
  Widget _buildMenuItemCard(
      Map<String, dynamic> item,
      Color primaryColor,
      Color lightPurple,
      int index,
      ) {
    final String imageBase64 = item['image_base64'] ?? '';
    final String name = item['name'] ?? 'Unknown';
    final double price = _parsePrice(item['price']);
    final String description = item['description'] ?? '';

    // Cache menu item images
    Uint8List? cachedImage;
    if (imageBase64.isNotEmpty) {
      final cacheKey = 'menu_${item['id'] ?? name}';
      if (_imageCache.containsKey(cacheKey)) {
        cachedImage = _imageCache[cacheKey];
      } else {
        try {
          final bytes = base64Decode(imageBase64);
          _imageCache[cacheKey] = bytes;
          cachedImage = bytes;
        } catch (e) {
          cachedImage = null;
        }
      }
    }

    return FadeTransition(
      opacity: _animationController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              0.0,
              0.6 + (index * 0.05),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: lightPurple,
                  child: cachedImage != null
                      ? Image.memory(
                    cachedImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackImage(name, primaryColor);
                    },
                  )
                      : _buildFallbackImage(name, primaryColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description.isNotEmpty ? description : 'Delicious dish',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => widget.onAddToCart(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "ADD",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildFallbackImage(String name, Color primaryColor) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.08),
            primaryColor.withOpacity(0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: primaryColor.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // HELPER METHODS
  // ==============================================
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  double _parsePrice(dynamic priceValue) {
    if (priceValue == null) return 0.0;
    if (priceValue is double) return priceValue;
    if (priceValue is int) return priceValue.toDouble();
    if (priceValue is String) return double.tryParse(priceValue) ?? 0.0;
    if (priceValue is num) return priceValue.toDouble();
    return 0.0;
  }
}