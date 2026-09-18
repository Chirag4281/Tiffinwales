import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ManagerAnalyticsTab extends StatefulWidget {
  final String locationName;
  final String email;

  const ManagerAnalyticsTab({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  State<ManagerAnalyticsTab> createState() => _ManagerAnalyticsTabState();
}

class _ManagerAnalyticsTabState extends State<ManagerAnalyticsTab> {
  bool _isLoading = true;
  String? _errorMessage;

  double _totalRevenue = 0;
  int _totalOrders = 0;
  double _averageOrderValue = 0;
  int _pendingOrders = 0;
  int _completedOrders = 0;
  int _cancelledOrders = 0;
  List<Map<String, dynamic>> _orders = [];

  Map<String, double> _monthlyRevenue = {};
  Map<String, int> _monthlyOrders = {};
  List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _selectedPeriod = 'This Month';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['location_name'] = widget.locationName;
      request.fields['user_type'] = 'admin';
      request.fields['user_role'] = 'manager';

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        _orders = List<Map<String, dynamic>>.from(data['data'] ?? []);
        _calculateAnalytics();
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load data';
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

  void _calculateAnalytics() {
    _totalRevenue = 0;
    _totalOrders = _orders.length;
    _pendingOrders = 0;
    _completedOrders = 0;
    _cancelledOrders = 0;
    _monthlyRevenue = {};
    _monthlyOrders = {};

    for (var order in _orders) {
      final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;
      final status = order['order_status']?.toString().toLowerCase() ?? 'pending';

      if (status == 'delivered' || status == 'completed' || status == 'ready') {
        _totalRevenue += total;
        _completedOrders++;
      } else if (status == 'pending' || status == 'preparing') {
        _pendingOrders++;
      } else if (status == 'cancelled') {
        _cancelledOrders++;
      }

      final createdAt = order['created_at']?.toString() ?? '';
      if (createdAt.isNotEmpty) {
        try {
          final date = DateTime.parse(createdAt);
          final monthName = _months[date.month - 1];

          if (status == 'delivered' || status == 'completed' || status == 'ready') {
            _monthlyRevenue[monthName] = (_monthlyRevenue[monthName] ?? 0) + total;
            _monthlyOrders[monthName] = (_monthlyOrders[monthName] ?? 0) + 1;
          }
        } catch (e) {}
      }
    }

    _averageOrderValue = _completedOrders > 0 ? _totalRevenue / _completedOrders : 0;
  }

  String _getPeriodText() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        return 'Today, ${now.day}/${now.month}/${now.year}';
      case 'This Week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return '${start.day}/${start.month} - ${now.day}/${now.month}';
      case 'This Month':
        return '${_months[now.month - 1]} ${now.year}';
      case 'This Year':
        return '${now.year}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);
    const Color lightBg = Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: lightBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Selector
              _buildPeriodSelector(primaryColor),
              const SizedBox(height: 16),

              // Summary Cards
              _buildSummaryCards(primaryColor, darkColor),
              const SizedBox(height: 16),

              // Revenue Chart
              _buildRevenueChart(primaryColor),
              const SizedBox(height: 16),

              // Order Status Breakdown
              _buildOrderStatusBreakdown(primaryColor),
              const SizedBox(height: 16),

              // Recent Orders
              _buildRecentOrders(primaryColor, darkColor),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
      ),
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards(Color primaryColor, Color darkColor) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Revenue',
            '\$${_totalRevenue.toStringAsFixed(2)}',
            Icons.attach_money_rounded,
            primaryColor,
            Colors.green,
            '${_completedOrders} orders',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Avg Order',
            '\$${_averageOrderValue.toStringAsFixed(2)}',
            Icons.trending_up_rounded,
            primaryColor,
            Colors.blue,
            'Per order average',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title,
      String value,
      IconData icon,
      Color primaryColor,
      Color accentColor,
      String subtitle,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: primaryColor, size: 22),
              const SizedBox(width: 10),
              Text(
                'Revenue Overview',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getPeriodText(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: _monthlyRevenue.isEmpty
                ? Center(
              child: Text(
                'No data available',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            )
                : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _months.map((month) {
                final revenue = _monthlyRevenue[month] ?? 0;
                final maxRevenue = _monthlyRevenue.values.isEmpty
                    ? 1
                    : _monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
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
                        height: height * 0.9,
                        width: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: hasData
                                ? [primaryColor, primaryColor.withOpacity(0.5)]
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
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
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

  Widget _buildOrderStatusBreakdown(Color primaryColor) {
    final total = _pendingOrders + _completedOrders + _cancelledOrders;
    final pendingPercent = total > 0 ? (_pendingOrders / total) * 100 : 0.0;
    final completedPercent = total > 0 ? (_completedOrders / total) * 100 : 0.0;
    final cancelledPercent = total > 0 ? (_cancelledOrders / total) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: primaryColor, size: 22),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_orders.length} total',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusItem('Pending', _pendingOrders, Colors.orange, pendingPercent),
              _buildStatusItem('Completed', _completedOrders, Colors.green, completedPercent),
              _buildStatusItem('Cancelled', _cancelledOrders, Colors.red, cancelledPercent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (pendingPercent > 0)
                Expanded(
                  flex: pendingPercent.toInt(),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              if (completedPercent > 0)
                Expanded(
                  flex: completedPercent.toInt(),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              if (cancelledPercent > 0)
                Expanded(
                  flex: cancelledPercent.toInt(),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(3),
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
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(Color primaryColor, Color darkColor) {
    final recentOrders = _orders.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: primaryColor, size: 22),
              const SizedBox(width: 10),
              Text(
                'Recent Orders',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
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
                        color: _getStatusColor(status).withOpacity(0.12),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: darkColor,
                            ),
                          ),
                          Text(
                            _formatDate(createdAt),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
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
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
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