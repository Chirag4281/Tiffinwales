enum PaymentStatus { success, failed, cancelled }

class PaymentSession {
  final String paymentId;
  final String orderId;
  final String checkoutUrl;
  final double amount;
  final String currency;
  final String status;

  PaymentSession({
    required this.paymentId,
    required this.orderId,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
    required this.status,
  });

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      paymentId: json['paymentId'] ?? '',
      orderId: json['orderId'] ?? '',
      checkoutUrl: json['checkoutUrl'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? 'pending',
    );
  }
}