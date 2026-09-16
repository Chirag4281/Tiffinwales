import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PendingOrdersDialog extends StatefulWidget {
  final String locationName;
  final String email;
  final VoidCallback? onNavigateToOrders;

  const PendingOrdersDialog({
    Key? key,
    required this.locationName,
    required this.email,
    this.onNavigateToOrders,
  }) : super(key: key);

  @override
  State<PendingOrdersDialog> createState() => _PendingOrdersDialogState();
}

class _PendingOrdersDialogState extends State<PendingOrdersDialog> {
  List<Map<String, dynamic>> _pendingOrders = [];
  bool _isLoading = true;
  bool _isDialogShown = false;
  String? _errorMessage;
  bool _hasCheckedOrders = false;
  bool _isClosed = false; // Track if widget is closed

  final String orderApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  @override
  void dispose() {
    _isClosed = true;
    super.dispose();
  }

  Future<void> _loadPendingOrders() async {
    // Don't proceed if widget is not mounted or already closed
    if (!mounted || _isClosed) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(orderApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['email'] = widget.email;
      request.fields['location_name'] = widget.locationName;
      request.fields['user_type'] = 'admin';
      request.fields['user_role'] = 'manager';

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      // Check if widget is still mounted and not closed
      if (!mounted || _isClosed) return;

      if (data['status'] == 'success') {
        List<Map<String, dynamic>> allOrders =
        List<Map<String, dynamic>>.from(data['data'] ?? []);

        _pendingOrders = allOrders
            .where((order) =>
        (order['order_status'] ?? 'pending').toString().toLowerCase() == 'pending')
            .toList();

        setState(() {
          _isLoading = false;
          _hasCheckedOrders = true;
        });

        // Only show dialog if there are pending orders
        if (_pendingOrders.isNotEmpty) {
          _showPendingOrdersDialog();
        } else {
          // No pending orders - close silently with no dialog
          _closeAllSilently();
        }
      } else {
        // Error from API - close silently
        _closeAllSilently();
      }
    } catch (e) {
      // Error occurred - close silently
      if (!mounted || _isClosed) return;
      _closeAllSilently();
    }
  }

  // ==============================================
  // CLOSE SILENTLY - No dialog shown
  // ==============================================
  void _closeAllSilently() {
    if (_isClosed || !mounted) return;
    _isClosed = true;
    _isDialogShown = false;

    // Close the widget itself
    try {
      Navigator.pop(context);
    } catch (e) {
      // Ignore if widget is already closed
    }
  }

  // ==============================================
  // CLOSE EVERYTHING - Properly dispose
  // ==============================================
  void _closeAll() {
    if (_isClosed || !mounted) return;
    _isClosed = true;
    _isDialogShown = false;

    // Close any open dialogs
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      // Ignore if no dialog is open
    }

    // Close the widget itself
    try {
      Navigator.pop(context);
    } catch (e) {
      // Ignore if widget is already closed
    }
  }

  void _showPendingOrdersDialog() {
    if (_isDialogShown || !mounted || _isClosed) return;
    _isDialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          _closeAll();
          return false;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pending_actions_rounded,
                        color: Colors.orange[700],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ Pending Orders',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            '${_pendingOrders.length} order(s) waiting for processing',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _closeAll,
                      icon: Icon(Icons.close, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // List of pending orders
                Expanded(
                  child: ListView.builder(
                    itemCount: _pendingOrders.length,
                    itemBuilder: (context, index) {
                      final order = _pendingOrders[index];
                      return _buildPendingOrderCard(order);
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closeAll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Later',
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
                        onPressed: () {
                          // Close everything first
                          _closeAll();
                          // Then navigate to orders after a small delay
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted && !_isClosed) {
                              widget.onNavigateToOrders?.call();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Go to Orders',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
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
        ),
      ),
    ).then((_) {
      _isDialogShown = false;
    });
  }

  Widget _buildPendingOrderCard(Map<String, dynamic> order) {
    final String customerName = order['name'] ?? 'Guest';
    final String firstItem = _getFirstItemName(order);
    final String createdAt = order['created_at'] ?? '';
    final String formattedTime = _formatTime(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  firstItem,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedTime,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Pending',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  String _getFirstItemName(Map<String, dynamic> order) {
    try {
      if (order['items'] != null && order['items'] is String) {
        final String itemsString = order['items'];
        if (itemsString.isNotEmpty && itemsString != 'null') {
          final List<dynamic> items = jsonDecode(itemsString) as List<dynamic>;
          if (items.isNotEmpty) {
            final firstItem = items[0];
            final String itemName = firstItem['item_name'] ?? firstItem['name'] ?? 'Unknown';
            return itemName;
          }
        }
      }
      return 'Unknown Item';
    } catch (e) {
      return 'Unknown Item';
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Just now';
    try {
      final DateTime date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container - no dialog shown
    // The loading state is handled internally
    return const SizedBox.shrink();
  }
}