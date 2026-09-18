// location_home_tab.dart - WITH PROPER IMAGE CACHING (FIXED) - Orange Theme

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:tiffinwales/subscription/subscription_list_screen.dart';
import '../subscription/subscription_order_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';
import 'meal_plan_order_screen.dart';

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
// ==============================================
// REORDER STATE
// ==============================================
  Map<String, dynamic>? _lastOrder;
  bool _isLoadingLastOrder = true;
  bool _isReordering = false;

  final String ordersApiUrl =
      'https://quantorra.co/tiffinwales/Orders.php';
  // Subscription plans from backend
  List<SubscriptionPlan> _subscriptionPlans = [];
  bool _isLoadingPlans = true;
  String? _plansError;

  // ==============================================
  // IMAGE CACHE - STATIC SO IT'S SHARED ACROSS ALL INSTANCES
  // ==============================================
  static final Map<String, Uint8List> _imageCache = {};
  static final Map<String, String> _imageUrlCache = {};
  static final Map<String, bool> _imageLoadingStatus = {};
  static bool _imagesPreCached = false;

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
    _loadLastOrder();          // ✅ ADD

    _startAutoScroll();

    if (!_imagesPreCached) {
      _preCacheImages();
      _imagesPreCached = true;
    }
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
// LOAD LAST ORDER FOR REORDER CARD
// ==============================================
  Future<void> _loadLastOrder() async {
    setState(() {
      _isLoadingLastOrder = true;
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'get_last_order';
      request.fields['email'] = widget.email;
      request.fields['location_name'] = widget.locationName;

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      if (!mounted) return;

      if (data['status'] == 'success' && data['data'] != null) {
        setState(() {
          _lastOrder = Map<String, dynamic>.from(data['data']);
          _isLoadingLastOrder = false;
        });
      } else {
        setState(() {
          _lastOrder = null;
          _isLoadingLastOrder = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _loadLastOrder: $e');
      if (mounted) {
        setState(() {
          _lastOrder = null;
          _isLoadingLastOrder = false;
        });
      }
    }
  }

// ==============================================
// REORDER — ADD ALL ITEMS FROM LAST ORDER
// ==============================================
  Future<void> _reorderLastOrder() async {
    if (_lastOrder == null || _isReordering) return;

    setState(() => _isReordering = true);

    try {
      // ---------- Parse items ----------
      List<Map<String, dynamic>> items = [];
      final rawItems = _lastOrder!['items'];

      if (rawItems is String && rawItems.isNotEmpty) {
        try {
          final decoded = json.decode(rawItems);
          if (decoded is List) {
            items = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        } catch (e) {
          debugPrint('❌ Failed to parse items JSON: $e');
        }
      } else if (rawItems is List) {
        items = rawItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      debugPrint('🔵 REORDER: parsed ${items.length} items');
      for (final it in items) {
        debugPrint('   → ${it['item_name'] ?? it['name']} x${it['quantity']}');
      }

      if (items.isEmpty) {
        _showReorderSnack('Previous order has no items', Colors.red);
        setState(() => _isReordering = false);
        return;
      }

      // ---------- ONE HTTP CALL ----------
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://quantorra.co/tiffinwales/Cart.php'),
      );
      request.fields['action'] = 'reorder';
      request.fields['email'] = widget.email;
      request.fields['location_name'] = widget.locationName;
      request.fields['items'] = json.encode(items);

      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      debugPrint('📥 Reorder response: $body');

      if (data['status'] != 'success') {
        _showReorderSnack(
          data['message']?.toString() ?? 'Failed to reorder',
          Colors.red,
        );
        setState(() => _isReordering = false);
        return;
      }

      if (!mounted) return;
      _showReorderSnack(
        'Added ${items.length} item${items.length == 1 ? '' : 's'} to cart!',
        const Color(0xFF10B981),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartScreen(
            email: widget.email,
            locationName: widget.locationName,
            username: widget.username,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ _reorderLastOrder: $e');
      _showReorderSnack('Failed to reorder', Colors.red);
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }
// ==============================================
// REORDER CARD — Zomato Style
// ==============================================
  Widget _buildReorderCard(Color primaryColor) {
    // Don't show anything if no last order or still loading
    if (_isLoadingLastOrder || _lastOrder == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Parse items
    List<Map<String, dynamic>> items = [];
    final rawItems = _lastOrder!['items'];
    if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final decoded = json.decode(rawItems);
        if (decoded is List) {
          items = decoded.map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).where((m) => m.isNotEmpty).toList();
        }
      } catch (_) {}
    } else if (rawItems is List) {
      items = rawItems.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty).toList();
    }

    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final String orderId = (_lastOrder!['order_id'] ?? '').toString();
    final String total = (_lastOrder!['total'] ?? '0').toString();
    final String createdAt = (_lastOrder!['created_at'] ?? '').toString();
    final String formattedDate = _formatOrderDate(createdAt);

    // Show max 4 item thumbnails
    final int visibleThumbs = items.length > 4 ? 4 : items.length;
    final int extraCount = items.length - visibleThumbs;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isReordering ? null : _reorderLastOrder,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withOpacity(0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Again',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              if (formattedDate.isNotEmpty)
                                Text(
                                  'From $formattedDate',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Item count badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${items.length} item${items.length == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Thumbnails row
                    Row(
                      children: [
                        // Thumbnail stack
                        SizedBox(
                          height: 52,
                          width: 52.0 * visibleThumbs + 8,
                          child: Stack(
                            children: List.generate(visibleThumbs, (i) {
                              final item = items[i];
                              return Positioned(
                                left: i * 42.0,
                                child: _buildReorderThumb(item),
                              );
                            }),
                          ),
                        ),

                        // "+N more" text
                        if (extraCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+$extraCount more',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Total + CTA
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${double.tryParse(total)?.toStringAsFixed(2) ?? total}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isReordering)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF97316),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.replay_rounded,
                                      size: 12,
                                      color: Color(0xFFF97316),
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isReordering ? 'Adding…' : 'Reorder',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFF97316),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Order id (small)
                    if (orderId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Order ID: $orderId',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

// ==============================================
// REORDER THUMBNAIL
// ==============================================
  Widget _buildReorderThumb(Map<String, dynamic> item) {
    final String name = (item['name'] ?? item['item_name'] ?? '?').toString();
    final String imageUrl = (item['image_url'] ?? item['image'] ?? '').toString();
    final String imageBase64 =
    (item['image_base64'] ?? '').toString();

    Widget content;

    if (imageUrl.isNotEmpty) {
      content = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          if (imageBase64.isNotEmpty) {
            try {
              return Image.memory(
                base64Decode(imageBase64),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbFallback(name),
              );
            } catch (_) {}
          }
          return _thumbFallback(name);
        },
      );
    } else if (imageBase64.isNotEmpty) {
      try {
        content = Image.memory(
          base64Decode(imageBase64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbFallback(name),
        );
      } catch (_) {
        content = _thumbFallback(name);
      }
    } else {
      content = _thumbFallback(name);
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(child: content),
    );
  }

  Widget _thumbFallback(String name) {
    return Container(
      color: const Color(0xFFFFF3E8),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFF97316),
          ),
        ),
      ),
    );
  }

// ==============================================
// FORMAT ORDER DATE ("Today", "Yesterday", "Mar 12")
// ==============================================
  String _formatOrderDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${months[dt.month - 1]} ${dt.day}';
      }
    } catch (_) {
      return '';
    }
  }
  void _showReorderSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: color,
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  // ==============================================
  // PRE-CACHE IMAGES - ONLY CALLED ONCE
  // ==============================================
  void _preCacheImages() {
    for (final item in widget.menuItems) {
      final imageBase64 = (item['image_base64'] ?? '').toString();
      final imageUrl = (item['image_url'] ?? '').toString();
      final cacheKey = 'menu_${item['id'] ?? item['name']}';

      if (imageBase64.isNotEmpty &&
          !imageBase64.startsWith('SVG:') &&
          !_imageCache.containsKey(cacheKey)) {
        try {
          final bytes = base64Decode(imageBase64);
          String content = utf8.decode(bytes, allowMalformed: true);
          if (!content.contains('<svg') && !content.contains('<?xml')) {
            _imageCache[cacheKey] = bytes;
          }
        } catch (e) {
          // Ignore
        }
      }

      if (imageUrl.isNotEmpty && !_imageUrlCache.containsKey(cacheKey)) {
        _imageUrlCache[cacheKey] = imageUrl;
      }
    }
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

          for (var plan in loadedPlans) {
            if (plan.hasImage && plan.imageBase64 != null) {
              try {
                final bytes = base64Decode(plan.imageBase64!);
                if (!_imageCache.containsKey(plan.id.toString())) {
                  _imageCache[plan.id.toString()] = bytes;
                }
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
          final description = (item['description'] ?? '')
              .toString()
              .toLowerCase();
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
        builder: (context) =>
            SubscriptionOrderScreen(
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
        builder: (context) =>
            SubscriptionListScreen(
              locationName: widget.locationName,
              userEmail: widget.email,
              username: widget.username,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);       // Logo orange
    const Color lightPurple = Color(0xFFFFF3E8);         // Warm orange tint
    const Color darkColor = Color(0xFF1C1C1E);           // Logo charcoal
    const Color lightBg = Color(0xFFFAFAFA);             // Clean background

    return Scaffold(
      backgroundColor: lightBg,
      body: CustomScrollView(
        slivers: [
          _buildHeader(darkColor, primaryColor),
          _buildSearchBar(primaryColor),
          if (!_isSearching) _buildReorderCard(primaryColor),          // ✅ NEW
          if (!_isSearching) _buildSubscriptionPlansSection(primaryColor),
          _buildMenuHeader(darkColor),
          _buildMenuList(primaryColor, lightPurple),
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
                    builder: (context) =>
                        HomeScreen(
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
                    color: const Color(0xFF1C1C1E),
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
  // SUBSCRIPTION CARD - PREMIUM REDESIGN
  // ==============================================
  Widget _buildSubscriptionCard(SubscriptionPlan plan, Color primaryColor) {
    final Map<String, List<Color>> planAccents = {
      '3days':  [const Color(0xFFF97316), const Color(0xFFEA580C)],
      '5days':  [const Color(0xFFF97316), const Color(0xFFEA580C)],
      '7days':  [const Color(0xFFF97316), const Color(0xFFEA580C)],
      '15days': [const Color(0xFFF97316), const Color(0xFFEA580C)],
      '30days': [const Color(0xFFF97316), const Color(0xFFEA580C)],
    };

    final List<Color> accentColors = planAccents[plan.planType] ??
        [const Color(0xFFF97316), const Color(0xFFEA580C)];

    final Color primaryAccent = accentColors[0];
    final Color secondaryAccent = accentColors[1];

    final bool hasImage = plan.hasImage;

    Uint8List? cachedImage;
    if (hasImage && plan.imageBase64 != null) {
      if (_imageCache.containsKey(plan.id.toString())) {
        cachedImage = _imageCache[plan.id.toString()];
      } else {
        try {
          final bytes = base64Decode(plan.imageBase64!);
          _imageCache[plan.id.toString()] = bytes;
          cachedImage = bytes;
        } catch (e) {
          cachedImage = null;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          highlightColor: Colors.transparent,
          splashColor: primaryColor.withOpacity(0.05),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: primaryAccent.withOpacity(0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeroImage(
                  plan: plan,
                  cachedImage: cachedImage,
                  accentColors: accentColors,
                  primaryAccent: primaryAccent,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPlanNameAndPrice(
                        plan: plan,
                        primaryAccent: primaryAccent,
                      ),
                      const SizedBox(height: 4),
                      _buildDescription(plan: plan),
                      const SizedBox(height: 12),
                      _buildFeaturesRow(
                        plan: plan,
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: Colors.grey[100],
                      ),
                      const SizedBox(height: 14),
                      _buildBottomRow(
                        plan: plan,
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // HERO IMAGE
  // ==============================================
  Widget _buildHeroImage({
    required SubscriptionPlan plan,
    required Uint8List? cachedImage,
    required List<Color> accentColors,
    required Color primaryAccent,
  }) {
    final bool hasImage = cachedImage != null;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            height: 170,
            width: double.infinity,
            color: Colors.grey[50],
            child: hasImage
                ? Image.memory(
              cachedImage!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return _buildImageFallback(
                  plan: plan,
                  accentColors: accentColors,
                );
              },
            )
                : _buildImageFallback(
              plan: plan,
              accentColors: accentColors,
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.02),
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.35),
                ],
                stops: const [0.0, 0.3, 0.5, 0.75, 1.0],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================
  // PLAN NAME & PRICE
  // ==============================================
  Widget _buildPlanNameAndPrice({
    required SubscriptionPlan plan,
    required Color primaryAccent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            plan.planName,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: primaryAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            plan.formattedPrice,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primaryAccent,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================
  // DESCRIPTION
  // ==============================================
  Widget _buildDescription({required SubscriptionPlan plan}) {
    return Text(
      plan.description.isNotEmpty
          ? plan.description
          : '${plan.durationDays}-day meal plan with fresh, homemade dishes',
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Colors.grey[500],
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ==============================================
  // FEATURES ROW
  // ==============================================
  Widget _buildFeaturesRow({
    required SubscriptionPlan plan,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    final features = [
      {
        'icon': Icons.restaurant,
        'label': '${plan.maxDishes} Dishes',
      },
      {
        'icon': Icons.calendar_today,
        'label': '${plan.durationDays} Days',
      },
      {
        'icon': Icons.timer,
        'label': 'Flexible',
      },
    ];

    return Row(
      children: features.map((feature) {
        return Expanded(
          child: _buildFeatureItem(
            icon: feature['icon'] as IconData,
            label: feature['label'] as String,
            primaryAccent: primaryAccent,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required Color primaryAccent,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: primaryAccent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primaryAccent.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: primaryAccent.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1C1C1E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // BOTTOM ROW: TRUST + CTA
  // ==============================================
  Widget _buildBottomRow({
    required SubscriptionPlan plan,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.shield_rounded,
              size: 14,
              color: const Color(0xFFF97316),
            ),
            const SizedBox(width: 4),
            Text(
              'Secure Checkout',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFF97316),
              ),
            ),
          ],
        ),
        _buildCTAButton(
          plan: plan,
          primaryAccent: primaryAccent,
          secondaryAccent: secondaryAccent,
        ),
      ],
    );
  }

  // ==============================================
  // CTA BUTTON
  // ==============================================
  Widget _buildCTAButton({
    required SubscriptionPlan plan,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToSubscriptionOrder(plan),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryAccent, secondaryAccent],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primaryAccent.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Plan',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================
  // IMAGE FALLBACK - PREMIUM
  // ==============================================
  Widget _buildImageFallback({
    required SubscriptionPlan plan,
    required List<Color> accentColors,
  }) {
    final Map<String, String> planEmojis = {
      '3days': '🌿',
      '5days': '🔥',
      '7days': '⭐',
      '15days': '👑',
      '30days': '💎',
    };
    final String emoji = planEmojis[plan.planType] ?? '📦';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColors[0].withOpacity(0.15),
            accentColors[1].withOpacity(0.25),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColors[0].withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColors[1].withOpacity(0.06),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 42),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.planName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accentColors[0].withOpacity(0.5),
                  ),
                ),
                Text(
                  '${plan.durationDays} Days',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: accentColors[0].withOpacity(0.3),
                  ),
                ),
              ],
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
  // MENU LIST - ONE ITEM PER LINE
  // ==============================================
  Widget _buildMenuList(Color primaryColor, Color lightPurple) {
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
      sliver: SliverList(
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

  bool _isMealPlanItem(String itemName) {
    if (itemName.isEmpty) return false;

    final lowerName = itemName.toLowerCase().trim();

    if (lowerName.contains('meal plan') ||
        lowerName.contains('meal-plan') ||
        lowerName.contains('mealplan')) {
      return true;
    }

    final regex = RegExp(r'\d+\s*[-\s]?\s*days?\s*meal');
    if (regex.hasMatch(lowerName)) {
      return true;
    }

    if (lowerName.contains('weekly meal') ||
        lowerName.contains('monthly meal') ||
        lowerName.contains('daily meal')) {
      return true;
    }

    return false;
  }

  int _parseDishCountFromName(String itemName) {
    if (itemName.isEmpty) return 3;

    final lower = itemName.toLowerCase();

    final match = RegExp(r'(\d+)\s*[-\s]?\s*days?').firstMatch(lower);
    if (match != null) {
      final parsed = int.tryParse(match.group(1) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }

    if (lower.contains('weekly')) return 7;
    if (lower.contains('monthly')) return 30;
    if (lower.contains('daily')) return 1;

    return 3;
  }

  // ==============================================
  // MENU ITEM CARD
  // ==============================================
  Widget _buildMenuItemCard(
      Map<String, dynamic> item,
      Color primaryColor,
      Color lightPurple,
      int index,
      ) {
    final String imageUrl = item['image_url'] ?? '';
    final String imageBase64 = item['image_base64'] ?? '';
    final String name = item['name'] ?? 'Unknown';
    final double price = _parsePrice(item['price']);
    final String description = item['description'] ?? '';
    final String? category = item['category'];

    final double? rating = () {
      final val = item['rating'];
      if (val == null) return null;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }();

    final bool isVeg = item['is_veg'] ?? true;
    final int? totalRatings = () {
      final val = item['total_ratings'];
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }();

    final String? discount = item['discount'];
    final bool popular = item['popular'] == true;
    final double? originalPrice = () {
      final val = item['original_price'];
      if (val == null) return null;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }();

    final cacheKey = 'menu_${item['id'] ?? name}';

    Uint8List? cachedImage = _imageCache[cacheKey];
    bool useNetworkImage = _imageUrlCache.containsKey(cacheKey);

    final String itemKey = '${item['id'] ?? name}_$index';

    return FadeTransition(
      opacity: _animationController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              0.0,
              0.5 + (index * 0.015),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
        child: Container(
          key: ValueKey(itemKey),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade50,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE SECTION (Left - Circular)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.08),
                            primaryColor.withOpacity(0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: lightPurple,
                          child: _buildCachedImageWidget(
                            cachedImage: cachedImage,
                            useNetworkImage: useNetworkImage,
                            imageUrl: imageUrl,
                            imageBase64: imageBase64,
                            name: name,
                            primaryColor: primaryColor,
                            cacheKey: cacheKey,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isVeg ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVeg ? Icons.circle : Icons.square,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                      ),
                    ),
                    if (discount != null && discount.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF6B6B),
                                const Color(0xFFFF3366),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            discount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // CONTENT SECTION (Right)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1C1E),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rating != null && rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.green,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if (totalRatings != null) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '(${_formatRatingCount(totalRatings)})',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (category != null && category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        description.isNotEmpty ? description : 'Delicious dish',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${price.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              if (originalPrice != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '\$${originalPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey[400],
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              if (_isMealPlanItem(name)) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MealPlanOrderScreen(
                                      locationName: widget.locationName,
                                      userEmail: widget.email,
                                      username: widget.username,
                                      menuItem: item,
                                      requiredDishCount: _parseDishCountFromName(name),
                                      onAddToCart: widget.onAddToCart,
                                    ),
                                  ),
                                );
                              } else {
                                widget.onAddToCart(item);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isMealPlanItem(name) ? Icons.tune_rounded : Icons.add_rounded,
                                    color: primaryColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isMealPlanItem(name) ? "Customize" : "Add",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (popular)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.whatshot_rounded,
                                size: 12,
                                color: const Color(0xFFFF6B6B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Popular',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF6B6B),
                                ),
                              ),
                            ],
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
    );
  }

  // ==============================================
  // CACHED IMAGE WIDGET
  // ==============================================
  Widget _buildCachedImageWidget({
    required Uint8List? cachedImage,
    required bool useNetworkImage,
    required String imageUrl,
    required String imageBase64,
    required String name,
    required Color primaryColor,
    required String cacheKey,
  }) {
    if (cachedImage != null) {
      return Image.memory(
        cachedImage,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return _buildCircularFallback(name, primaryColor);
        },
      );
    }

    if (useNetworkImage && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Container(
            color: Colors.grey.shade50,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (imageBase64.isNotEmpty) {
            try {
              final bytes = base64Decode(imageBase64);
              _imageCache[cacheKey] = bytes;
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return _buildCircularFallback(name, primaryColor);
                },
              );
            } catch (e) {
              return _buildCircularFallback(name, primaryColor);
            }
          }
          return _buildCircularFallback(name, primaryColor);
        },
      );
    }

    if (imageBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64);
        _imageCache[cacheKey] = bytes;
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _buildCircularFallback(name, primaryColor);
          },
        );
      } catch (e) {
        return _buildCircularFallback(name, primaryColor);
      }
    }

    return _buildCircularFallback(name, primaryColor);
  }

  // ==============================================
  // CIRCULAR FALLBACK IMAGE
  // ==============================================
  Widget _buildCircularFallback(String name, Color primaryColor) {
    return Container(
      color: Colors.grey.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 24,
              color: primaryColor.withOpacity(0.2),
            ),
            const SizedBox(height: 2),
            Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor.withOpacity(0.4),
              ),
            ),
          ],
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

  String _formatRatingCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else if (count >= 100) {
      return '${(count / 100).toStringAsFixed(0)}K';
    }
    return count.toString();
  }

  double _parsePrice(dynamic price) {
    if (price is String) {
      return double.tryParse(price) ?? 0.0;
    } else if (price is num) {
      return price.toDouble();
    }
    return 0.0;
  }
}