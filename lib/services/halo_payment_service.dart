// lib/services/halo_payment_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/halo_payment_models.dart';
import '../screens/payment_result_screen.dart';

/// Service for handling Halo Payments integration
class HaloPaymentService {
  // Base URL for your backend API
  static const String _backendBaseUrl = 'https://quantorra.co/tiffinwales/api/halo';

  // Timeouts
  static const Duration _defaultTimeout = Duration(seconds: 45);
  static const Duration _pollingInterval = Duration(seconds: 2);
  static const int _maxPollingAttempts = 45; // 90 seconds max

  /// Create a payment session via the backend
  /// Returns a [HaloPaymentSessionResponse] containing the checkout URL
  static Future<HaloPaymentSessionResponse> createPayment({
    required String merchantOrderId,
    required String email,
    required String name,
    required String phone,
    required String address,
    required String city,
    required String postalCode,
    required int amount, // In cents
    required String currency,
    required String description,
    required String successUrl,
    required String cancelUrl,
    required String failureUrl,
  }) async {
    try {
      final request = HaloCreatePaymentRequest(
        merchantOrderId: merchantOrderId,
        email: email,
        name: name,
        phone: phone,
        address: address,
        city: city,
        postalCode: postalCode,
        amount: amount,
        currency: currency,
        description: description,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
        failureUrl: failureUrl,
      );

      final response = await http.post(
        Uri.parse('$_backendBaseUrl/create-payment.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        return HaloPaymentSessionResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);

      // Log for debugging (without sensitive data)
      print('[HALO] Create payment response received');

      return HaloPaymentSessionResponse.fromJson(data);
    } on TimeoutException {
      return HaloPaymentSessionResponse(
        success: false,
        message: 'Connection timeout. Please try again.',
      );
    } catch (e) {
      print('[HALO] Error creating payment: $e');
      return HaloPaymentSessionResponse(
        success: false,
        message: 'Failed to create payment: ${e.toString()}',
      );
    }
  }

  /// Verify payment status via the backend
  static Future<HaloPaymentStatusResponse> verifyPayment({
    required String paymentId,
    required String merchantOrderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/payment-status.php?payment_id=$paymentId&order_id=$merchantOrderId'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        return HaloPaymentStatusResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);

      // Log for debugging
      print('[HALO] Payment verification response: ${data['status']}');

      return HaloPaymentStatusResponse.fromJson(data);
    } on TimeoutException {
      return HaloPaymentStatusResponse(
        success: false,
        message: 'Verification timeout',
      );
    } catch (e) {
      print('[HALO] Error verifying payment: $e');
      return HaloPaymentStatusResponse(
        success: false,
        message: 'Failed to verify payment: ${e.toString()}',
      );
    }
  }

  /// Poll payment status until completion or timeout
  static Future<HaloPaymentStatusResponse> pollPaymentStatus({
    required String paymentId,
    required String merchantOrderId,
    required Function(String status, String? message) onStatusUpdate,
  }) async {
    int attempts = 0;
    HaloPaymentStatusResponse? lastResponse;

    while (attempts < _maxPollingAttempts) {
      attempts++;

      try {
        final response = await verifyPayment(
          paymentId: paymentId,
          merchantOrderId: merchantOrderId,
        );

        lastResponse = response;

        if (response.success) {
          final status = response.status ?? 'pending';

          // Notify caller of status update
          onStatusUpdate(status, response.message);

          // If status is final, return immediately
          final paymentStatus = PaymentStatusEnum.fromString(status);
          if (paymentStatus.isFinal) {
            print('[HALO] Payment reached final status: $status after $attempts attempts');
            return response;
          }
        }

        // Wait before next poll
        await Future.delayed(_pollingInterval);
      } catch (e) {
        print('[HALO] Polling error: $e');
        // Continue polling despite errors
        await Future.delayed(_pollingInterval);
      }
    }

    // Timeout - return last known status
    print('[HALO] Payment polling timed out after $_maxPollingAttempts attempts');
    return lastResponse ?? HaloPaymentStatusResponse(
      success: false,
      status: 'unknown',
      message: 'Payment verification timed out',
    );
  }

  /// Get payment status (single check)
  static Future<HaloPaymentStatusResponse> getPaymentStatus({
    required String merchantOrderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/payment-status.php?order_id=$merchantOrderId'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        return HaloPaymentStatusResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);
      return HaloPaymentStatusResponse.fromJson(data);
    } catch (e) {
      return HaloPaymentStatusResponse(
        success: false,
        message: 'Failed to get payment status: ${e.toString()}',
      );
    }
  }
}