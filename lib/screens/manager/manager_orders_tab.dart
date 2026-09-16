// ==============================================
// MANAGER ORDERS TAB - ORANGE THEME (TIFFIN WALES)
// ==============================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ManagerOrdersTab extends StatefulWidget {
  final String locationName;
  final String email;

  const ManagerOrdersTab({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  State<ManagerOrdersTab> createState() => _ManagerOrdersTabState();
}

class _ManagerOrdersTabState extends State<ManagerOrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  String _filterStatus = 'all';

  // Updated API URL if needed, otherwise keep existing
  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';

  // BRAND COLOR DEFINITION
  static const Color brandOrange = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
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
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'update_order_status';
      request.fields['order_id'] = orderId.toString();
      request.fields['order_status'] = newStatus;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      setState(() {
        _isLoading = false;
      });

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Order status updated to $newStatus'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        _loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(data['message'] ?? 'Failed to update status'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Error: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ==============================================
  // DELETE ORDER - WITH CONFIRMATION
  // ==============================================
  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final int orderId = order['id'] ?? 0;
    final String orderStatus = order['order_status'] ?? 'pending';

    if (orderStatus != 'pending' && orderStatus != 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Only pending or cancelled orders can be deleted'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog(
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
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Delete Order',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this order?',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderPreviewRow('Order ID', '#${order['id']}'),
                  _buildOrderPreviewRow('Customer', order['name'] ?? 'N/A'),
                  _buildOrderPreviewRow('Total', '\$${order['total']?.toString() ?? '0.00'}'),
                  _buildOrderPreviewRow('Status', order['order_status']?.toUpperCase() ?? 'PENDING'),
                  _buildOrderPreviewRow('Date', order['created_at']?.toString().substring(0, 10) ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All order data will be permanently deleted.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red.shade700,
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever_rounded, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Delete Order',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeDeleteOrder(orderId);
    }
  }

  Future<void> _executeDeleteOrder(int orderId) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'delete_order';
      request.fields['order_id'] = orderId.toString();

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      setState(() {
        _isDeleting = false;
      });

      if (data['status'] == 'success') {
        setState(() {
          _orders.removeWhere((order) => order['id'] == orderId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Order deleted successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(data['message'] ?? 'Failed to delete order'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Error: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildOrderPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            ':',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
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
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_filterStatus == 'all') return _orders;
    return _orders.where((order) {
      final status = order['order_status']?.toString().toLowerCase() ?? '';
      return status == _filterStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Using the defined brand orange instead of indigo
    const Color primaryColor = brandOrange;
    const Color darkColor = Color(0xFF1A202C);
    const Color lightBg = Color(0xFFF7FAFC);
    final filteredOrders = _filteredOrders;

    return Scaffold(
      backgroundColor: lightBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandOrange))
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(backgroundColor: brandOrange),
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
            Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('No orders yet'),
            SizedBox(height: 8),
            Text('Orders will appear here'),
          ],
        ),
      )
          : Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', primaryColor),
                  _buildFilterChip('Pending', 'pending', Colors.orange),
                  _buildFilterChip('Preparing', 'preparing', Colors.blue),
                  _buildFilterChip('Ready', 'ready', Colors.green),
                  _buildFilterChip('Delivered', 'delivered', Colors.purple),
                  _buildFilterChip('Cancelled', 'cancelled', Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Order Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredOrders.length} orders',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
                if (_filterStatus != 'all')
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterStatus = 'all';
                      });
                    },
                    child: Text(
                      'Clear Filter',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Orders List
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_alt_off_rounded,
                    size: 50,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $_filterStatus orders',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterStatus = 'all';
                      });
                    },
                    child: Text(
                      'Show all orders',
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadOrders,
              color: primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  final status = order['order_status'] ?? 'pending';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.1),
                        child: Text(
                          '#${order['id'] ?? '?'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        order['name'] ?? 'Unknown Customer',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: darkColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total: \$${order['total']?.toString() ?? '0.00'}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
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
                                      status.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (status == 'pending' || status == 'cancelled')
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red.shade400,
                                    size: 22,
                                  ),
                                  onPressed: _isDeleting
                                      ? null
                                      : () => _deleteOrder(order),
                                  tooltip: 'Delete Order',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ],
                      ),
                      children: [
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
                              _buildDetailCard(
                                'Customer Details',
                                Icons.person_outline_rounded,
                                [
                                  _buildDetailRow(
                                      Icons.person_rounded, 'Name', order['name'] ?? 'N/A'),
                                  _buildDetailRow(
                                      Icons.phone_rounded, 'Phone', order['phone'] ?? 'N/A'),
                                  _buildDetailRow(
                                      Icons.email_rounded, 'Email', order['email'] ?? 'N/A'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDetailCard(
                                'Delivery Details',
                                Icons.location_on_outlined,
                                [
                                  _buildDetailRow(Icons.location_on_rounded, 'Address',
                                      order['address'] ?? 'N/A'),
                                  _buildDetailRow(Icons.location_city_rounded, 'City',
                                      order['city'] ?? 'N/A'),
                                  _buildDetailRow(Icons.pin_drop_rounded, 'Postal Code',
                                      order['postal_code'] ?? 'N/A'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDetailCard(
                                'Order Details',
                                Icons.receipt_long_rounded,
                                [
                                  _buildDetailRow(Icons.access_time_rounded, 'Delivery Slot',
                                      order['delivery_slot'] ?? 'ASAP'),
                                  _buildDetailRow(Icons.payment_rounded, 'Payment',
                                      order['payment_method'] ?? 'Cash on Delivery'),
                                  _buildDetailRow(Icons.note_rounded, 'Instructions',
                                      order['special_instructions'] ?? 'None'),
                                  _buildDetailRow(Icons.calendar_today_rounded, 'Created',
                                      order['created_at'] ?? 'N/A'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Update Status:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatusButton(
                                      'Pending', 'pending', status, order['id'] ?? 0),
                                  _buildStatusButton('Preparing', 'preparing', status,
                                      order['id'] ?? 0),
                                  _buildStatusButton(
                                      'Ready', 'ready', status, order['id'] ?? 0),
                                  _buildStatusButton('Delivered', 'delivered', status,
                                      order['id'] ?? 0),
                                  _buildStatusButton('Cancelled', 'cancelled', status,
                                      order['id'] ?? 0),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (status == 'pending' || status == 'cancelled')
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isDeleting
                                        ? null
                                        : () => _deleteOrder(order),
                                    icon: _isDeleting
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.red,
                                      ),
                                    )
                                        : const Icon(Icons.delete_forever_rounded, size: 18),
                                    label: Text(
                                      _isDeleting ? 'Deleting...' : 'Delete Order',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color primaryColor) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterStatus = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, List<Widget> children) {
    // Use brand orange for icons in detail cards
    const Color cardIconColor = brandOrange;

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
              Icon(icon, size: 16, color: cardIconColor),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
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

  Widget _buildStatusButton(String label, String statusValue,
      String currentStatus, int orderId) {
    final isSelected = currentStatus == statusValue;

    return ElevatedButton(
      onPressed: isSelected || _isDeleting
          ? null
          : () => _updateOrderStatus(orderId, statusValue),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? _getStatusColor(statusValue) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}