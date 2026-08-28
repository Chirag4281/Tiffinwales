import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationOrdersPage extends StatefulWidget {
  final String locationName;
  final String email;

  const LocationOrdersPage({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  State<LocationOrdersPage> createState() => _LocationOrdersPageState();
}

class _LocationOrdersPageState extends State<LocationOrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _expandedOrderId;
  String _selectedFilter = 'All';

  final String orderApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // ==============================================
  // LOAD ORDERS FROM API
  // ==============================================
  // In LocationOrdersPage (User view)
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(orderApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['email'] = widget.email;
      request.fields['location_name'] = widget.locationName;
      request.fields['user_type'] = 'normal';
      request.fields['user_role'] = 'user';

      // Shows orders by email AND location

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load orders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }
  // ==============================================
  // GET FIRST ITEM NAME FROM ORDER
  // ==============================================
  String _getFirstItemName(Map<String, dynamic> order) {
    try {
      if (order['items'] != null && order['items'] is String) {
        final String itemsString = order['items'];
        if (itemsString.isNotEmpty && itemsString != 'null') {
          final List<dynamic> items = jsonDecode(itemsString) as List<dynamic>;
          if (items.isNotEmpty) {
            final firstItem = items[0];
            final String itemName = firstItem['item_name'] ?? firstItem['name'] ?? 'Unknown';
            final int quantity = int.tryParse(firstItem['quantity']?.toString() ?? '1') ?? 1;

            if (items.length > 1) {
              return '$itemName (+${items.length - 1} more)';
            }
            return itemName;
          }
        }
      } else if (order['items'] != null && order['items'] is List) {
        final List<dynamic> items = order['items'];
        if (items.isNotEmpty) {
          final firstItem = items[0];
          final String itemName = firstItem['item_name'] ?? firstItem['name'] ?? 'Unknown';
          final int quantity = int.tryParse(firstItem['quantity']?.toString() ?? '1') ?? 1;

          if (items.length > 1) {
            return '$itemName (+${items.length - 1} more)';
          }
          return itemName;
        }
      }
      return 'Unknown Item';
    } catch (e) {
      return 'Unknown Item';
    }
  }

  // ==============================================
  // GET ITEMS LIST FROM ORDER
  // ==============================================
  List<dynamic> _getItemsList(Map<String, dynamic> order) {
    try {
      if (order['items'] != null && order['items'] is String) {
        final String itemsString = order['items'];
        if (itemsString.isNotEmpty && itemsString != 'null') {
          return jsonDecode(itemsString) as List<dynamic>;
        }
      } else if (order['items'] != null && order['items'] is List) {
        return order['items'] as List<dynamic>;
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);
    const Color lightBg = Color(0xFFF7FAFC);

    // Filter orders based on selected filter
    List<Map<String, dynamic>> filteredOrders = _orders;
    if (_selectedFilter != 'All') {
      filteredOrders = _orders.where((order) {
        final status = (order['order_status'] ?? 'pending').toString().toLowerCase();
        return status == _selectedFilter.toLowerCase();
      }).toList();
    }

    return Container(
      color: lightBg,
      child: RefreshIndicator(
        onRefresh: _loadOrders,
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // Header
                    _buildHeader(primaryColor, darkColor),
                    const SizedBox(height: 16),

                    if (_isLoading)
                      _buildLoadingState()
                    else if (_errorMessage != null)
                      _buildErrorState(primaryColor, darkColor)
                    else if (_orders.isEmpty)
                        _buildEmptyState(primaryColor, darkColor)
                      else if (filteredOrders.isEmpty)
                          _buildEmptyFilterState(primaryColor, darkColor)
                        else
                          ...filteredOrders.map((order) => _buildOrderCard(order, primaryColor, darkColor)).toList(),

                    const SizedBox(height: 30),
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
  // BUILD METHODS
  // ==============================================

  Widget _buildHeader(Color primaryColor, Color darkColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            const Color(0xFF8B5CF6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Orders',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Order history from ${widget.locationName}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoading && _orders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_orders.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (!_isLoading && _orders.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterChip('All', _selectedFilter == 'All', primaryColor),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Pending', _selectedFilter == 'Pending', primaryColor),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Preparing', _selectedFilter == 'Preparing', primaryColor),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Delivered', _selectedFilter == 'Delivered', primaryColor),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Cancelled', _selectedFilter == 'Cancelled', primaryColor),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, bool isSelected, Color primaryColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? primaryColor : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your orders...',
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

  Widget _buildErrorState(Color primaryColor, Color darkColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Orders',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor, Color darkColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 60,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Orders Yet',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your orders will appear here once you place them',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Refresh',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState(Color primaryColor, Color darkColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No $_selectedFilter orders',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the filter',
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

  Widget _buildOrderCard(Map<String, dynamic> order, Color primaryColor, Color darkColor) {
    final int orderId = order['id'] ?? 0;
    final bool isExpanded = _expandedOrderId == orderId;

    // Get first item name
    final String firstItemName = _getFirstItemName(order);

    // Get all items for expanded view
    final List<dynamic> items = _getItemsList(order);

    final String status = (order['order_status'] ?? 'pending').toString().toLowerCase();
    final String customerName = order['name'] ?? 'Guest';
    final String phone = order['phone'] ?? 'N/A';
    final String address = order['address'] ?? 'N/A';
    final String city = order['city'] ?? '';
    final String postalCode = order['postal_code'] ?? '';
    final String deliverySlot = order['delivery_slot'] ?? 'ASAP';
    final String paymentMethod = order['payment_method'] ?? 'Cash on Delivery';
    final String createdAt = order['created_at'] ?? '';
    final String specialInstructions = order['special_instructions'] ?? '';
    final double total = double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
    final double subtotal = double.tryParse(order['subtotal']?.toString() ?? '0') ?? 0.0;
    final double deliveryFee = double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0.0;
    final double serviceCharge = double.tryParse(order['service_charge']?.toString() ?? '0') ?? 0.0;
    final double tax = double.tryParse(order['tax']?.toString() ?? '0') ?? 0.0;

    String formattedDate = _formatDate(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isExpanded ? primaryColor.withOpacity(0.2) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedOrderId = isExpanded ? null : orderId;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Order Info - Now shows item name instead of customer name
                  Expanded(
                    child: Row(
                      children: [

                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                firstItemName, // Display first item name instead of customer name
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: darkColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 10,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
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
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(status),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(status),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Name
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Customer: ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            customerName,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Delivery Details
                  _buildInfoCard(
                    title: 'Delivery Details',
                    icon: Icons.location_on_outlined,
                    children: [
                      _buildInfoRow(Icons.phone_outlined, 'Phone', phone),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'Address',
                        address + (city.isNotEmpty ? ', $city' : '') + (postalCode.isNotEmpty ? ' - $postalCode' : ''),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Order Items
                  if (items.isNotEmpty) ...[
                    _buildInfoCard(
                      title: 'Order Items (${items.length})',
                      icon: Icons.shopping_bag_outlined,
                      children: items.map((item) => _buildItemRow(item, primaryColor)).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Delivery & Payment
                  _buildInfoCard(
                    title: 'Delivery & Payment',
                    icon: Icons.payment_outlined,
                    children: [
                      _buildInfoRow(Icons.access_time, 'Delivery Slot', deliverySlot),
                      _buildInfoRow(Icons.payment, 'Payment Method', paymentMethod),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Special Instructions
                  if (specialInstructions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note_outlined, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Special Instructions',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[700],
                                  ),
                                ),
                                Text(
                                  specialInstructions,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Price Breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Subtotal', subtotal),
                        if (deliveryFee > 0) _buildPriceRow('Delivery Fee', deliveryFee),
                        if (serviceCharge > 0) _buildPriceRow('Service Charge', serviceCharge),
                        if (tax > 0) _buildPriceRow('Tax', tax),
                        const Divider(height: 12),
                        _buildPriceRow('Total', total, isTotal: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Order Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Order placed on ${_formatFullDate(createdAt)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item, Color primaryColor) {
    final String name = item['item_name'] ?? item['name'] ?? 'Unknown';
    final int quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
    final double price = double.tryParse(item['item_price']?.toString() ?? '0') ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
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
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
          Text(
            '\$${(price * quantity).toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A202C),
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
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
              color: isTotal ? darkColor : Colors.grey[600],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? primaryColor : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // HELPER METHODS
  // ==============================================

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Just now';
    try {
      final DateTime date = DateTime.parse(dateString);
      final DateTime now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  String _formatFullDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'completed':
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }
}