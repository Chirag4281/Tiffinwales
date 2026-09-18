// lib/screens/subscription_payment_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final String locationName;
  final String userEmail;
  final String username;
  final SubscriptionPlan selectedPlan;
  final String mealType;
  final String breadType;
  final String spiceLevel;
  final List<String> selectedDishes;
  final double totalAmount;
  final String deliveryOption;
  final DateTime deliveryDate;
  final String deliveryTimeSlot;
  final String specialInstructions;
  final double deliveryFee;
  final double distance;
  final bool isDeliveryAvailable;
  final String? cardNumber;
  final String? expiry;
  final String? cvc;

  const SubscriptionPaymentScreen({
    Key? key,
    required this.locationName,
    required this.userEmail,
    required this.username,
    required this.selectedPlan,
    required this.mealType,
    required this.breadType,
    required this.spiceLevel,
    required this.selectedDishes,
    required this.totalAmount,
    required this.deliveryOption,
    required this.deliveryDate,
    required this.deliveryTimeSlot,
    required this.specialInstructions,
    required this.deliveryFee,
    required this.distance,
    required this.isDeliveryAvailable,
    this.cardNumber,
    this.expiry,
    this.cvc,
  }) : super(key: key);

  @override
  State<SubscriptionPaymentScreen> createState() => _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  bool _isLoading = false;
  bool _isPlacingOrder = false;
  String? _paymentUrl;
  late WebViewController _webViewController;
  bool _isWebViewLoading = false;
  bool _paymentCompleted = false;
  String? _subscriptionId;
  String? _orderNumber;

  final String haloPaymentApiUrl = 'https://quantorra.co/tiffinwales/create_halo_payment.php';

  @override
  void initState() {
    super.initState();
    _initiatePayment();
  }

  Future<void> _initiatePayment() async {
    // If COD, skip payment and go directly to subscription creation


    // If no card details, show error
    if (widget.cardNumber == null || widget.expiry == null || widget.cvc == null) {
      _showErrorDialog('Payment Error', 'No card details provided. Please add a card.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final orderId = 'SUB-${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse(haloPaymentApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'order_id': orderId,
          'amount': widget.totalAmount.toStringAsFixed(2),
          'currency': 'USD',
          'customer_name': widget.username,
          'customer_email': widget.userEmail,
          'customer_phone': '',
          'card': {
            'number': widget.cardNumber!.replaceAll(' ', ''),
            'expiration_date': widget.expiry!,
            'cvc': widget.cvc!,
          }
        }),
      ).timeout(const Duration(seconds: 20));

      print('🔍 Payment Response: ${response.body}');
      final data = jsonDecode(response.body);

      if (data['status'] == 'success' && data['payment_url'] != null) {
        setState(() {
          _paymentUrl = data['payment_url'];
          _isLoading = false;
        });
        _showPaymentWebView(orderId);
      } else {
        throw Exception(data['message'] ?? 'Failed to initialize payment');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Payment Error', 'Failed to initiate payment: ${e.toString()}');
    }
  }


  void _showPaymentWebView(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          width: double.infinity,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                title: const Text('Secure Halo Payment', style: TextStyle(color: Colors.black)),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                      _showRetryDialog();
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
                        onPageStarted: (url) => setState(() => _isWebViewLoading = true),
                        onPageFinished: (url) {
                          setState(() => _isWebViewLoading = false);

                          if (url.contains('payment_return.php') || url.contains('status=success')) {
                            Navigator.pop(context);
                            _finalizeSubscription(paymentId);
                          } else if (url.contains('status=failed') || url.contains('cancel')) {
                            Navigator.pop(context);
                            _showRetryDialog();
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

  // ==============================================
  // FINALIZE SUBSCRIPTION WITH PAYMENT
  // ==============================================
  Future<void> _finalizeSubscription(String paymentId) async {
    setState(() {
      _isLoading = true;
      _isPlacingOrder = true;
    });

    try {
      final formattedDate = widget.deliveryDate.toIso8601String().split('T').first;
      final days = widget.selectedPlan.durationDays;
      final totalDeliveryFee = widget.deliveryFee * days;

      // Create subscription with payment info
      final response = await SubscriptionService.createSubscription(
        userEmail: widget.userEmail,
        locationName: widget.locationName,
        planId: widget.selectedPlan.id,
        mealType: widget.mealType,
        breadType: widget.breadType,
        spiceLevel: widget.spiceLevel,
        selectedDishes: widget.selectedDishes,
        totalPrice: widget.totalAmount,
        deliveryOption: widget.deliveryOption,
        deliveryDate: formattedDate,
        deliveryTimeSlot: widget.deliveryTimeSlot,
        specialInstructions: widget.specialInstructions,
        // Payment fields
        paymentStatus: 'paid',
        paymentId: paymentId,
        paymentMethod: 'Halo Payments',
        deliveryFee: widget.deliveryFee,
        totalDeliveryFee: totalDeliveryFee,
        distance: widget.distance,
      );

      print('📦 Subscription Response: $response');

      if (response['status'] == 'success') {
        final data = response['data'];
        setState(() {
          _subscriptionId = data?['subscription_id']?.toString() ?? '';
          _orderNumber = data?['order_number']?.toString() ?? '';
          _paymentCompleted = true;
          _isLoading = false;
          _isPlacingOrder = false;
        });

        _showSuccessDialog();
      } else {
        throw Exception(response['message'] ?? 'Failed to create subscription');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isPlacingOrder = false;
      });
      _showErrorDialog('Subscription Error', 'Failed to create subscription: ${e.toString()}');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 60),
              ),
              const SizedBox(height: 20),
              Text(
                'Subscription Active! 🎉',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${widget.selectedPlan.planName} has been activated.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (_orderNumber != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Order: ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '$_orderNumber',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
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
                    Icon(Icons.notifications_active, color: Colors.green[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '✅ Payment confirmed! Your subscription is now active.',
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Back',
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
                        Navigator.pop(context);
                        Navigator.popUntil(context, (route) => route.isFirst);
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
                        'Home',
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
    );
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 14),
            Text(
              'Payment Incomplete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Your payment was not completed. Would you like to try again?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initiatePayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Go Back',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () {
            if (_paymentCompleted) {
              Navigator.pop(context);
            } else {
              _showRetryDialog();
            }
          },
        ),
        title: Text(
          'Payment',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              _isPlacingOrder
                  ? 'Creating your subscription...'
                  : 'Initializing payment...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            const SizedBox(height: 20),
            _buildPaymentDetails(),
            const SizedBox(height: 20),
            _buildSubscriptionDetails(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final days = widget.selectedPlan.durationDays;
    final totalDeliveryFee = widget.deliveryFee * days;

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Summary',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Plan', widget.selectedPlan.planName),
          _buildSummaryRow('Duration', '${widget.selectedPlan.durationDays} Days'),
          _buildSummaryRow('Dishes', '${widget.selectedPlan.maxDishes} Dishes'),
          _buildSummaryRow('Meal Type', widget.mealType.toUpperCase()),
          _buildSummaryRow('Bread Type', widget.breadType.toUpperCase()),
          _buildSummaryRow('Spice Level', widget.spiceLevel.toUpperCase()),
          const Divider(height: 16),
          _buildSummaryRow(
            'Plan Price',
            '\$${widget.selectedPlan.price.toStringAsFixed(2)}',
            isBold: true,
          ),
          _buildSummaryRow(
            'Delivery Fee ($days days)',
            '\$${totalDeliveryFee.toStringAsFixed(2)}',
          ),
          const Divider(height: 16, thickness: 2),
          _buildSummaryRow(
            'Total Amount',
            '\$${widget.totalAmount.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isTotal = false}) {
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
              color: isTotal ? const Color(0xFF1A202C) : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 20 : 14,
              fontWeight: isTotal ? FontWeight.w800 : (isBold ? FontWeight.w600 : FontWeight.w400),
              color: isTotal ? const Color(0xFF6366F1) : const Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails() {
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_outline, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Method',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.payment, color: Color(0xFF6366F1), size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo Payments',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                      Text(
                        'Secure online payment',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Secure',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will be redirected to Halo Payments secure gateway to complete your payment.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[700],
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

  Widget _buildSubscriptionDetails() {
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.food_bank, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Selected Dishes',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedDishes.map((dish) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  dish,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delivery: ${widget.deliveryDate.toIso8601String().split('T').first} at ${widget.deliveryTimeSlot}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
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
}