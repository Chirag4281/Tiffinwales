// cart_screen.dart - NO LOADING SPINNER, Instant Updates

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'order_screen.dart';

class CartScreen extends StatefulWidget {
  final String email;
  final String locationName;
  final String username;

  const CartScreen({
    super.key,
    required this.email,
    required this.locationName,
    required this.username,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ==============================================
  // NO SPINNER - Just track if we need to revert
  // ==============================================
  bool _isOperationInProgress = false;
  Timer? _debounceTimer;

  final String cartApiUrl = 'https://quantorra.co/tiffinwales/Cart.php';

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ==============================================
  // LOAD CART ITEMS
  // ==============================================
  Future<void> _loadCartItems() async {
    if (_isOperationInProgress) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOperationInProgress = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'get_cart';
      request.fields['email'] = widget.email;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (mounted) {
        if (responseData['status'] == 'success') {
          setState(() {
            _cartItems = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
            _isLoading = false;
            _isOperationInProgress = false;
          });
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Failed to load cart';
            _isLoading = false;
            _isOperationInProgress = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: ${e.toString()}';
          _isLoading = false;
          _isOperationInProgress = false;
        });
      }
    }
  }

  // ==============================================
  // REMOVE FROM CART - INSTANT, NO SPINNER
  // ==============================================
  void _removeFromCart(Map<String, dynamic> item) {
    final String itemName = item['item_name'] ?? '';
    if (_isOperationInProgress) return;

    // === INSTANT REMOVAL - NO SPINNER ===
    setState(() {
      _cartItems.removeWhere((i) => i['item_name'] == itemName);
    });

    // Show quick feedback
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$itemName removed',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(milliseconds: 400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    // Background sync - fire and forget
    _syncRemoveToServer(itemName);
  }

  // ==============================================
  // BACKGROUND REMOVE SYNC
  // ==============================================
  Future<void> _syncRemoveToServer(String itemName) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'remove_from_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      // If server failed, reload to sync
      if (responseData['status'] != 'success' && mounted) {
        await _loadCartItems();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove $itemName. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await _loadCartItems();
      }
    }
  }

  // ==============================================
  // UPDATE QUANTITY - INSTANT, NO SPINNER
  // ==============================================
  void _updateCartQuantity(Map<String, dynamic> item, int newQuantity) {
    final String itemName = item['item_name'] ?? '';
    if (_isOperationInProgress) return;

    // === INSTANT QUANTITY UPDATE - NO SPINNER ===
    setState(() {
      final index = _cartItems.indexWhere((i) => i['item_name'] == itemName);
      if (index != -1) {
        _cartItems[index]['quantity'] = newQuantity;
      }
    });

    // Debounce the sync to prevent rapid server calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      await _syncQuantityToServer(itemName, newQuantity);
    });
  }

  // ==============================================
  // BACKGROUND QUANTITY SYNC
  // ==============================================
  Future<void> _syncQuantityToServer(String itemName, int newQuantity) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'update_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;
      request.fields['quantity'] = newQuantity.toString();

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      // If server failed, reload to sync
      if (responseData['status'] != 'success' && mounted) {
        await _loadCartItems();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update quantity. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await _loadCartItems();
      }
    }
  }

  // ==============================================
  // CLEAR CART - INSTANT, NO SPINNER
  // ==============================================
  void _clearCart() {
    if (_isOperationInProgress) return;

    // === INSTANT CLEAR - NO SPINNER ===
    setState(() {
      _cartItems.clear();
    });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Cart cleared!'),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(milliseconds: 400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    // Background sync
    _syncClearCartToServer();
  }

  // ==============================================
  // BACKGROUND CLEAR SYNC
  // ==============================================
  Future<void> _syncClearCartToServer() async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'clear_cart';
      request.fields['email'] = widget.email;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] != 'success' && mounted) {
        await _loadCartItems();
      }
    } catch (e) {
      if (mounted) {
        await _loadCartItems();
      }
    }
  }

  double get _total => _cartItems.fold(
    0.0,
        (sum, item) => sum + (double.tryParse(item['item_price']?.toString() ?? '0') ?? 0) * (item['quantity'] ?? 1),
  );

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);
    const Color lightBg = Color(0xFFF7FAFC);
    final bool hasItems = _cartItems.isNotEmpty;

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Cart",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),
        centerTitle: true,
        actions: [
          if (hasItems && !_isOperationInProgress)
            TextButton(
              onPressed: () => _showClearCartDialog(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[400],
              ),
              child: Text(
                "Clear All",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : _cartItems.isEmpty
            ? _buildEmptyState()
            : _buildCartContent(),
      ),
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
            'Loading your cart...',
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
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadCartItems,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 60,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Your cart is empty",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Looks like you haven't added any items yet",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              "Explore Menu",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);
    final double total = _total;
    final double deliveryFee = 2.50;
    final double tax = total * 0.08;
    final double grandTotal = total + deliveryFee + tax;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              final price = double.tryParse(item['item_price']?.toString() ?? '0') ?? 0;
              final quantity = item['quantity'] ?? 1;

              return _buildCartItem(
                item: item,
                price: price,
                quantity: quantity,
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildPriceRow('Subtotal', total),
                    _buildPriceRow('Delivery Fee', deliveryFee),
                    _buildPriceRow('Tax & Charges', tax),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildPriceRow('Total', grandTotal, isTotal: true),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isOperationInProgress ? null : () => _showCheckoutDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Place Order",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '\$${grandTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================
  // CART ITEM - NO SPINNER EVER
  // ==============================================
  Widget _buildCartItem({
    required Map<String, dynamic> item,
    required double price,
    required int quantity,
  }) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);
    final String itemName = item['item_name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.12),
                  const Color(0xFF8B5CF6).withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                itemName.substring(0, 1).toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ==============================================
                  // PLUS/MINUS BUTTONS - NO SPINNER EVER
                  // ==============================================
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (quantity > 1) {
                              _updateCartQuantity(item, quantity - 1);
                            } else {
                              _removeFromCart(item);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Icon(
                              Icons.remove,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$quantity',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: darkColor,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            _updateCartQuantity(item, quantity + 1);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Icon(
                              Icons.add,
                              color: primaryColor,
                              size: 18,
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                _showRemoveDialog(context, item);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red[300],
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
              color: isTotal ? darkColor : Colors.grey[600],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? primaryColor : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // DIALOGS
  // ==============================================

  void _showRemoveDialog(BuildContext context, Map<String, dynamic> item) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Remove Item',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${item['item_name']}" from your cart?',
          style: GoogleFonts.poppins(
            fontSize: 14,
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFromCart(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    const Color darkColor = Color(0xFF1A202C);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Clear Cart',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),
        content: Text(
          'Are you sure you want to clear your entire cart?',
          style: GoogleFonts.poppins(
            fontSize: 14,
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCart();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Clear All',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);
    final double total = _total;
    final double deliveryFee = 2.50;
    final double tax = total * 0.08;
    final double grandTotal = total + deliveryFee + tax;

    showDialog(
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
                color: primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Order',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDialogPriceRow('Items (${_cartItems.length})', total),
                  _buildDialogPriceRow('Delivery Fee', deliveryFee),
                  _buildDialogPriceRow('Tax & Charges', tax),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildDialogPriceRow('Total', grandTotal, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Delivering From ${widget.locationName}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
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
            onPressed: _isOperationInProgress ? null : () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderScreen(
                    email: widget.email,
                    locationName: widget.locationName,
                    username: widget.username,
                    cartItems: _cartItems,
                    total: total,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Proceed to Checkout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogPriceRow(String label, double amount, {bool isTotal = false}) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
              color: isTotal ? darkColor : Colors.grey[600],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? primaryColor : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}