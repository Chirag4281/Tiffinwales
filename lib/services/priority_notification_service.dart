import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PriorityNotificationService {
  static const String baseUrl = 'https://quantorra.co/tiffinwales/';

  // ==============================================
  // FORCE HIGH PRIORITY NOTIFICATION
  // ==============================================
  static Future<Map<String, dynamic>> sendHighPriorityNotification({
    required String targetEmail,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    bool forceHighPriority = true, // 🔥 FORCE HIGH PRIORITY
  }) async {
    try {
      final url = Uri.parse('${baseUrl}send_notification.php');

      final response = await http.post(
        url,
        body: {
          'action': 'send_high_priority',
          'target_email': targetEmail,
          'title': title,
          'body': body,
          'data': jsonEncode(data),
          'priority': 'high', // 🔥 HIGH PRIORITY
          'force_high_priority': forceHighPriority ? 'true' : 'false',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ HIGH PRIORITY notification sent: ${result['message']}');
        return result;
      } else {
        print('❌ Failed to send HIGH PRIORITY notification');
        return {'status': 'error', 'message': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ Error sending HIGH PRIORITY notification: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==============================================
  // BULK HIGH PRIORITY NOTIFICATIONS
  // ==============================================
  static Future<void> sendBulkHighPriorityNotifications({
    required List<String> targetEmails,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    for (var email in targetEmails) {
      await sendHighPriorityNotification(
        targetEmail: email,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  // ==============================================
  // SEND TO ALL MANAGERS AND MASTER ADMINS
  // ==============================================
  static Future<void> notifyAllManagersAndAdmins({
    required String locationName,
    required String orderId,
    required String customerName,
    required String orderTotal,
  }) async {
    final title = '🆕 NEW ORDER at $locationName';
    final body = '$customerName placed an order (#$orderId) worth \$$orderTotal';

    final data = {
      'target': 'orders',
      'order_id': orderId,
      'location': locationName,
      'type': 'new_order',
      'priority': 'high',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final url = Uri.parse('${baseUrl}send_notification.php');

      final response = await http.post(
        url,
        body: {
          'action': 'notify_order_placed_high_priority',
          'location_name': locationName,
          'order_id': orderId,
          'customer_name': customerName,
          'order_total': orderTotal,
          'priority': 'high', // 🔥 HIGH PRIORITY
          'force_high_priority': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ HIGH PRIORITY notifications sent to managers and admins');
        print('📊 Result: ${result['message']}');
      } else {
        print('❌ Failed to send HIGH PRIORITY notifications');
      }
    } catch (e) {
      print('❌ Error sending HIGH PRIORITY notifications: $e');
    }
  }
}