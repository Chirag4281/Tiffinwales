// lib/screens/subscription_order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';

class SubscriptionOrderDetailsScreen extends StatefulWidget {
  final UserSubscription subscription;
  final String userEmail;

  const SubscriptionOrderDetailsScreen({
    super.key,
    required this.subscription,
    required this.userEmail,
  });

  @override
  State<SubscriptionOrderDetailsScreen> createState() => _SubscriptionOrderDetailsScreenState();
}

class _SubscriptionOrderDetailsScreenState extends State<SubscriptionOrderDetailsScreen> {
  List<Map<String, dynamic>> _orders = [];
  List<String> _deliveredDishes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadDeliveredDishes();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SubscriptionService.getSubscriptionOrders(
        subscriptionId: widget.subscription.id,
        userEmail: widget.userEmail,
      );

      if (response['status'] == 'success' && response['data'] != null) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'No orders found';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ==============================================
  // NEW: Load delivered dishes
  // ==============================================
  Future<void> _loadDeliveredDishes() async {
    try {
      final response = await http.post(
        Uri.parse('https://quantorra.co/tiffinwales/SubscriptionManager.php'),
        body: {
          'action': 'get_delivered_dishes',
          'subscription_id': widget.subscription.id.toString(),
        },
      );

      var data = json.decode(response.body);

      if (data['status'] == 'success' && data['data'] != null) {
        final List<dynamic> deliveredData = data['data'];
        setState(() {
          _deliveredDishes = deliveredData
              .map((item) => item['dish_name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      print('Error loading delivered dishes: $e');
    }
  }

  // ==============================================
  // Helper: Check if dish is delivered
  // ==============================================
  bool _isDishDelivered(String dishName) {
    return _deliveredDishes.contains(dishName);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: darkColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: darkColor, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
            onPressed: () {
              _loadOrders();
              _loadDeliveredDishes();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      )
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadOrders();
                _loadDeliveredDishes();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _orders.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('No orders found for this subscription'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          await _loadOrders();
          await _loadDeliveredDishes();
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            return _buildOrderCard(order, primaryColor, darkColor);
          },
        ),
      ),
    );
  }
// Add this method to show delivery instances

 
  Widget _buildOrderCard(Map<String, dynamic> order, Color primaryColor, Color darkColor) {
    final status = order['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    // Parse selected dishes
    List<String> dishes = [];
    if (order['selected_dishes'] != null) {
      if (order['selected_dishes'] is List) {
        dishes = List<String>.from(order['selected_dishes']);
      } else if (order['selected_dishes'] is String) {
        try {
          final decoded = jsonDecode(order['selected_dishes']);
          if (decoded is List) {
            dishes = List<String>.from(decoded);
          }
        } catch (e) {}
      }
    }

    // Calculate delivered count
    final deliveredCount = _deliveredDishes.length;
    final totalDishes = widget.subscription.plan.durationDays;
    final remainingDishes = totalDishes - deliveredCount;
    final progress = totalDishes > 0 ? deliveredCount / totalDishes : 0.0;

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
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order['order_number'] ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: darkColor,
                        ),
                      ),
                      Text(
                        'Delivery: ${order['delivery_date'] ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ==============================================
            // NEW: Delivery Progress Section
            // ==============================================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.05),
                    primaryColor.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivery Progress',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: darkColor,
                        ),
                      ),
                      Text(
                        '$deliveredCount / $totalDishes',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: progress >= 1.0 ? Colors.green : primaryColor,
                      minHeight: 6,
                    ),
                  ),
                  Text(
                    progress >= 1.0
                        ? '✅ All dishes delivered!'
                        : '$remainingDishes dish${remainingDishes > 1 ? 'es' : ''} remaining',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: progress >= 1.0 ? Colors.green : Colors.grey[500],
                      fontWeight: progress >= 1.0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Delivery Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Time',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          order['delivery_time_slot'] ?? 'N/A',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: darkColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey[200],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Order Date',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          order['order_date'] ?? 'N/A',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: darkColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ==============================================
            // UPDATED: Selected Dishes with Delivery Status
            // ==============================================
            if (dishes.isNotEmpty) ...[
              Text(
                'Selected Dishes',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: dishes.map((dish) {
                  final isDelivered = _isDishDelivered(dish);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isDelivered
                          ? const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      )
                          : LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.1),
                          primaryColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDelivered
                            ? const Color(0xFF22C55E)
                            : primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDelivered)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 12,
                          ),
                        if (isDelivered) const SizedBox(width: 4),
                        Text(
                          dish,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isDelivered ? FontWeight.w600 : FontWeight.w500,
                            color: isDelivered ? Colors.white : primaryColor,
                          ),
                        ),
                        if (!isDelivered)
                          const Icon(
                            Icons.pending,
                            color: Colors.grey,
                            size: 10,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Meal Options
            Row(
              children: [
                _buildOptionChip(
                  Icons.restaurant,
                  '${order['meal_type']?.toString().toUpperCase() ?? 'VEG'}',
                ),
                const SizedBox(width: 8),
                _buildOptionChip(
                  Icons.breakfast_dining,
                  order['bread_type']?.toString().toUpperCase() ?? 'NAAN',
                ),
                const SizedBox(width: 8),
                _buildOptionChip(
                  Icons.local_fire_department,
                  'SPICE: ${order['spice_level']?.toString().toUpperCase() ?? 'MILD'}',
                ),
              ],
            ),

            Divider(height: 24, color: Colors.grey[100]),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  '\$${order['total_price']?.toString() ?? '0.00'}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[600], size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'preparing':
        return Icons.kitchen;
      case 'ready':
        return Icons.delivery_dining;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.circle;
    }
  }
}