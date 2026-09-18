// lib/models/halo_payment_models.dart
import 'package:json_annotation/json_annotation.dart';

// This file defines the data models for Halo Payments

/// Request to create a Halo payment session
class HaloCreatePaymentRequest {
  final String merchantOrderId;
  final String email;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String postalCode;
  final int amount; // In cents (e.g., $10.50 = 1050)
  final String currency;
  final String description;
  final String successUrl;
  final String cancelUrl;
  final String failureUrl;

  HaloCreatePaymentRequest({
    required this.merchantOrderId,
    required this.email,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.amount,
    required this.currency,
    required this.description,
    required this.successUrl,
    required this.cancelUrl,
    required this.failureUrl,
  });

  Map<String, dynamic> toJson() => {
    'merchant_order_id': merchantOrderId,
    'email': email,
    'name': name,
    'phone': phone,
    'address': address,
    'city': city,
    'postal_code': postalCode,
    'amount': amount,
    'currency': currency,
    'description': description,
    'success_url': successUrl,
    'cancel_url': cancelUrl,
    'failure_url': failureUrl,
  };
}

/// Response from creating a Halo payment session
class HaloPaymentSessionResponse {
  final bool success;
  final String? message;
  final String? merchantOrderId;
  final String? paymentId;
  final String? checkoutUrl;
  final String? status;

  HaloPaymentSessionResponse({
    required this.success,
    this.message,
    this.merchantOrderId,
    this.paymentId,
    this.checkoutUrl,
    this.status,
  });

  factory HaloPaymentSessionResponse.fromJson(Map<String, dynamic> json) {
    return HaloPaymentSessionResponse(
      success: json['success'] ?? false,
      message: json['message'],
      merchantOrderId: json['merchant_order_id'] ?? json['orderId'],
      paymentId: json['payment_id'] ?? json['paymentId'],
      checkoutUrl: json['checkout_url'] ?? json['checkoutUrl'],
      status: json['status'],
    );
  }
}

/// Payment status verification response
class HaloPaymentStatusResponse {
  final bool success;
  final String? status; // 'paid', 'failed', 'cancelled', 'pending'
  final String? paymentId;
  final String? merchantOrderId;
  final String? message;
  final double? amount;
  final String? currency;
  final String? gatewayStatus;

  HaloPaymentStatusResponse({
    required this.success,
    this.status,
    this.paymentId,
    this.merchantOrderId,
    this.message,
    this.amount,
    this.currency,
    this.gatewayStatus,
  });

  factory HaloPaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return HaloPaymentStatusResponse(
      success: json['success'] ?? false,
      status: json['status'],
      paymentId: json['payment_id'] ?? json['paymentId'],
      merchantOrderId: json['merchant_order_id'] ?? json['orderId'],
      message: json['message'],
      amount: json['amount']?.toDouble(),
      currency: json['currency'],
      gatewayStatus: json['gateway_status'],
    );
  }
}

/// Payment status enum for Flutter
enum PaymentStatusEnum {
  pending,
  processing,
  paid,
  failed,
  cancelled,
  refunded,
  unknown;

  static PaymentStatusEnum fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return PaymentStatusEnum.pending;
      case 'processing':
        return PaymentStatusEnum.processing;
      case 'paid':
      case 'success':
      case 'completed':
      case 'approved':
        return PaymentStatusEnum.paid;
      case 'failed':
      case 'declined':
        return PaymentStatusEnum.failed;
      case 'cancelled':
        return PaymentStatusEnum.cancelled;
      case 'refunded':
        return PaymentStatusEnum.refunded;
      default:
        return PaymentStatusEnum.unknown;
    }
  }

  bool get isFinal => this == PaymentStatusEnum.paid ||
      this == PaymentStatusEnum.failed ||
      this == PaymentStatusEnum.cancelled ||
      this == PaymentStatusEnum.refunded;
}