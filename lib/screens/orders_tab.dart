import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _locations = [];
  String? _selectedLocation;
  bool _isLoading = true;
  bool _isLoadingLocations = true;
  bool _isProcessing = false;
  String? _errorMessage;
  String _selectedFilter = 'All';
  late AnimationController _animationController;

  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';
  final String locationApiUrl = 'https://quantorra.co/tiffinwales/Locations.php';

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(locationApiUrl));
      request.fields['action'] = 'get_locations';

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        setState(() {
          _locations = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoadingLocations = false;
          if (_locations.isNotEmpty) {
            _selectedLocation = _locations[0]['name'];
            _loadOrders();
          }
        });
        _animationController.forward();
      } else {
        setState(() {
          _isLoadingLocations = false;
          _errorMessage = 'Failed to load locations';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocations = false;
        _errorMessage = 'Failed to load locations';
      });
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['user_type'] = 'admin';
      request.fields['user_role'] = 'master';

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
    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'update_order_status';
      request.fields['order_id'] = orderId.toString();
      request.fields['order_status'] = newStatus;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      setState(() => _isProcessing = false);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar('Order status updated to $newStatus'),
        );
        _loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(data['message'] ?? 'Failed to update'),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        _buildErrorSnackBar('Error: ${e.toString()}'),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return const Color(0xFFF97316);   // Tiffin Wales orange (was purple)
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    List<Map<String, dynamic>> filtered = _orders;

    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      filtered = filtered.where((order) {
        final location = (order['location_name'] ?? '').toString();
        return location == _selectedLocation;
      }).toList();
    }

    if (_selectedFilter != 'All') {
      filtered = filtered.where((order) {
        final status = (order['order_status'] ?? '').toString().toLowerCase();
        return status == _selectedFilter.toLowerCase();
      }).toList();
    }

    return filtered;
  }

  String _getFirstItemName(Map<String, dynamic> order) {
    try {
      final items = order['items'];
      if (items != null) {
        List<dynamic> itemList;
        if (items is String) {
          itemList = jsonDecode(items) as List<dynamic>;
        } else if (items is List) {
          itemList = items;
        } else {
          return 'Unknown Item';
        }

        if (itemList.isNotEmpty) {
          final firstItem = itemList[0];
          final name = firstItem['item_name'] ?? firstItem['name'] ?? 'Unknown';
          if (itemList.length > 1) {
            return '$name (+${itemList.length - 1} more)';
          }
          return name;
        }
      }
      return 'No items';
    } catch (e) {
      return 'Unknown Item';
    }
  }

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

  SnackBar _buildSuccessSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  SnackBar _buildErrorSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  List<DropdownMenuItem<String>> _getLocationDropdownItems() {
    return [
      const DropdownMenuItem(value: '', child: Text('All Locations')),
      ..._locations.map<DropdownMenuItem<String>>((location) {
        return DropdownMenuItem<String>(
          value: location['name'] as String,
          child: Text(location['name'] ?? 'Unknown'),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);   // Logo orange
    const Color darkColor = Color(0xFF1C1C1E);       // Logo charcoal

    final filteredOrders = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                if (!_isLoadingLocations)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      decoration: InputDecoration(
                        labelText: 'Filter by Location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        prefixIcon: const Icon(Icons.location_on, color: Color(0xFFF97316)),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: _getLocationDropdownItems(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLocation = value;
                        });
                      },
                    ),
                  ),
                if (!_isLoading && _orders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusChip('All', _selectedFilter == 'All', primaryColor),
                        const SizedBox(width: 8),
                        _buildStatusChip('Pending', _selectedFilter == 'Pending', primaryColor),
                        const SizedBox(width: 8),
                        _buildStatusChip('Preparing', _selectedFilter == 'Preparing', primaryColor),
                        const SizedBox(width: 8),
                        _buildStatusChip('Ready', _selectedFilter == 'Ready', primaryColor),
                        const SizedBox(width: 8),
                        _buildStatusChip('Delivered', _selectedFilter == 'Delivered', primaryColor),
                        const SizedBox(width: 8),
                        _buildStatusChip('Cancelled', _selectedFilter == 'Cancelled', primaryColor),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Order Count
          if (!_isLoading && filteredOrders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${filteredOrders.length} Orders',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
              ),
            )
                : _errorMessage != null
                ? _buildErrorState()
                : filteredOrders.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadOrders,
              color: primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order, index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
            'Failed to Load Orders',
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
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
              ).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _orders.isEmpty ? Icons.receipt_long : Icons.filter_alt_off,
              size: 50,
              color: const Color(0xFFF97316).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _orders.isEmpty ? 'No Orders Yet' : 'No Matching Orders',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _orders.isEmpty
                ? 'Orders will appear here when placed'
                : 'Try changing your filters',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, Color primaryColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);

    final status = order['order_status'] ?? 'pending';
    final customerName = order['name'] ?? 'Guest';
    final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
    final firstItem = _getFirstItemName(order);
    final createdAt = order['created_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      ),
      child: ExpansionTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${order['id'] ?? '?'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _getStatusColor(status),
              ),
            ),
          ),
        ),
        title: Text(
          '$customerName - $firstItem',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: darkColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            Text(
              '\$${total.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(createdAt),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        trailing: Icon(
          _getStatusColor(status) == Colors.green
              ? Icons.check_circle
              : Icons.more_horiz,
          color: _getStatusColor(status),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow('Customer', customerName),
                _buildDetailRow('Phone', order['phone'] ?? 'N/A'),
                _buildDetailRow('Address', order['address'] ?? 'N/A'),
                if (order['city'] != null && order['city'].toString().isNotEmpty)
                  _buildDetailRow('City', order['city']),
                _buildDetailRow('Location', order['location_name'] ?? 'N/A'),
                _buildDetailRow('Delivery Slot', order['delivery_slot'] ?? 'ASAP'),
                _buildDetailRow('Payment', order['payment_method'] ?? 'Cash on Delivery'),
                if (order['special_instructions'] != null && order['special_instructions'].toString().isNotEmpty)
                  _buildDetailRow('Instructions', order['special_instructions']),

                const SizedBox(height: 16),
                Text(
                  'Update Status',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: darkColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusButton('Pending', 'pending', status, order['id'] ?? 0),
                    _buildStatusButton('Preparing', 'preparing', status, order['id'] ?? 0),
                    _buildStatusButton('Ready', 'ready', status, order['id'] ?? 0),
                    _buildStatusButton('Delivered', 'delivered', status, order['id'] ?? 0),
                    _buildStatusButton('Cancelled', 'cancelled', status, order['id'] ?? 0),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #${order['id']} • ${_formatDate(createdAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String label, String statusValue, String currentStatus, int orderId) {
    final isSelected = currentStatus.toLowerCase() == statusValue.toLowerCase();

    return ElevatedButton(
      onPressed: isSelected || _isProcessing
          ? null
          : () => _updateOrderStatus(orderId, statusValue),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? _getStatusColor(statusValue) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: _isProcessing && !isSelected
          ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}