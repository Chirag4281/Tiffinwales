import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedLocation = 'All Locations';
  String _selectedPeriod = 'This Month';

  final List<String> _locations = ['All Locations'];
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  // Analytics Data
  Map<String, dynamic> _analytics = {
    'total_locations': 0,
    'total_orders': 0,
    'total_revenue': 0.0,
    'total_menu_items': 0,
    'pending_orders': 0,
    'completed_orders': 0,
    'cancelled_orders': 0,
    'monthly_revenue': {},
    'category_sales': {},
    'recent_orders': [],
    'top_items': [],
    'location_data': {},
    'daily_stats': {},
    'branch_stats': {},
  };

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';
  final String locationsApiUrl = 'https://quantorra.co/tiffinwales/Locations.php';
  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(locationsApiUrl));
      request.fields['action'] = 'get_locations';
      var response = await request.send();
      var body = await response.stream.bytesToString();
      var data = json.decode(body);

      if (data['status'] == 'success') {
        final locations = List<Map<String, dynamic>>.from(data['data'] ?? []);
        setState(() {
          _locations.clear();
          _locations.add('All Locations');
          _locations.addAll(locations.map((loc) => loc['name'] as String));
        });
        _loadAnalytics();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load locations';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load orders with location filter
      var orderRequest = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      orderRequest.fields['action'] = 'get_orders';
      orderRequest.fields['user_type'] = 'admin';
      orderRequest.fields['user_role'] = 'master';

      // CRITICAL FIX: Always send location_name, even for 'All Locations'
      // The API will handle the filtering
      if (_selectedLocation != 'All Locations') {
        orderRequest.fields['location_name'] = _selectedLocation;
      } else {
        // For 'All Locations', we don't send location_name to get all
        // Or we can send a special flag
      }

      var orderResponse = await orderRequest.send();
      var orderBody = await orderResponse.stream.bytesToString();
      var orderData = json.decode(orderBody);

      if (orderData['status'] == 'success') {
        final orders = List<Map<String, dynamic>>.from(orderData['data'] ?? []);

        // DEBUG: Log to see what we're getting
        print('Location filter: $_selectedLocation');
        print('Orders received: ${orders.length}');
        if (orders.isNotEmpty) {
          print('First order location: ${orders[0]['location_name']}');
        }

        _processAnalytics(orders);
      } else {
        _resetAnalytics();
      }

      // Load locations count
      var locRequest = http.MultipartRequest('POST', Uri.parse(locationsApiUrl));
      locRequest.fields['action'] = 'get_locations';
      var locResponse = await locRequest.send();
      var locBody = await locResponse.stream.bytesToString();
      var locData = json.decode(locBody);
      if (locData['status'] == 'success') {
        _analytics['total_locations'] = (locData['data'] as List).length;
      }

      // Load menu items count
      var menuRequest = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      menuRequest.fields['action'] = 'get_all_menus';
      var menuResponse = await menuRequest.send();
      var menuBody = await menuResponse.stream.bytesToString();
      var menuData = json.decode(menuBody);
      if (menuData['status'] == 'success') {
        _analytics['total_menu_items'] = (menuData['data'] as List).length;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _resetAnalytics() {
    _analytics['total_orders'] = 0;
    _analytics['total_revenue'] = 0.0;
    _analytics['pending_orders'] = 0;
    _analytics['completed_orders'] = 0;
    _analytics['cancelled_orders'] = 0;
    _analytics['monthly_revenue'] = {};
    _analytics['category_sales'] = {};
    _analytics['recent_orders'] = [];
    _analytics['top_items'] = [];
    _analytics['location_data'] = {};
  }

  void _processAnalytics(List<Map<String, dynamic>> orders) {
    // Filter orders by location if a specific location is selected
    List<Map<String, dynamic>> filteredOrders = orders;
    if (_selectedLocation != 'All Locations') {
      filteredOrders = orders.where((order) {
        final orderLocation = order['location_name']?.toString() ?? '';
        return orderLocation == _selectedLocation;
      }).toList();
    }

    _analytics['total_orders'] = filteredOrders.length;
    _analytics['recent_orders'] = filteredOrders.take(5).toList();

    double revenue = 0;
    int pending = 0, completed = 0, cancelled = 0;
    Map<String, double> monthlyRevenue = {};
    Map<String, double> categorySales = {};
    Map<String, double> itemSales = {};
    Map<String, Map<String, dynamic>> locationData = {};

    for (var order in filteredOrders) {
      final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;
      final status = order['order_status']?.toString().toLowerCase() ?? 'pending';
      final createdAt = order['created_at']?.toString() ?? '';
      final locationName = order['location_name']?.toString() ?? 'Unknown';

      // Location wise data
      if (!locationData.containsKey(locationName)) {
        locationData[locationName] = {
          'revenue': 0.0,
          'orders': 0,
          'completed': 0,
        };
      }

      // Revenue and status counts
      if (status == 'delivered' || status == 'completed' || status == 'ready') {
        revenue += total;
        completed++;
        locationData[locationName]!['revenue'] = (locationData[locationName]!['revenue'] as double) + total;
        locationData[locationName]!['completed'] = (locationData[locationName]!['completed'] as int) + 1;
      } else if (status == 'pending' || status == 'preparing') {
        pending++;
      } else if (status == 'cancelled') {
        cancelled++;
      }
      locationData[locationName]!['orders'] = (locationData[locationName]!['orders'] as int) + 1;

      // Monthly revenue
      if (createdAt.isNotEmpty) {
        try {
          final date = DateTime.parse(createdAt);
          final monthName = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1];
          if (status == 'delivered' || status == 'completed' || status == 'ready') {
            monthlyRevenue[monthName] = (monthlyRevenue[monthName] ?? 0) + total;
          }

          // Category and item sales
          final items = order['items'];
          if (items != null) {
            List<dynamic> itemList;
            if (items is String) {
              itemList = jsonDecode(items) as List<dynamic>;
            } else if (items is List) {
              itemList = items;
            } else {
              itemList = [];
            }

            for (var item in itemList) {
              final itemName = item['item_name'] ?? item['name'] ?? 'Unknown';
              final itemPrice = double.tryParse(item['item_price']?.toString() ?? '0') ?? 0;
              final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
              final category = item['category'] ?? 'Main Course';

              final itemTotal = itemPrice * quantity;
              itemSales[itemName] = (itemSales[itemName] ?? 0) + itemTotal;
              categorySales[category] = (categorySales[category] ?? 0) + itemTotal;
            }
          }
        } catch (e) {}
      }
    }

    _analytics['total_revenue'] = revenue;
    _analytics['pending_orders'] = pending;
    _analytics['completed_orders'] = completed;
    _analytics['cancelled_orders'] = cancelled;
    _analytics['monthly_revenue'] = monthlyRevenue;
    _analytics['category_sales'] = categorySales;
    _analytics['location_data'] = locationData;

    // Top selling items
    final sortedItems = itemSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _analytics['top_items'] = sortedItems.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316); // Tiffin Wales orange
    const Color secondaryColor = Color(0xFFEA580C);
    const Color lightPurple = Color(0xFFFFF3E8);
    const Color darkColor = Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _isLoading
          ? _buildLoadingState(primaryColor)
          : _errorMessage != null
          ? _buildErrorState(primaryColor)
          : RefreshIndicator(
        onRefresh: _loadAnalytics,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(primaryColor),
                const SizedBox(height: 16),
                _buildBranchSelector(primaryColor),
                const SizedBox(height: 16),
                _buildStatsGrid(primaryColor),
                const SizedBox(height: 16),
                _buildRevenueChart(primaryColor),
                const SizedBox(height: 16),
                _buildQuickStats(primaryColor),
                const SizedBox(height: 16),
                _buildCategorySales(primaryColor),
                const SizedBox(height: 16),
                _buildTopItems(primaryColor),
                const SizedBox(height: 16),
                _buildRecentOrders(primaryColor),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Dashboard...',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              icon: const Icon(Icons.refresh_rounded),
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

  Widget _buildHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF97316),
            Color(0xFFEA580C),
            Color(0xFFFB923C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
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
                      'Dashboard',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _selectedLocation == 'All Locations'
                          ? 'All Branches Overview'
                          : '$_selectedLocation Branch',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getCurrentDate(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Revenue: \$${_analytics['total_revenue'].toStringAsFixed(2)} | Orders: ${_analytics['total_orders']} | Locations: ${_analytics['total_locations']}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1]} ${now.year}';
  }

  Widget _buildBranchSelector(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8), // Light orange background
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedLocation,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: primaryColor, size: 28),
                iconSize: 28,
                decoration: InputDecoration(
                  labelText: '📍 Branch',
                  labelStyle: GoogleFonts.poppins(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                dropdownColor: Colors.white,
                items: _locations.map((location) {
                  return DropdownMenuItem<String>(
                    value: location,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        location,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1C1C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLocation = value!;
                    _loadAnalytics();
                  });
                },
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8), // Light orange background
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedPeriod,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: primaryColor, size: 28),
                iconSize: 28,
                decoration: InputDecoration(
                  labelText: '📅 Period',
                  labelStyle: GoogleFonts.poppins(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                dropdownColor: Colors.white,
                items: _periods.map((period) {
                  return DropdownMenuItem<String>(
                    value: period,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        period,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1C1C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                    _loadAnalytics();
                  });
                },
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Color primaryColor) {
    final stats = [
      {
        'title': 'Total Revenue',
        'value': '\$${_analytics['total_revenue'].toStringAsFixed(2)}',
        'icon': Icons.attach_money_rounded,
        'color': primaryColor,
        'bgColor': const Color(0xFFFFF3E8),
        'subtitle': '${_analytics['completed_orders']} completed',
      },
      {
        'title': 'Total Orders',
        'value': _analytics['total_orders'].toString(),
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFF22C55E),
        'bgColor': const Color(0xFFDCFCE7),
        'subtitle': '${_analytics['pending_orders']} pending',
      },
      {
        'title': 'Locations',
        'value': _analytics['total_locations'].toString(),
        'icon': Icons.location_on_rounded,
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFEFF6FF),
        'subtitle': 'Active branches',
      },
      {
        'title': 'Menu Items',
        'value': _analytics['total_menu_items'].toString(),
        'icon': Icons.restaurant_menu_rounded,
        'color': const Color(0xFFEF4444),
        'bgColor': const Color(0xFFFEE2E2),
        'subtitle': 'Total dishes',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: (stat['color'] as Color).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stat['bgColor'] as Color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 20,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat['value'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    stat['title'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    stat['subtitle'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueChart(Color primaryColor) {
    final monthlyData = _analytics['monthly_revenue'] as Map<String, dynamic>;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    double maxRevenue = 1.0;
    if (monthlyData.isNotEmpty) {
      final values = monthlyData.values.map((v) => (v as num).toDouble()).toList();
      maxRevenue = values.reduce((a, b) => a > b ? a : b);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bar_chart_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Revenue Trend',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Monthly',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (monthlyData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  'No revenue data available',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: months.map((month) {
                  final revenue = (monthlyData[month] as num?)?.toDouble() ?? 0.0;
                  final height = maxRevenue > 0 ? (revenue / maxRevenue) * 100 : 0;
                  final hasData = revenue > 0;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hasData)
                          Text(
                            '\$${revenue.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        Container(
                          height: height * 0.85,
                          width: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: hasData
                                  ? [primaryColor, primaryColor.withOpacity(0.4)]
                                  : [Colors.grey[200]!, Colors.grey[200]!],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          month,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Color primaryColor) {
    final pending = _analytics['pending_orders'] ?? 0;
    final completed = _analytics['completed_orders'] ?? 0;
    final cancelled = _analytics['cancelled_orders'] ?? 0;
    final total = pending + completed + cancelled;

    final pendingPercent = total > 0 ? (pending / total) * 100 : 0.0;
    final completedPercent = total > 0 ? (completed / total) * 100 : 0.0;
    final cancelledPercent = total > 0 ? (cancelled / total) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.pie_chart_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Order Status',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              Text(
                '${_analytics['total_orders']} total',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusItem('Pending', pending, Colors.orange, pendingPercent),
              _buildStatusItem('Completed', completed, Colors.green, completedPercent),
              _buildStatusItem('Cancelled', cancelled, Colors.red, cancelledPercent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (pendingPercent > 0)
                Expanded(
                  flex: pendingPercent.toInt(),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              if (completedPercent > 0)
                Expanded(
                  flex: completedPercent.toInt(),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              if (cancelledPercent > 0)
                Expanded(
                  flex: cancelledPercent.toInt(),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color, double percent) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySales(Color primaryColor) {
    final categoryData = _analytics['category_sales'] as Map<String, dynamic>? ?? {};
    final categories = categoryData.keys.toList();
    final colors = [
      primaryColor,
      const Color(0xFF22C55E),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFFEA580C),
      const Color(0xFFF59E0B),
    ];

    final total = categoryData.values.fold(0.0, (sum, value) => sum + (value as num).toDouble());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.category_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Category Sales',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No category data available',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...categories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final value = (categoryData[category] as num).toDouble();
              final percentage = total > 0 ? (value / total) * 100 : 0;
              final color = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                        Text(
                          '\$${value.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        color: color,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopItems(Color primaryColor) {
    final topItems = _analytics['top_items'] as List<dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.trending_up_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Top Selling Items',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              Text(
                '${topItems.length} items',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No sales data available',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...topItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final itemName = item.key;
              final sales = item.value;
              final colors = [primaryColor, const Color(0xFFEA580C), const Color(0xFFFB923C)];

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[100]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index < 3 ? colors[index].withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: index < 3 ? colors[index] : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: index < 3 ? colors[index] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        itemName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                    Text(
                      '\$${sales.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(Color primaryColor) {
    final recentOrders = _analytics['recent_orders'] as List<dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Recent Orders',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No recent orders',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                  ),
                ),
              ),
            )
          else
            ...recentOrders.map((order) {
              final status = order['order_status'] ?? 'pending';
              final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;
              final name = order['name'] ?? 'Guest';
              final createdAt = order['created_at'] ?? '';
              final locationName = order['location_name'] ?? 'Unknown';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[100]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                            fontSize: 16,
                          ),
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
                                name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  locationName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _formatDate(createdAt),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return const Color(0xFFF97316);   // Tiffin Wales orange (was Colors.purple)
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          if (diff.inMinutes == 0) return 'Just now';
          return '${diff.inMinutes}m ago';
        }
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}