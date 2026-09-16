import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/payment_model.dart'; // Import the enum from here

class PaymentResultScreen extends StatelessWidget {
  final PaymentStatus status;
  final String orderId;
  final String? paymentId;  // NEW
  final double amount;
  final String message;

  const PaymentResultScreen({
    super.key,
    required this.status,
    required this.orderId,
    this.paymentId,  // NEW
    required this.amount,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status == PaymentStatus.success;
    final isCancelled = status == PaymentStatus.cancelled;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSuccess
                      ? Colors.green.withOpacity(0.1)
                      : isCancelled
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                ),
                child: Icon(
                  isSuccess
                      ? Icons.check_circle
                      : isCancelled
                      ? Icons.cancel
                      : Icons.error,
                  size: 50,
                  color: isSuccess
                      ? Colors.green
                      : isCancelled
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSuccess
                    ? 'Payment Successful! 🎉'
                    : isCancelled
                    ? 'Payment Cancelled'
                    : 'Payment Failed',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isSuccess
                      ? Colors.green
                      : isCancelled
                      ? Colors.orange
                      : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order ID:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            orderId,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount Paid:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Method:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Halo Pay',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (isSuccess) {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSuccess
                            ? const Color(0xFF6366F1)
                            : isCancelled
                            ? const Color(0xFFF59E0B)
                            : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isSuccess
                            ? 'Continue to Home'
                            : isCancelled
                            ? 'Return to Checkout'
                            : 'Try Again',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isSuccess) ...[
                const SizedBox(height: 12),
                Text(
                  'A confirmation email has been sent to your registered email address.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}