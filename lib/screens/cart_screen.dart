// lib/screens/cart_screen.dart
// Premium Cart Screen — with Meal Plan edit support

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' as typed_data;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'order_screen.dart';
import 'meal_plan_order_screen.dart';

// ============================================================
// THEME CONSTANTS
// ============================================================
class CartTheme {
  static const Color primary = Color(0xFFF97316);        // Logo orange
  static const Color primaryDark = Color(0xFFEA580C);    // Darker orange
  static const Color secondary = Color(0xFFEA580C);      // Secondary orange
  static const Color dark = Color(0xFF0F0F10);           // Deep charcoal
  static const Color body = Color(0xFF1C1C1E);           // Logo charcoal
  static const Color muted = Color(0xFF64748B);          // Neutral grey
  static const Color softBg = Color(0xFFFAFAFA);         // Clean background
  static const Color cardBg = Colors.white;
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentAmber = Color(0xFFF59E0B);

  // ✅ Orange gradient (Tiffin Wales brand)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
  );

  // ✅ Orange gradient for the header
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF3E8), Color(0xFFFFE8D0)],
  );

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: primary.withOpacity(0.35),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}

// ============================================================
// CART SCREEN
// ============================================================
class CartScreen extends StatefulWidget {
  final String email;
  final String locationName;
  final String username;
  final VoidCallback? onCartChanged;

  const CartScreen({
    super.key,
    required this.email,
    required this.locationName,
    required this.username,
    this.onCartChanged,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  // ---------------------------------------------------------
  // STATE
  // ---------------------------------------------------------
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOperationInProgress = false;
  Timer? _debounceTimer;

  // Animations
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const String cartApiUrl =
      'https://quantorra.co/tiffinwales/Cart.php';

  // ---------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------
  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _entranceController.forward();

    _loadCartItems();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  // =========================================================
  // API — LOAD CART
  // =========================================================
  Future<void> _loadCartItems() async {
    if (_isOperationInProgress) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOperationInProgress = true;
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'get_cart';
      request.fields['email'] = widget.email;

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
        throw Exception('Connection timeout. Please try again.'),
      );

      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      if (!mounted) return;

      if (data['status'] == 'success') {
        setState(() {
          _cartItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
          _isOperationInProgress = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load cart';
          _isLoading = false;
          _isOperationInProgress = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
        _isOperationInProgress = false;
      });
    }
  }

  // =========================================================
  // MEAL PLAN DETECTION HELPERS
  // =========================================================
  bool _isMealPlanItem(String itemName) {
    if (itemName.isEmpty) return false;
    final lower = itemName.toLowerCase();
    return lower.contains('meal plan') ||
        lower.contains('meal-plan') ||
        RegExp(r'\d+\s*[-\s]?\s*days?\s*meal').hasMatch(lower);
  }

  int _parseRequiredDishCount(String itemName) {
    final m = RegExp(r'(\d+)\s*[-\s]?\s*days?')
        .firstMatch(itemName.toLowerCase());
    if (m != null) {
      final n = int.tryParse(m.group(1) ?? '');
      if (n != null && n > 0) return n;
    }
    final paren = RegExp(r'\(([^)]*)\)').firstMatch(itemName);
    if (paren != null) {
      final dishes = paren
          .group(1)!
          .split(',')
          .where((s) => s.trim().isNotEmpty);
      if (dishes.isNotEmpty) return dishes.length;
    }
    return 3;
  }

  List<String> _parseSelectedDishes(String itemName) {
    final paren = RegExp(r'\(([^)]*)\)').firstMatch(itemName);
    if (paren == null) return [];
    return paren
        .group(1)!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _stripDishSuffix(String itemName) {
    final idx = itemName.indexOf(' (');
    return idx == -1 ? itemName : itemName.substring(0, idx).trim();
  }

  // =========================================================
  // REMOVE
  // =========================================================
  void _removeFromCart(Map<String, dynamic> item) {
    if (_isOperationInProgress) return;
    final String itemName = item['item_name'] ?? '';

    setState(() {
      _cartItems.removeWhere((i) => i['item_name'] == itemName);
    });

    _showSnack(
      icon: Icons.check_circle,
      message: '${_stripDishSuffix(itemName)} removed',
      color: CartTheme.accentGreen,
    );

    _syncRemoveToServer(itemName);
  }

  Future<void> _syncRemoveToServer(String itemName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'remove_from_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;

      final streamed = await request.send().timeout(
        const Duration(seconds: 8),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] != 'success' && mounted) {
        await _loadCartItems();
      }
    } catch (_) {
      if (mounted) await _loadCartItems();
    }
  }

  Future<bool> _removeItemFromServerRaw(String itemName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'remove_from_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;

      final streamed = await request.send().timeout(
        const Duration(seconds: 8),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);
      return data['status'] == 'success';
    } catch (e) {
      debugPrint('❌ _removeItemFromServerRaw: $e');
      return false;
    }
  }

  // =========================================================
  // QUANTITY
  // =========================================================
  void _updateCartQuantity(Map<String, dynamic> item, int newQuantity) {
    if (_isOperationInProgress) return;
    final String itemName = item['item_name'] ?? '';

    setState(() {
      final idx = _cartItems.indexWhere((i) => i['item_name'] == itemName);
      if (idx != -1) _cartItems[idx]['quantity'] = newQuantity;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      await _syncQuantityToServer(itemName, newQuantity);
    });
  }

  Future<void> _syncQuantityToServer(String itemName, int newQuantity) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'update_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;
      request.fields['quantity'] = newQuantity.toString();

      final streamed = await request.send().timeout(
        const Duration(seconds: 8),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] != 'success' && mounted) {
        await _loadCartItems();
      }
    } catch (_) {
      if (mounted) await _loadCartItems();
    }
  }

  // =========================================================
  // CLEAR CART
  // =========================================================
  void _clearCart() {
    if (_isOperationInProgress) return;

    setState(() => _cartItems.clear());

    _showSnack(
      icon: Icons.check_circle,
      message: 'Cart cleared!',
      color: CartTheme.primary,
    );

    _syncClearCartToServer();
  }

  Future<void> _syncClearCartToServer() async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'clear_cart';
      request.fields['email'] = widget.email;

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] != 'success' && mounted) {
        await _loadCartItems();
      }
    } catch (_) {
      if (mounted) await _loadCartItems();
    }
  }

  // =========================================================
  // EDIT MEAL PLAN
  // =========================================================
  Future<void> _editMealPlan(Map<String, dynamic> cartItem) async {
    final String fullName = cartItem['item_name']?.toString() ?? '';
    final int requiredCount = _parseRequiredDishCount(fullName);
    final List<String> existingDishes = _parseSelectedDishes(fullName);
    final String baseName = _stripDishSuffix(fullName);

    // Synthesize a menuItem for the edit screen
    final Map<String, dynamic> menuItem = {
      'id': cartItem['id'],
      'name': baseName,
      'price': cartItem['item_price'],
      'image_url': cartItem['image_url'] ?? '',
      'image_base64': cartItem['image_base64'] ?? '',
      'image': cartItem['image_url'] ?? '',
      'description': cartItem['description'] ?? '',
    };

    // 1) Remove old entry from server so we don't get duplicates
    final removed = await _removeItemFromServerRaw(fullName);
    if (!removed) {
      if (mounted) {
        _showSnack(
          icon: Icons.error_outline,
          message: 'Could not prepare item for editing. Try again.',
          color: CartTheme.accentRed,
        );
      }
      return;
    }

    // 2) Optimistically remove from local list
    if (mounted) {
      setState(() {
        _cartItems.removeWhere((i) => i['item_name'] == fullName);
      });
    }

    if (!mounted) return;

    // 3) Open the meal plan screen prefilled
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealPlanOrderScreen(
          locationName: widget.locationName,
          userEmail: widget.email,
          username: widget.username,
          requiredDishCount: requiredCount,
          menuItem: menuItem,
          preselectedDishes: existingDishes,
          onAddToCart: _reAddMealPlan,
        ),
      ),
    );

    // 4) Refresh cart & notify parent
    await _loadCartItems();
    widget.onCartChanged?.call();
  }

  Future<void> _reAddMealPlan(Map<String, dynamic> orderItem) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'add_to_cart';
      request.fields['email'] = widget.email;
      request.fields['location_name'] = widget.locationName;

      final String baseName = orderItem['name']?.toString() ?? 'Meal Plan';
      final List<String> dishes =
          (orderItem['selected_dishes'] as List?)?.cast<String>() ?? [];
      final String displayName =
      dishes.isEmpty ? baseName : '$baseName (${dishes.join(", ")})';

      request.fields['item_name'] = displayName;
      request.fields['item_price'] =
          (orderItem['total_price'] ?? orderItem['price'] ?? '0').toString();
      request.fields['quantity'] = '1';

      final String imgUrl =
      (orderItem['image_url'] ?? orderItem['image'] ?? '').toString();
      final String imgBase64 =
      (orderItem['image_base64'] ?? '').toString();
      if (imgUrl.isNotEmpty) request.fields['image_url'] = imgUrl;
      if (imgBase64.isNotEmpty) request.fields['image_base64'] = imgBase64;

      request.fields['is_meal_plan'] = 'true';
      request.fields['meal_type'] = orderItem['meal_type']?.toString() ?? 'both';
      request.fields['bread_type'] =
          orderItem['bread_type']?.toString() ?? 'naan';
      request.fields['spice_level'] =
          orderItem['spice_level']?.toString() ?? 'mild';
      request.fields['selected_dishes'] = json.encode(dishes);
      request.fields['special_instructions'] =
          orderItem['special_instructions']?.toString() ?? '';
      request.fields['delivery_option'] =
          orderItem['delivery_option']?.toString() ?? 'delivery';
      request.fields['delivery_date'] =
          orderItem['delivery_date']?.toString() ?? '';
      request.fields['delivery_time_slot'] =
          orderItem['delivery_time_slot']?.toString() ?? '';

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] != 'success') {
        debugPrint('❌ _reAddMealPlan: ${data['message']}');
      }
    } catch (e) {
      debugPrint('❌ _reAddMealPlan: $e');
    }
  }

  // =========================================================
  // SNACKBAR
  // =========================================================
  void _showSnack({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // =========================================================
  // TOTALS
  // =========================================================
  double get _subtotal => _cartItems.fold(
    0.0,
        (sum, item) =>
    sum +
        (double.tryParse(item['item_price']?.toString() ?? '0') ?? 0) *
            ((item['quantity'] ?? 1) as int),
  );

  int get _totalItems => _cartItems.fold(
    0,
        (sum, item) => sum + ((item['quantity'] ?? 1) as int),
  );

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final hasItems = _cartItems.isNotEmpty;

    return Scaffold(
      backgroundColor: CartTheme.softBg,
      body: Column(
        children: [
          // ✅ Header with top SafeArea (respects notch/status bar)
          SafeArea(
            bottom: false,
            child: _buildHeader(hasItems),
          ),
          // ✅ Content + checkout bar with bottom SafeArea
          Expanded(
            child: SafeArea(
              top: false,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _isLoading
                      ? _buildLoadingState()
                      : _errorMessage != null
                      ? _buildErrorState()
                      : !hasItems
                      ? _buildEmptyState()
                      : _buildCartContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
  // ---------------------------------------------------------
  // HEADER — Orange gradient (Tiffin Wales)
  // ---------------------------------------------------------
  Widget _buildHeader(bool hasItems) {
    return Container(
      decoration: BoxDecoration(
        gradient: CartTheme.heroGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: CartTheme.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        children: [
          Row(
            children: [
              _roundIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_totalItems item${_totalItems == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasItems && !_isOperationInProgress)
                GestureDetector(
                  onTap: () => _showClearCartDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Cart',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.locationName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ---------------------------------------------------------
  // LOADING STATE
  // ---------------------------------------------------------
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: CartTheme.softGradient,
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(CartTheme.primary),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Loading your cart…',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: CartTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // ERROR STATE
  // ---------------------------------------------------------
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: CartTheme.accentRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 42,
                color: CartTheme.accentRed.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CartTheme.body,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: CartTheme.muted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCartItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: CartTheme.primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Try Again',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: CartTheme.softGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 60,
                color: CartTheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Your cart is empty',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: CartTheme.body,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Looks like you haven't added anything yet",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: CartTheme.muted,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: CartTheme.primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant_menu_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Explore Menu',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  Widget _buildCartContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), // uniform padding
            physics: const BouncingScrollPhysics(),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              final price =
                  double.tryParse(item['item_price']?.toString() ?? '0') ?? 0;
              final quantity = (item['quantity'] ?? 1) as int;
              return _buildCartItemCard(
                key: ValueKey(item['item_name'] ?? index),
                item: item,
                price: price,
                quantity: quantity,
              );
            },
          ),
        ),
        _buildCheckoutBar(),
      ],
    );
  }
  // ---------------------------------------------------------
  // CART ITEM CARD
  // ---------------------------------------------------------
  Widget _buildCartItemCard({
    required Key key,
    required Map<String, dynamic> item,
    required double price,
    required int quantity,
  }) {
    final String itemName = item['item_name']?.toString() ?? 'Unknown';
    final bool isMealPlan = _isMealPlanItem(itemName);
    final String baseName =
    isMealPlan ? _stripDishSuffix(itemName) : itemName;
    final List<String> dishes =
    isMealPlan ? _parseSelectedDishes(itemName) : [];
    final String description = (item['description'] ?? '').toString();

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: CartTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMealPlan
              ? CartTheme.primary.withOpacity(0.15)
              : Colors.grey.shade100,
          width: 1,
        ),
        boxShadow: CartTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal plan gradient strip
          if (isMealPlan)
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: CartTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                _buildItemImage(item, itemName),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top: name + badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              baseName,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CartTheme.body,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMealPlan) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: CartTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${dishes.length}D PLAN',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Description (only for non-meal-plan)
                      if (!isMealPlan && description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: CartTheme.muted,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Dish chips
                      if (isMealPlan && dishes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: dishes
                              .take(6)
                              .map((d) => _buildDishChip(d))
                              .toList()
                            ..addAll(
                              dishes.length > 6
                                  ? [
                                _buildDishChip(
                                  '+${dishes.length - 6} more',
                                  isMore: true,
                                ),
                              ]
                                  : [],
                            ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Price row + qty stepper
                      Row(
                        children: [
                          Text(
                            '\$${(price * quantity).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: CartTheme.primary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (quantity > 1) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(\$${price.toStringAsFixed(2)} ea)',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: CartTheme.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const Spacer(),
                          _buildQtyStepper(item, quantity),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: CartTheme.softBg.withOpacity(0.6),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                if (isMealPlan)
                  Expanded(
                    child: _buildActionChip(
                      icon: Icons.tune_rounded,
                      label: 'Customize',
                      color: CartTheme.primary,
                      onTap: () => _editMealPlan(item),
                    ),
                  )
                else
                  Expanded(
                    child: _buildActionChip(
                      icon: Icons.info_outline_rounded,
                      label: 'Delicious choice',
                      color: CartTheme.muted,
                      onTap: null,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionChip(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    color: CartTheme.accentRed,
                    onTap: () => _showRemoveDialog(context, item),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishChip(String label, {bool isMore = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMore
            ? CartTheme.primary.withOpacity(0.12)
            : CartTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CartTheme.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: CartTheme.primaryDark,
        ),
      ),
    );
  }

  Widget _buildQtyStepper(Map<String, dynamic> item, int quantity) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CartTheme.primary.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            icon: Icons.remove_rounded,
            onTap: () {
              if (quantity > 1) {
                _updateCartQuantity(item, quantity - 1);
              } else {
                _showRemoveDialog(context, item);
              }
            },
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 24),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CartTheme.body,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add_rounded,
            onTap: () => _updateCartQuantity(item, quantity + 1),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          icon,
          color: CartTheme.primary,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // ITEM IMAGE
  // ---------------------------------------------------------
  Widget _buildItemImage(Map<String, dynamic> item, String name) {
    const double size = 92;
    final String rawUrl = (item['image_url'] ?? '').toString().trim();
    final String imageBase64 =
    (item['image_base64'] ?? '').toString().trim();
    final String imageUrl = _normalizeImageUrl(rawUrl);

    Widget inner;
    if (imageUrl.isNotEmpty) {
      inner = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _imagePlaceholder(name);
        },
        errorBuilder: (_, __, ___) {
          if (imageBase64.isNotEmpty) {
            return _buildBase64Image(imageBase64, name);
          }
          return _imagePlaceholder(name);
        },
      );
    } else if (imageBase64.isNotEmpty) {
      inner = _buildBase64Image(imageBase64, name);
    } else {
      inner = _imagePlaceholder(name);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: CartTheme.softGradient,
        boxShadow: [
          BoxShadow(
            color: CartTheme.primary.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: inner,
      ),
    );
  }

  String _normalizeImageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw.replaceAll(RegExp(r'(?<!:)\/\/+'), '/');
    }
    final clean = raw.replaceFirst(RegExp(r'^\/+'), '');
    return 'https://quantorra.co/tiffinwales/$clean';
  }

  Widget _buildBase64Image(String base64Str, String name) {
    try {
      String clean = base64Str;
      if (clean.contains(',')) clean = clean.split(',').last;
      clean = clean.replaceAll(RegExp(r'\s+'), '');

      final typed_data.Uint8List bytes = base64Decode(clean);

      try {
        final content = utf8.decode(bytes, allowMalformed: true);
        if (content.contains('<svg') || content.contains('<?xml')) {
          return _imagePlaceholder(name);
        }
      } catch (_) {}

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: 92,
        height: 92,
        errorBuilder: (_, __, ___) => _imagePlaceholder(name),
      );
    } catch (_) {
      return _imagePlaceholder(name);
    }
  }

  Widget _imagePlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: CartTheme.softGradient,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: CartTheme.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final subtotal = _subtotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), // reduced bottom
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _summaryTile(
                  label: 'Subtotal',
                  value: '\$${subtotal.toStringAsFixed(2)}',
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(width: 10),
                _summaryTile(
                  label: 'Items',
                  value: '$_totalItems',
                  icon: Icons.shopping_basket_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isOperationInProgress
                    ? null
                    : () => _showCheckoutDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CartTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: CartTheme.primary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Proceed to Checkout',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '\$${subtotal.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10), // extra breathing room above home bar
          ],
        ),
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CartTheme.softBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CartTheme.primary.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: CartTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: CartTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: CartTheme.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: CartTheme.body,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DIALOGS
  // =========================================================
  void _showRemoveDialog(BuildContext context, Map<String, dynamic> item) {
    final displayName = _stripDishSuffix(item['item_name'] ?? '');

    showDialog(
      context: context,
      builder: (_) => _dialogShell(
        icon: Icons.delete_outline_rounded,
        iconColor: CartTheme.accentRed,
        title: 'Remove Item?',
        body:
        'Are you sure you want to remove "$displayName" from your cart?',
        primaryLabel: 'Remove',
        primaryColor: CartTheme.accentRed,
        onPrimary: () {
          Navigator.pop(context);
          _removeFromCart(item);
        },
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _dialogShell(
        icon: Icons.delete_sweep_rounded,
        iconColor: CartTheme.accentRed,
        title: 'Clear Cart?',
        body:
        'This will remove all $_totalItems item${_totalItems == 1 ? '' : 's'} from your cart.',
        primaryLabel: 'Clear All',
        primaryColor: CartTheme.accentRed,
        onPrimary: () {
          Navigator.pop(context);
          _clearCart();
        },
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    final subtotal = _subtotal;

    showDialog(
      context: context,
      builder: (_) => _dialogShell(
        icon: Icons.shopping_bag_rounded,
        iconColor: CartTheme.primary,
        title: 'Confirm Order',
        customBody: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: CartTheme.softGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _dialogRow('Items', '$_totalItems'),
                  const SizedBox(height: 6),
                  _dialogRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
                  Divider(height: 18, color: Colors.grey.shade300),
                  _dialogRow(
                    'Total',
                    '\$${subtotal.toStringAsFixed(2)}',
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: CartTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Delivering from ${widget.locationName}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: CartTheme.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        primaryLabel: 'Proceed',
        primaryColor: CartTheme.primary,
        onPrimary: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderScreen(
                email: widget.email,
                locationName: widget.locationName,
                username: widget.username,
                cartItems: _cartItems,
                total: subtotal,
              ),
            ),
          ).then((_) => _loadCartItems());
        },
      ),
    );
  }

  Widget _dialogRow(String label, String value, {bool emphasized = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: emphasized ? 14 : 12.5,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            color: emphasized ? CartTheme.body : CartTheme.muted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: emphasized ? 15 : 13,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            color: emphasized ? CartTheme.primary : CartTheme.body,
          ),
        ),
      ],
    );
  }

  Widget _dialogShell({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? body,
    Widget? customBody,
    required String primaryLabel,
    required Color primaryColor,
    required VoidCallback onPrimary,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CartTheme.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (body != null)
              Text(
                body,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: CartTheme.muted,
                  height: 1.45,
                ),
              ),
            if (customBody != null) customBody,
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CartTheme.muted,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryLabel,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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