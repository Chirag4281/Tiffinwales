import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/priority_notification_service.dart';
import '../services/notification_service.dart';
import '../services/secure_card_service.dart';

class OrderScreen extends StatefulWidget {
  final String email;
  final String locationName;
  final String username;
  final List<Map<String, dynamic>> cartItems;
  final double total;
  final Function(Map<String, dynamic>)? onAddToCart;

  const OrderScreen({
    super.key,
    required this.email,
    required this.locationName,
    required this.username,
    required this.cartItems,
    required this.total,
    this.onAddToCart,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();

  // Card autofill state
  SavedCardDisplay? _savedCardDisplay;
  bool _isLoadingSavedCard = false;
  bool _useSavedCard = false;
  bool _saveCardAfterOrder = true; // checkbox — user controls

  bool _showCardForm = false;
  bool _isLoading = false;
  bool _isPlacingOrder = false;

  // ✅ Local mutable cart state
  late List<Map<String, dynamic>> _localCartItems;
  late double _localTotal;

  // Suggestions State
  List<Map<String, dynamic>> _suggestedItems = [];
  bool _isLoadingSuggestions = false;
  final Set<String> _addedSuggestionIds = {};
  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';

  // Payment & WebView State
  bool _isOnlinePayment = false;
  String? _paymentUrl;
  late WebViewController _webViewController;
  bool _isWebViewLoading = false;

  List<String> _deliverySlots = [];
  String? _selectedDeliverySlot;
  bool _isLoadingSlots = true;

  String? _deliveryLatitude;
  String? _deliveryLongitude;
  bool _isLiveLocation = false;
  bool _isFetchingLocation = false;

  double _deliveryFee = 0.0;
  double _distance = 0.0;
  bool _isCalculatingDeliveryFee = false;
  String _distanceUnit = 'miles';
  bool _isDeliveryAvailable = true;
  String _deliveryUnavailableReason = '';

// ✅ Delivery Option: 'delivery' or 'pickup'
  String _deliveryOption = 'delivery';

  bool _addressChoiceShown = false;
  String _selectedAddressType = 'stored';

  bool _hasSavedAddress = false;
  bool _isLoadingAddress = false;

  // API URLs
  final String orderApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';
  final String cartApiUrl = 'https://quantorra.co/tiffinwales/Cart.php';
  final String addressApiUrl = 'https://quantorra.co/tiffinwales/Address.php';
  final String deliveryFeeApiUrl =
      'https://quantorra.co/tiffinwales/delivery_fee.php';
  final String haloPaymentApiUrl =
      'https://quantorra.co/tiffinwales/create_halo_payment.php';

  final loc.Location _location = loc.Location();

  @override
  void initState() {
    super.initState();
    // ✅ Initialize local cart from widget
    _localCartItems = widget.cartItems
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _localTotal = widget.total;

    _loadDeliverySlots();
    _loadUserAddress();
    _prefillName();
    _loadSuggestions();
    _loadSavedCard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddressChoiceDialog();
    });
  }

  Future<void> _loadSavedCard() async {
    setState(() => _isLoadingSavedCard = true);
    try {
      final display = await SecureCardService.loadDisplayInfo();
      if (!mounted) return;
      setState(() {
        _savedCardDisplay = display;
        _useSavedCard = display != null; // default to using it if available
        _isLoadingSavedCard = false;
      });
    } catch (e) {
      print('❌ Load saved card error: $e');
      if (mounted) setState(() => _isLoadingSavedCard = false);
    }
  }

  void _prefillName() {
    if (widget.username.isNotEmpty) {
      _nameController.text = widget.username;
    }
  }

// ==============================================
// SERVER SYNC — ADD TO CART (persist to DB)
// ==============================================
  Future<void> _syncAddToServer(Map<String, dynamic> item, int newQty) async {
    try {
      final String itemId = (item['id'] ?? item['name'] ?? '').toString();
      final String itemName = item['name'] ?? 'Item';
      final double price = double.tryParse(
        item['price']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0',
      ) ??
          0.0;

      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));

      // If it's an update (qty > 1), use update_cart; else add_to_cart
      if (newQty > 1) {
        request.fields['action'] = 'update_cart';
        request.fields['email'] = widget.email;
        request.fields['item_name'] = itemName;
        request.fields['quantity'] = newQty.toString();
      } else {
        request.fields['action'] = 'add_to_cart';
        request.fields['email'] = widget.email;
        request.fields['location_name'] = widget.locationName;
        request.fields['item_name'] = itemName;
        request.fields['item_price'] = price.toString();
        request.fields['quantity'] = '1';
        request.fields['item_id'] = itemId;

        final String imgUrl = (item['image_url'] ?? '').toString();
        final String imgBase64 = (item['image_base64'] ?? '').toString();
        if (imgUrl.isNotEmpty) request.fields['image_url'] = imgUrl;
        if (imgBase64.isNotEmpty) request.fields['image_base64'] = imgBase64;
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);
      print('✅ Server sync (add/update): ${data['status']}');
    } catch (e) {
      print('❌ Server sync add failed: $e');
    }
  }

// ==============================================
// SERVER SYNC — REMOVE / DECREMENT
// ==============================================
  Future<void> _syncRemoveFromServer(Map<String, dynamic> item) async {
    try {
      final String itemName = item['name'] ?? item['item_name'] ?? '';
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'remove_from_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);
      print('✅ Server sync (remove): ${data['status']}');
    } catch (e) {
      print('❌ Server sync remove failed: $e');
    }
  }

// ==============================================
// SERVER SYNC — DECREMENT (update_cart with new qty)
// ==============================================
  Future<void> _syncDecrementToServer(Map<String, dynamic> item,
      int newQty) async {
    try {
      final String itemName = item['item_name'] ?? item['name'] ?? '';
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'update_cart';
      request.fields['email'] = widget.email;
      request.fields['item_name'] = itemName;
      request.fields['quantity'] = newQty.toString();

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);
      print('✅ Server sync (decrement): ${data['status']}');
    } catch (e) {
      print('❌ Server sync decrement failed: $e');
    }
  }

  // ==============================================
  // ADD ITEM TO LOCAL CART (Real-time sync)
  // ==============================================
  // ==============================================
// ADD ITEM TO LOCAL CART + PERSIST TO SERVER
// ==============================================
  void _addItemToCart(Map<String, dynamic> item) {
    final String itemId = (item['id'] ?? item['name'] ?? '').toString();
    final String itemName = item['name'] ?? 'Item';
    final double price = double.tryParse(
      item['price']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0',
    ) ??
        0.0;

    int existingIndex = _localCartItems.indexWhere(
          (cartItem) =>
      (cartItem['item_id'] ??
          cartItem['id'] ??
          cartItem['item_name'] ??
          '')
          .toString() ==
          itemId,
    );

    int newQty = 1;

    setState(() {
      if (existingIndex != -1) {
        final existing = _localCartItems[existingIndex];
        final currentQty =
            int.tryParse(existing['quantity']?.toString() ?? '1') ?? 1;
        newQty = currentQty + 1;
        _localCartItems[existingIndex] = {
          ...existing,
          'quantity': newQty,
        };
      } else {
        newQty = 1;
        _localCartItems.add({
          'item_id': itemId,
          'id': itemId,
          'item_name': itemName,
          'name': itemName,
          'item_price': price.toString(),
          'price': price.toString(),
          'quantity': 1,
          'image_url': item['image_url'] ?? '',
          'image_base64': item['image_base64'] ?? '',
        });
      }

      _recalculateTotal();
      _addedSuggestionIds.add(itemId);
    });

    // 🔥 PERSIST TO SERVER (so CartScreen sees it)
    _syncAddToServer(item, newQty);

    // Notify parent
    widget.onAddToCart?.call(item);
  }

  // ==============================================
  // DECREMENT CART ITEM
  // ==============================================
  // ==============================================
// DECREMENT CART ITEM + SYNC TO SERVER
// ==============================================
  void _decrementCartItem(String itemId) {
    final int idx = _localCartItems.indexWhere(
          (c) =>
      (c['item_id'] ?? c['id'] ?? c['item_name'] ?? '').toString() ==
          itemId,
    );
    if (idx == -1) return;

    Map<String, dynamic> removedItem = {};
    bool shouldRemoveFromServer = false;
    int newQty = 1;

    setState(() {
      final current =
          int.tryParse(_localCartItems[idx]['quantity']?.toString() ?? '1') ??
              1;
      if (current <= 1) {
        removedItem = Map<String, dynamic>.from(_localCartItems[idx]);
        _localCartItems.removeAt(idx);
        _addedSuggestionIds.remove(itemId);
        shouldRemoveFromServer = true;
      } else {
        newQty = current - 1;
        _localCartItems[idx] = {
          ..._localCartItems[idx],
          'quantity': newQty,
        };
      }
      _recalculateTotal();
    });

    // 🔥 SYNC TO SERVER
    if (shouldRemoveFromServer) {
      _syncRemoveFromServer(removedItem);
    } else {
      _syncDecrementToServer(_localCartItems[idx], newQty);
    }
  }

  // ==============================================
// REFRESH LOCAL CART FROM SERVER (optional safety net)
// ==============================================
  Future<void> _refreshLocalCartFromServer() async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'get_cart';
      request.fields['email'] = widget.email;

      final streamed = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final body = await streamed.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] == 'success') {
        setState(() {
          _localCartItems =
          List<Map<String, dynamic>>.from(data['data'] ?? []);
          _recalculateTotal();
        });
      }
    } catch (e) {
      print('❌ Failed to refresh cart: $e');
    }
  }

  void _recalculateTotal() {
    _localTotal = _localCartItems.fold<double>(0.0, (sum, cartItem) {
      final p = double.tryParse(
        cartItem['item_price']
            ?.toString()
            .replaceAll(RegExp(r'[^\d.]'), '') ??
            cartItem['price']
                ?.toString()
                .replaceAll(RegExp(r'[^\d.]'), '') ??
            '0',
      ) ??
          0.0;
      final q = int.tryParse(cartItem['quantity']?.toString() ?? '1') ?? 1;
      return sum + (p * q);
    });
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'get_menus';
      request.fields['location_name'] = widget.locationName;
      request.fields['email'] = widget.email;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      print('Suggestions response: $responseBody');
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success' && responseData['data'] != null) {
        List<dynamic> rawItems = responseData['data'];

        // =============================================
        // MATCHERS
        // =============================================
        bool isBread(Map<String, dynamic> item) {
          final cat = (item['category'] ?? '').toString().toLowerCase();
          final name = (item['name'] ?? '').toString().toLowerCase();
          return cat.contains('bread') ||
              cat.contains('roti') ||
              cat.contains('rotli') ||
              cat.contains('naan') ||
              name.contains('naan') ||
              name.contains('roti') ||
              name.contains('paratha') ||
              name.contains('kulcha') ||
              name.contains('chapati') ||
              name.contains('bhakri') ||
              name.contains('thepla') ||
              name.contains('puri');
        }

        bool isSweetOrBeverage(Map<String, dynamic> item) {
          final cat = (item['category'] ?? '').toString().toLowerCase();
          final name = (item['name'] ?? '').toString().toLowerCase();

          // Category-level matches (covers all location variants)
          if (cat.contains('sweet') ||
              cat.contains('dessert') ||
              cat.contains('mithai') ||
              cat.contains('beverage') ||
              cat.contains('appetizer') ||
              cat.contains('snack') ||
              cat.contains('farsan') ||
              cat.contains('drink') ||
              cat.contains('chutney')) {
            return true;
          }

          // Name-level matches (sweets)
          if (name.contains('sweet') ||
              name.contains('dessert') ||
              name.contains('mithai') ||
              name.contains('halwa') ||
              name.contains('laddu') ||
              name.contains('ladoo') ||
              name.contains('barfi') ||
              name.contains('kheer') ||
              name.contains('gulab jamun') ||
              name.contains('rasmalai') ||
              name.contains('jalebi') ||
              name.contains('peda') ||
              name.contains('shrikhand') ||
              name.contains('basundi') ||
              name.contains('rabdi')) {
            return true;
          }

          // Name-level matches (beverages)
          if (name.contains('lassi') ||
              name.contains('chaas') ||
              name.contains('chai') ||
              name.contains('tea') ||
              name.contains('coffee') ||
              name.contains('juice') ||
              name.contains('shake') ||
              name.contains('soda') ||
              name.contains('mocktail') ||
              name.contains('buttermilk')) {
            return true;
          }

          return false;
        }

        // =============================================
        // SPLIT ITEMS INTO BREADS + SWEETS
        // =============================================
        final allItems =
        rawItems.map((e) => Map<String, dynamic>.from(e)).toList();

        final breads = <Map<String, dynamic>>[];
        final sweets = <Map<String, dynamic>>[];
        final seenIds = <String>{};

        for (final item in allItems) {
          final id = (item['id'] ?? item['name'] ?? '').toString();
          if (id.isEmpty || seenIds.contains(id)) continue;

          if (isBread(item)) {
            breads.add({...item, '_suggestionType': 'bread'});
            seenIds.add(id);
          } else if (isSweetOrBeverage(item)) {
            // Distinguish beverage vs sweet for the badge
            final name = (item['name'] ?? '').toString().toLowerCase();
            final cat = (item['category'] ?? '').toString().toLowerCase();

            String subtype = 'sweet'; // default

            final beverageKeywords = [
              'lassi', 'chaas', 'chai', 'tea', 'coffee', 'juice',
              'shake', 'soda', 'mocktail', 'buttermilk',
            ];
            final isBeverageByName =
            beverageKeywords.any((k) => name.contains(k));
            final isBeverageByCat =
                cat.contains('beverage') || cat.contains('drink');

            if (isBeverageByName || isBeverageByCat) {
              subtype = 'beverage';
            }

            sweets.add({...item, '_suggestionType': subtype});
            seenIds.add(id);
          }
        }

        // =============================================
        // BUILD FINAL LIST
        // Interleave: bread, sweet, bread, sweet...
        // so the UI shows a nice mix
        // =============================================
        // Cap each type at 6 so we don't flood the strip with one category
        const int maxPerType = 6;
        final breadsCapped = breads.take(maxPerType).toList();
        final extrasCapped = sweets.take(maxPerType).toList();

        final suggestions = <Map<String, dynamic>>[];
        final maxLen = breadsCapped.length > extrasCapped.length
            ? breadsCapped.length
            : extrasCapped.length;

        for (int i = 0; i < maxLen; i++) {
          if (i < breadsCapped.length) suggestions.add(breadsCapped[i]);
          if (i < extrasCapped.length) suggestions.add(extrasCapped[i]);
        }

        final finalSuggestions = suggestions.isNotEmpty
            ? suggestions
            : allItems
            .take(8)
            .map((e) => {...e, '_suggestionType': 'generic'})
            .toList();

        setState(() {
          _suggestedItems = finalSuggestions;
          _isLoadingSuggestions = false;
        });

        print(
            '✅ Loaded ${breads.length} breads + ${sweets.length} sweets '
                '(total ${finalSuggestions.length})');
      } else {
        setState(() {
          _suggestedItems = [];
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      print('Error loading suggestions: $e');
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  // ==============================================
  // INLINE SUGGESTIONS — CLEAN ZOMATO STYLE
  // ==============================================
  Widget _buildInlineSuggestions() {
    const Color primaryColor = Color(0xFFF97316);

    if (_isLoadingSuggestions && _suggestedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_suggestedItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'People Also Purchase',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Breads & sweets to complete your meal',
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
          const SizedBox(height: 14),

          // HORIZONTAL TILES
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestedItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildSuggestionTile(_suggestedItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // SUGGESTION TILE — CLEANER DESIGN
  // ==============================================
  Widget _buildSuggestionTile(Map<String, dynamic> item) {
    const Color primaryColor = Color(0xFFF97316);
    final String itemId = (item['id'] ?? item['name'] ?? '').toString();
    final String name = item['name'] ?? 'Unknown';
    final double price = double.tryParse(
      item['price']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0',
    ) ??
        0.0;
    final String imageBase64 = item['image_base64'] ?? '';
    final String imageUrl = item['image_url'] ?? '';
    final bool isVeg = item['is_veg'] ?? true;

    // Check quantity in local cart
    int cartQty = 0;
    final existing = _localCartItems.firstWhere(
          (c) =>
      (c['item_id'] ?? c['id'] ?? c['item_name'] ?? '').toString() ==
          itemId,
      orElse: () => {},
    );
    if (existing.isNotEmpty) {
      cartQty = int.tryParse(existing['quantity']?.toString() ?? '0') ?? 0;
    }

    return Container(
      width: 145,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cartQty > 0
              ? primaryColor.withOpacity(0.4)
              : Colors.grey.withOpacity(0.15),
          width: cartQty > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: Container(
                  width: 145,
                  height: 100,
                  color: const Color(0xFFFFF3E8),
                  child: _buildSuggestionImage(
                    imageUrl,
                    imageBase64,
                    name,
                    primaryColor,
                  ),
                ),
              ),
              // Veg / Non-veg indicator
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isVeg ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // INFO
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 32,
                  child: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const Spacer(),
                    // Type badge: 🍞 bread or 🍮 sweet
                    _buildSuggestionTypeBadge(
                        item['_suggestionType']?.toString()),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // ADD BUTTON / QUANTITY STEPPER
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 32,
              child: cartQty > 0
                  ? Container(
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => _decrementCartItem(itemId),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 28,
                        height: 32,
                        child: Icon(
                          Icons.remove_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    Text(
                      '$cartQty',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _addItemToCart(item),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 28,
                        height: 32,
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : GestureDetector(
                onTap: () {
                  _addItemToCart(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name added to cart'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'ADD',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ==============================================
// SUGGESTION TYPE BADGE (Bread / Sweet)
// ==============================================
  Widget _buildSuggestionTypeBadge(String? type) {
    if (type == null || type.isEmpty) return const SizedBox.shrink();

    late final IconData icon;
    late final Color color;

    switch (type) {
      case 'bread':
        icon = Icons.bakery_dining_rounded;
        color = const Color(0xFFF97316); // orange
        break;
      case 'sweet':
        icon = Icons.cake_rounded;
        color = const Color(0xFFEC4899); // pink
        break;
      case 'beverage':
        icon = Icons.local_drink_rounded;
        color = const Color(0xFF06B6D4); // cyan
        break;
      default:
        icon = Icons.restaurant_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 11, color: color),
    );
  }

  // ==============================================
  // SUGGESTION IMAGE BUILDER
  // ==============================================
  Widget _buildSuggestionImage(String imageUrl,
      String imageBase64,
      String name,
      Color primaryColor,) {
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) {
          if (imageBase64.isNotEmpty) {
            try {
              return Image.memory(
                base64Decode(imageBase64),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildSuggestionFallback(name, primaryColor),
              );
            } catch (_) {}
          }
          return _buildSuggestionFallback(name, primaryColor);
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.grey.shade50,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
            ),
          );
        },
      );
    }
    if (imageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildSuggestionFallback(name, primaryColor),
        );
      } catch (_) {}
    }
    return _buildSuggestionFallback(name, primaryColor);
  }

  Widget _buildSuggestionFallback(String name, Color primaryColor) {
    return Container(
      color: primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: primaryColor.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // GET ADDRESS FROM LAT LNG
  // ==============================================
  Future<Map<String, String>?> _getAddressFromLatLng(double lat,
      double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
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

        return {
          'address': address,
          'city': city,
          'postalCode': postalCode,
        };
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  // ==============================================
  // SHOW ADDRESS CHOICE DIALOG
  // ==============================================
  void _showAddressChoiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
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
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 5,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: const Color(0xFFF97316).withOpacity(0.2),
                    blurRadius: 80,
                    offset: const Offset(0, 30),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                          ),
                          borderRadius: BorderRadius.circular(16),
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
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Delivery Address',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Select where you want your order delivered',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildAddressOption(
                    icon: Icons.saved_search_rounded,
                    title: 'Stored Address',
                    subtitle: _hasSavedAddress &&
                        _addressController.text.isNotEmpty
                        ? _addressController.text.substring(0, 30) + '...'
                        : 'Use your saved delivery address',
                    isSelected: _selectedAddressType == 'stored',
                    color: const Color(0xFFF97316),
                    onTap: () {
                      setState(() {
                        _selectedAddressType = 'stored';
                        _isLiveLocation = false;
                      });
                      Navigator.pop(context);
                      _handleAddressSelection('stored');
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildAddressOption(
                    icon: Icons.gps_fixed_rounded,
                    title: 'Live Location',
                    subtitle: 'Use your current GPS location',
                    isSelected: _selectedAddressType == 'live',
                    color: const Color(0xFF34D399),
                    onTap: () {
                      setState(() {
                        _selectedAddressType = 'live';
                        _isLiveLocation = true;
                        _isFetchingLocation = true;
                      });
                      Navigator.pop(context);
                      _handleAddressSelection('live');
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white.withOpacity(0.4),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Delivery charges and availability may vary based on your location',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
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
    );
  }

  Widget _buildAddressOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.white.withOpacity(0.5),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddressSelection(String addressType) async {
    if (addressType == 'live') {
      _showFetchingLocationDialog();
      try {
        bool _serviceEnabled = await _location.serviceEnabled();
        if (!_serviceEnabled) {
          _serviceEnabled = await _location.requestService();
          if (!_serviceEnabled) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location services are disabled'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isFetchingLocation = false;
            });
            return;
          }
        }

        loc.PermissionStatus _permissionGranted =
        await _location.hasPermission();
        if (_permissionGranted == loc.PermissionStatus.denied) {
          _permissionGranted = await _location.requestPermission();
          if (_permissionGranted != loc.PermissionStatus.granted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isFetchingLocation = false;
            });
            return;
          }
        }

        loc.LocationData locationData = await _location.getLocation();
        final userLat = locationData.latitude;
        final userLng = locationData.longitude;

        if (userLat != null && userLng != null) {
          final addressData = await _getAddressFromLatLng(userLat, userLng);
          Navigator.pop(context);
          setState(() {
            if (addressData != null) {
              _addressController.text =
                  addressData['address'] ?? 'Live Location';
              _cityController.text = addressData['city'] ?? '';
              _postalCodeController.text = addressData['postalCode'] ?? '';
            } else {
              _addressController.text = 'Live Location';
              _cityController.text = 'GPS Location';
            }
            _deliveryLatitude = userLat.toString();
            _deliveryLongitude = userLng.toString();
            _isLiveLocation = true;
            _isFetchingLocation = false;
            _isCalculatingDeliveryFee = true;
          });
          await _calculateDeliveryFee(userLat, userLng);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📍 Location updated to Live GPS'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          Navigator.pop(context);
          setState(() {
            _isFetchingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        Navigator.pop(context);
        setState(() {
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() {
        _isLiveLocation = false;
        _isCalculatingDeliveryFee = true;
      });
      await _loadUserAddress();
      if (_hasSavedAddress &&
          _deliveryLatitude != null &&
          _deliveryLatitude!.isNotEmpty) {
        await _calculateDeliveryFee(
            double.parse(_deliveryLatitude!),
            double.parse(_deliveryLongitude!));
      } else {
        await _calculateDeliveryFee(19.0760, 72.8777);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📍 Address updated to saved address'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showFetchingLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Color(0xFFF97316),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.gps_fixed,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Fetching Live Location',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we get your current location...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(0),
                      _buildDot(1),
                      _buildDot(2),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withOpacity(index == 1 ? 1.0 : 0.3),
        shape: BoxShape.circle,
      ),
    );
  }

  // ==============================================
  // CALCULATE DELIVERY FEE
  // ==============================================
  Future<void> _calculateDeliveryFee(double userLat, double userLng) async {
    try {
      print('Calculating delivery fee for - Lat: $userLat, Lng: $userLng');

      var request = http.MultipartRequest('POST', Uri.parse(deliveryFeeApiUrl));
      request.fields['action'] = 'calculate_delivery_fee';
      request.fields['location_name'] = widget.locationName;
      request.fields['email'] = widget.email;
      request.fields['user_latitude'] = userLat.toString();
      request.fields['user_longitude'] = userLng.toString();

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      print('Response from server: $responseBody');

      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        final distance = double.tryParse(
            responseData['data']['distance']?.toString() ?? '0') ??
            0;
        final fee = double.tryParse(
            responseData['data']['delivery_fee']?.toString() ?? '0') ??
            0;
        final isAvailable = responseData['data']['is_available'] ?? false;

        print(
            'Distance calculated: $distance miles, Fee: $fee, Available: $isAvailable');

        setState(() {
          _distance = distance;
          _deliveryFee = fee;
          _isCalculatingDeliveryFee = false;
          _isDeliveryAvailable = isAvailable;
          _deliveryUnavailableReason = isAvailable
              ? ''
              : 'We currently deliver only within 15 miles. Your location is ${distance
              .toStringAsFixed(1)} miles away.';
        });
      } else {
        print('Error from server: ${responseData['message']}');
        setState(() {
          _isDeliveryAvailable = false;
          _deliveryUnavailableReason = responseData['message'] ??
              'Unable to calculate delivery fee. Please try again.';
          _isCalculatingDeliveryFee = false;
        });
      }
    } catch (e) {
      print('Error calculating delivery fee: $e');
      setState(() {
        _isDeliveryAvailable = false;
        _deliveryUnavailableReason =
        'Failed to connect to delivery service. Please check your internet connection.';
        _isCalculatingDeliveryFee = false;
      });
    }
  }

  // ==============================================
  // LOAD SAVED ADDRESS
  // ==============================================
  Future<void> _loadUserAddress() async {
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
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success' && responseData['data'] != null) {
        var data = responseData['data'];
        setState(() {
          _addressController.text = data['address'] ?? '';
          _cityController.text = data['city'] ?? '';
          _postalCodeController.text = data['postal_code'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _deliveryLatitude = data['latitude'] ?? '';
          _deliveryLongitude = data['longitude'] ?? '';
          _hasSavedAddress = true;
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _hasSavedAddress = false;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  // ==============================================
  // LOAD DELIVERY SLOTS
  // ==============================================
  Future<void> _loadDeliverySlots() async {
    setState(() {
      _isLoadingSlots = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _deliverySlots = [
        '12:00PM to 1:00PM',
        '1:00PM to 2:00PM',
        '11:30AM to 12PM',
        '12:00PM to 12:30PM',
        '12:30PM to 1:00PM',
        '1:00PM to 1:30PM',
        '1:30PM to 2:00PM',
        '2:00PM to 2:30PM',
        '2:30PM to 3:00PM',
        '6:00PM to 6:30PM',
        '6:30PM to 7:00PM',
        '7:00PM to 7:30PM',
        '7:30PM to 8:00PM',
        '8:00PM to 8:30PM',
        '8:30PM to 9:00PM',
      ];
      _selectedDeliverySlot = _deliverySlots[0];
      _isLoadingSlots = false;
    });
  }

  // ==============================================
  // CALCULATIONS
  // ==============================================
  double get subtotal => _localTotal;

// ✅ Pickup = no delivery fee; Delivery = subtotal + fee
  double get effectiveDeliveryFee =>
      _deliveryOption == 'pickup' ? 0.0 : _deliveryFee;

  double get grandTotal => subtotal + effectiveDeliveryFee;

// ==============================================
// SHOW DELIVERY FEE INFO DIALOG
// ==============================================
  void _showDeliveryFeeInfo() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delivery Fee Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Distance',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${_distance.toStringAsFixed(1)} $_distanceUnit',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildRateRow('0 - 3 miles', '\$8.00',
                          _distance <= 3 && _distance > 0),
                      const Divider(height: 8),
                      _buildRateRow('3 - 5 miles', '\$10.00',
                          _distance > 3 && _distance <= 5),
                      const Divider(height: 8),
                      _buildRateRow('5 - 10 miles', '\$12.00',
                          _distance > 5 && _distance <= 10),
                      const Divider(height: 8),
                      _buildRateRow('10 - 15 miles', '\$14.00',
                          _distance > 10 && _distance <= 15),
                      const Divider(height: 8),
                      _buildRateRow(
                          '15+ miles', 'Not Available', _distance > 15),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isDeliveryAvailable
                        ? Colors.green.withOpacity(0.08)
                        : Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDeliveryAvailable
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isDeliveryAvailable
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: _isDeliveryAvailable
                            ? Colors.green[700]
                            : Colors.red[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isDeliveryAvailable
                              ? '✅ Delivery available to your location!'
                              : '❌ Delivery not available to your location',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _isDeliveryAvailable
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Got it',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildRateRow(String range, String fee, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.circle,
            size: 14,
            color: isActive ? const Color(0xFFF97316) : Colors.grey[300],
          ),
          const SizedBox(width: 8),
          Text(
            range,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isActive ? const Color(0xFF1C1C1E) : Colors.grey[500],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            fee,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isActive ? const Color(0xFFF97316) : Colors.grey[500],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOrderNotifications({
    required String orderId,
    required String customerName,
    required String orderTotal,
    required String locationName,
    required String paymentMethod,
  }) async {
    try {
      print('==========================================');
      print('📤 SENDING ORDER NOTIFICATION');
      print('==========================================');
      print('📦 Order ID: $orderId');
      print('👤 Customer: $customerName');
      print('💰 Total: $orderTotal');
      print('📍 Location: $locationName');

      final response = await http.post(
        Uri.parse(
          'https://quantorra.co/tiffinwales/send_notification.php',
        ),
        body: {
          'action': 'notify_order_placed',
          'location_name': locationName,
          'order_id': orderId,
          'customer_name': customerName,
          'order_total': orderTotal,
          'priority': 'high',
          'payment_method': paymentMethod,
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        print('❌ Notification API failed');
        return;
      }

      final result = jsonDecode(response.body);
      print('📊 Status: ${result['status']}');
    } catch (e) {
      print('❌ ORDER NOTIFICATION ERROR: $e');
    }
  }

  // ==============================================
  // PLACE ORDER LOGIC
  // ==============================================
  Future<void> _placeOrder() async {
    if (_isPlacingOrder) return;

// ✅ Require phone number validation (from _formKey)
    if (!_formKey.currentState!.validate()) return;

// ✅ Explicit phone check (belt-and-suspenders)
    if (_phoneController.text
        .trim()
        .isEmpty) {
      _snack('Phone number is required to place an order', Colors.red);
      return;
    }
    if (_phoneController.text
        .trim()
        .length < 10) {
      _snack('Please enter a valid 10-digit phone number', Colors.red);
      return;
    }

// ✅ Only block if Delivery is selected AND unavailable
    if (_deliveryOption == 'delivery' && !_isDeliveryAvailable) return;

    // ---------------------------------------------------------
    // Resolve card data — either from secure storage or manual entry
    // ---------------------------------------------------------
    String cardNumber;
    String expiry;
    String cvc;

    if (_useSavedCard && _savedCardDisplay != null) {
      // Pull full card from secure storage only when placing order
      final savedCard = await SecureCardService.loadCard();
      if (savedCard == null) {
        _snack(
            'Saved card is no longer available. Please re-enter.', Colors.red);
        setState(() {
          _useSavedCard = false;
          _savedCardDisplay = null;
        });
        return;
      }
      cardNumber = savedCard.cardNumber;
      expiry = savedCard.expiry;
      // ⚠️ We NEVER store CVV. Ask the user every time.
      if (_cvcController.text.isEmpty) {
        _snack('Please enter the CVC for your saved card', Colors.orange);
        return;
      }
      cvc = _cvcController.text;
    } else {
      if (_cardNumberController.text.isEmpty ||
          _expiryController.text.isEmpty ||
          _cvcController.text.isEmpty) {
        _snack('Please enter valid card details', Colors.red);
        return;
      }
      cardNumber = _cardNumberController.text.replaceAll(' ', '');
      expiry = _expiryController.text;
      cvc = _cvcController.text;
    }

    setState(() {
      _isPlacingOrder = true;
      _isLoading = true;
    });

    try {
      final orderId = 'ORD-${DateTime
          .now()
          .millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse('https://quantorra.co/tiffinwales/create_halo_payment.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': grandTotal.toStringAsFixed(2),
          'currency': 'USD',
          'order_id': orderId,
          'card': {
            'number': cardNumber,
            'expiration_date': expiry,
            'cvc': cvc,
          },
          'billing': {
            'first_name': _nameController.text
                .split(' ')
                .first,
            'last_name': _nameController.text.split(' ').skip(1).join(' '),
            'email': widget.email,
            'phone': _phoneController.text,
            'address_line_1': _addressController.text,
            'city': _cityController.text,
            'state': '',
            'postal_code': _postalCodeController.text,
            'country': 'US',
          }
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // ✅ Save card AFTER successful payment (only if user opted in and
        // this was a manual entry, not a saved card)
        if (!_useSavedCard && _saveCardAfterOrder) {
          await SecureCardService.saveCard(
            cardNumber: cardNumber,
            expiry: expiry,
            holderName: _nameController.text.trim(),
          );
          // Refresh display
          final d = await SecureCardService.loadDisplayInfo();
          if (mounted) setState(() => _savedCardDisplay = d);
        }

        await _finalizeOrder(orderId, 'paid', data['transaction_id']);
      } else {
        throw Exception(data['message'] ?? 'Payment failed');
      }
    } catch (e) {
      setState(() {
        _isPlacingOrder = false;
        _isLoading = false;
      });
      _snack('Payment Error: ${e.toString()}', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _initiateHaloPayment() async {
    setState(() {
      _isPlacingOrder = true;
      _isLoading = true;
    });

    try {
      final orderId = 'ORD-${DateTime
          .now()
          .millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse(haloPaymentApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'order_id': orderId,
          'amount': grandTotal.toStringAsFixed(2),
          'currency': 'USD',
          'customer_name': _nameController.text.trim(),
          'customer_email': widget.email,
          'customer_phone': _phoneController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));
      print('🔍 RAW RESPONSE: ${response.body}');
      final data = jsonDecode(response.body);

      if (data['status'] == 'success' && data['payment_url'] != null) {
        setState(() {
          _paymentUrl = data['payment_url'];
          _isPlacingOrder = false;
          _isLoading = false;
        });
        _showPaymentWebView(orderId);
      } else {
        throw Exception(data['message'] ?? 'Failed to initialize payment');
      }
    } catch (e) {
      setState(() {
        _isPlacingOrder = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Payment Error: ${e.toString()}');
    }
  }

  void _showPaymentWebView(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              height: MediaQuery
                  .of(context)
                  .size
                  .height * 0.85,
              width: double.infinity,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    title: const Text('Secure Halo Payment',
                        style: TextStyle(color: Colors.black)),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                          _showRetryDialog(orderId);
                        },
                      )
                    ],
                  ),
                  Expanded(
                    child: WebViewWidget(
                      controller: WebViewController()
                        ..setJavaScriptMode(JavaScriptMode.unrestricted)
                        ..setNavigationDelegate(
                          NavigationDelegate(
                            onPageStarted: (url) =>
                                setState(() => _isWebViewLoading = true),
                            onPageFinished: (url) {
                              setState(() => _isWebViewLoading = false);

                              if (url.contains('payment_return.php') ||
                                  url.contains('status=success')) {
                                Navigator.pop(context);
                                _finalizeOrder(orderId, 'paid', null);
                              } else if (url.contains('status=failed') ||
                                  url.contains('cancel')) {
                                Navigator.pop(context);
                                _showRetryDialog(orderId);
                              }
                            },
                          ),
                        )
                        ..loadRequest(Uri.parse(_paymentUrl!)),
                    ),
                  ),
                  if (_isWebViewLoading) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
    );
  }

  void _showRetryDialog(String orderId) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Payment Incomplete'),
            content: const Text(
                'Your order was not completed. Would you like to try paying again?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _initiateHaloPayment();
                },
                child: const Text('Retry Payment'),
              ),
            ],
          ),
    );
  }

  Future<void> _finalizeOrder(String orderId, String paymentStatus,
      String? transactionId) async {
    setState(() {
      _isPlacingOrder = true;
      _isLoading = true;
    });

    try {
      Map<String, dynamic> orderData = {
        'action': 'place_order',
        'order_id': orderId,
        'email': widget.email,
        'location_name': widget.locationName,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'delivery_slot': _selectedDeliverySlot ?? '',
        'delivery_option': _deliveryOption,
        // ✅ NEW
        'payment_method': 'Halo Payments',
        'payment_status': paymentStatus,
        'special_instructions': _specialInstructionsController.text.trim(),
        'subtotal': subtotal.toStringAsFixed(2),
        'delivery_fee': effectiveDeliveryFee.toStringAsFixed(2),
        // ✅ 0 for pickup
        'service_charge': '0.00',
        'tax': '0.00',
        'total': grandTotal.toStringAsFixed(2),
        'distance': _deliveryOption == 'pickup'
            ? '0.00'
            : _distance.toStringAsFixed(2),
        'currency': 'USD',
        'items': jsonEncode(_localCartItems),
        'order_status': 'confirmed',
        'payment_id': transactionId ?? '',
      };

      var request = http.MultipartRequest('POST', Uri.parse(orderApiUrl));
      request.fields.addAll(
          orderData.map((key, value) => MapEntry(key, value.toString())));

      var streamedResponse = await request.send();
      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        await _sendOrderNotifications(
          orderId: orderId,
          customerName: _nameController.text.trim(),
          orderTotal: grandTotal.toStringAsFixed(2),
          locationName: widget.locationName,
          paymentMethod: 'Halo Payments',
        );
        await _clearCart();

        _showOrderSuccessDialog(
          orderId: orderId,
          customerName: _nameController.text.trim(),
          total: grandTotal,
          paymentMethod: 'Halo Payments',
        );
      }
    } catch (e) {
      print("Error finalizing online order: $e");
    } finally {
      setState(() {
        _isPlacingOrder = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCart() async {
    try {
      print('🗑️ Clearing cart for user: ${widget.email}');
      var request = http.MultipartRequest('POST', Uri.parse(cartApiUrl));
      request.fields['action'] = 'clear_cart';
      request.fields['email'] = widget.email;
      await request.send().timeout(const Duration(seconds: 10));
      print('✅ Cart cleared successfully');
    } catch (e) {
      print('❌ Error clearing cart: $e');
    }
  }

  void _showOrderSuccessDialog({
    required String orderId,
    required String customerName,
    required double total,
    required String paymentMethod,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Order Placed! 🎉',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your order has been placed successfully!',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order ID:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            orderId,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_deliveryOption == 'pickup' ? 'Pickup' : 'Estimated Delivery'}: ${_selectedDeliverySlot ?? "30-45 min"}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.green[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '✅ Managers have been notified about your order',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Payment: $paymentMethod',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue to Home',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _specialInstructionsController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    super.dispose();
  }

// ==============================================
// DELIVERY / PICKUP SELECTOR
// ==============================================
  Widget _buildDeliveryOptionSelector() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delivery_dining, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Type',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDeliveryOptionButton(
                  icon: Icons.delivery_dining,
                  label: 'Delivery',
                  value: 'delivery',
                  primaryColor: primaryColor,
                  subtitle: _deliveryOption == 'delivery' &&
                      _isDeliveryAvailable
                      ? '\$${_deliveryFee.toStringAsFixed(2)} fee'
                      : _deliveryOption == 'delivery' && !_isDeliveryAvailable
                      ? 'Not available'
                      : 'Home delivery',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDeliveryOptionButton(
                  icon: Icons.storefront,
                  label: 'Pickup',
                  value: 'pickup',
                  primaryColor: primaryColor,
                  subtitle: 'Free • Ready in 20 min',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOptionButton({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
    required String subtitle,
  }) {
    final isSelected = _deliveryOption == value;
    final isDeliveryUnavailable = value == 'delivery' &&
        !_isDeliveryAvailable && !_isCalculatingDeliveryFee;

    return GestureDetector(
      onTap: isDeliveryUnavailable
          ? null
          : () => setState(() => _deliveryOption = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [primaryColor, primaryColor.withOpacity(0.85)],
          )
              : null,
          color: isSelected
              ? null
              : (isDeliveryUnavailable ? Colors.grey[100] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDeliveryUnavailable ? Colors.grey[200]! : Colors
                .grey[200]!),
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
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : (isDeliveryUnavailable
                      ? Colors.grey[400]
                      : primaryColor),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDeliveryUnavailable
                        ? Colors.grey[400]
                        : const Color(0xFF1C1C1E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white.withOpacity(0.85)
                    : (isDeliveryUnavailable
                    ? Colors.red[400]
                    : Colors.grey[600]),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);
    const Color lightBg = Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Place Order',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_localCartItems.length} items', // ✅ Use local cart count
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : Column(
          children: [
            if (!_isDeliveryAvailable && !_isCalculatingDeliveryFee) ...[
              _buildDeliveryUnavailableBanner(),
            ],
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeliveryOptionSelector(), // ✅ NEW
                    const SizedBox(height: 16),
                    _buildOrderSummary(),
                    const SizedBox(height: 16),
                    _buildInlineSuggestions(),
                    const SizedBox(height: 8),
                    _buildDeliveryAddress(),
                    const SizedBox(height: 16),
                    _buildDeliveryTime(),
                    const SizedBox(height: 16),
                    _buildPaymentMethod(),
                    const SizedBox(height: 16),
                    _buildSpecialInstructions(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
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
            _isPlacingOrder
                ? 'Placing your order...\nNotifying managers...'
                : 'Loading...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (_isPlacingOrder) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sending HIGH PRIORITY notifications...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryUnavailableBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Not Available',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _deliveryUnavailableReason,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Summary',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ✅ Use _localCartItems (updates in real-time)
          ..._localCartItems.map((item) {
            final price = double.tryParse(
              item['item_price']
                  ?.toString()
                  .replaceAll(RegExp(r'[^\d.]'), '') ??
                  item['price']
                      ?.toString()
                      .replaceAll(RegExp(r'[^\d.]'), '') ??
                  '0',
            ) ??
                0;
            final quantity =
                int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
            final name = item['item_name'] ?? item['name'] ?? 'Unknown';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$quantity',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Text(
                    '\$${(price * quantity).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 20),
          _buildPriceRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),

// ✅ Delivery Fee row — with info icon + pickup handling
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Delivery Fee',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_deliveryOption == 'delivery') ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _showDeliveryFeeInfo,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(0xFFF97316),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                _deliveryOption == 'pickup'
                    ? 'Free (Pickup)'
                    : _isCalculatingDeliveryFee
                    ? 'Calculating...'
                    : _isDeliveryAvailable
                    ? '\$${_deliveryFee.toStringAsFixed(2)}'
                    : 'N/A',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _deliveryOption == 'pickup'
                      ? Colors.green[700]
                      : _isCalculatingDeliveryFee
                      ? Colors.grey[400]
                      : _isDeliveryAvailable
                      ? Colors.grey[800]
                      : Colors.red,
                ),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 2),
          _buildPriceRow(
            'Grand Total',
            (_deliveryOption == 'pickup' || _isDeliveryAvailable)
                ? '\$${grandTotal.toStringAsFixed(2)}'
                : 'Not Available',
            isTotal: true,
          ),
          if (_deliveryOption == 'delivery' &&
              _distance > 0 &&
              _isDeliveryAvailable) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.blue[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Distance: ${_distance.toStringAsFixed(
                        1)} $_distanceUnit from restaurant',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
              color: isTotal ? darkColor : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? primaryColor : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Delivery Address',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: darkColor,
                  ),
                ),
                const Spacer(),
                if (_isLiveLocation)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live Location',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  if (_hasSavedAddress)
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Saved',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: Color(0xFFF97316), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'Enter your phone number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: Color(0xFFF97316), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Street Address *',
                hintText: 'Enter your street address',
                prefixIcon: const Icon(Icons.home_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: Color(0xFFF97316), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your address';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'City *',
                      hintText: 'Enter city',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Color(0xFFF97316), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _postalCodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Postal Code *',
                      hintText: 'Enter postal code',
                      prefixIcon: const Icon(Icons.pin_drop_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Color(0xFFF97316), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTime() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _deliveryOption == 'pickup' ? 'Pickup Time' : 'Delivery Time',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingSlots
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Color(0xFFF97316),
              ),
            ),
          )
              : Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDeliverySlot,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: darkColor,
                ),
                items: _deliverySlots.map((slot) {
                  return DropdownMenuItem(
                    value: slot,
                    child: Text(slot),
                  );
                }).toList(),
                onChanged: (_deliveryOption == 'pickup' || _isDeliveryAvailable)
                    ? (value) {
                  setState(() {
                    _selectedDeliverySlot = value;
                  });
                }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Method',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ---------- SAVED CARD BANNER ----------
          if (_isLoadingSavedCard)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
              ),
            )
          else
            if (_savedCardDisplay != null) ...[
              _buildSavedCardTile(_savedCardDisplay!),
              const SizedBox(height: 12),
            ],

          // ---------- MANUAL CARD FORM ----------
          // Only show the manual form if:
          //  - no saved card exists, OR
          //  - user tapped "Use different card"
          if (!_useSavedCard || _savedCardDisplay == null) ...[
            TextFormField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
              ],
              decoration: InputDecoration(
                labelText: 'Card Number',
                hintText: '4111 1111 1111 1111',
                prefixIcon: const Icon(Icons.credit_card_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Expiry (MM/YY)',
                      hintText: '12/25',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvcController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'CVC',
                      hintText: '123',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ---------- SAVE CARD CHECKBOX ----------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _saveCardAfterOrder,
                    activeColor: primaryColor,
                    onChanged: (v) =>
                        setState(() => _saveCardAfterOrder = v ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Save card securely',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: darkColor,
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            ...[
              // "Use a different card" button when a saved card is selected
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _useSavedCard = false;
                    _cardNumberController.clear();
                    _expiryController.clear();
                    _cvcController.clear();
                  });
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  'Use a different card',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildSavedCardTile(SavedCardDisplay card) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.08),
            primaryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Card brand icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _brandIcon(card.brand),
                color: primaryColor,
                size: 22,
              ),
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
                      '${card.brand} •••• ${card.last4}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 9,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Secured',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Expires ${card.expiry}',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Remove saved card button
          IconButton(
            tooltip: 'Forget this card',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
              size: 20,
            ),
            onPressed: () => _showForgetCardDialog(),
          ),
        ],
      ),
    );
  }

  IconData _brandIcon(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  void _showForgetCardDialog() {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Forget saved card?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'You will need to enter your card details again next time.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await SecureCardService.clearCard();
                  if (!mounted) return;
                  setState(() {
                    _savedCardDisplay = null;
                    _useSavedCard = false;
                    _cardNumberController.clear();
                    _expiryController.clear();
                    _cvcController.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saved card removed'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  'Forget',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSpecialInstructions() {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_outlined, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Special Instructions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _specialInstructionsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any special requests for your order?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFF97316), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    const Color primaryColor = Color(0xFFF97316);

    // ✅ Can place order when:
    //   - Pickup selected, OR
    //   - Delivery selected AND delivery is available
    final bool canPlace = !_isPlacingOrder &&
        (_deliveryOption == 'pickup' || _isDeliveryAvailable);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canPlace ? _placeOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canPlace ? primaryColor : Colors.grey[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: canPlace ? 4 : 0,
                shadowColor: canPlace
                    ? primaryColor.withOpacity(0.3)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isPlacingOrder
                        ? Icons.hourglass_empty
                        : canPlace
                        ? Icons.shopping_bag_outlined
                        : Icons.warning_amber_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isPlacingOrder
                        ? 'Processing...'
                        : canPlace
                        ? 'Place Order • \$${grandTotal.toStringAsFixed(2)}'
                        : 'Delivery Not Available',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_deliveryOption == 'pickup' && !_isPlacingOrder) ...[
            const SizedBox(height: 6),
            Text(
              '🏪 Pickup order — no delivery fee',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}