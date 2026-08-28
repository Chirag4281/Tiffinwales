// lib/services/subscription_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_models.dart';

class SubscriptionService {
  static const String baseUrl = 'https://quantorra.co/tiffinwales/SubscriptionManager.php';

  // ==============================================
  // GET SUBSCRIPTION PLANS
  // ==============================================
  static Future<Map<String, dynamic>> getSubscriptionPlans({
    required String locationName,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields['action'] = 'get_all_plans';
      request.fields['location_name'] = locationName;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==============================================
  // GET AVAILABLE DISHES
  // ==============================================
  static Future<Map<String, dynamic>> getAvailableDishes({
    required String locationName,
    String? category,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields['action'] = 'get_dishes';
      request.fields['location_name'] = locationName;
      if (category != null) {
        request.fields['category'] = category;
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==============================================
  // CREATE SUBSCRIPTION
  // ==============================================
  static Future<Map<String, dynamic>> createSubscription({
    required String userEmail,
    required String locationName,
    required int planId,
    required String mealType,
    required String breadType,
    required String spiceLevel,
    required List<String> selectedDishes,
    required double totalPrice,
    required String deliveryOption,
    required String deliveryDate,
    required String deliveryTimeSlot,
    String specialInstructions = '',
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields['action'] = 'create_subscription';
      request.fields['user_email'] = userEmail;
      request.fields['location_name'] = locationName;
      request.fields['plan_id'] = planId.toString();
      request.fields['meal_type'] = mealType;
      request.fields['bread_type'] = breadType;
      request.fields['spice_level'] = spiceLevel;
      request.fields['selected_dishes'] = jsonEncode(selectedDishes);
      request.fields['total_price'] = totalPrice.toString();
      request.fields['delivery_option'] = deliveryOption;
      request.fields['delivery_date'] = deliveryDate;
      request.fields['delivery_time_slot'] = deliveryTimeSlot;
      request.fields['special_instructions'] = specialInstructions;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==============================================
  // GET USER SUBSCRIPTIONS
  // ==============================================
  static Future<Map<String, dynamic>> getUserSubscriptions({
    required String userEmail,
    required String locationName,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields['action'] = 'get_user_subscriptions';
      request.fields['user_email'] = userEmail;
      request.fields['location_name'] = locationName;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==============================================
  // UPDATE SUBSCRIPTION STATUS
  // ==============================================
  static Future<Map<String, dynamic>> updateSubscriptionStatus({
    required int subscriptionId,
    required String status,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields['action'] = 'update_status';
      request.fields['subscription_id'] = subscriptionId.toString();
      request.fields['status'] = status;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ==============================================
  // MARK ORDER DELIVERED (Update days remaining)
  // ==============================================
  static Future<Map<String, dynamic>> markOrderDelivered({
    required int subscriptionId,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields['action'] = 'mark_delivered';
      request.fields['subscription_id'] = subscriptionId.toString();

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
// Add this method to SubscriptionService

// ==============================================
// GET SUBSCRIPTION ORDERS
// ==============================================
  // Add this to SubscriptionService

// ==============================================
// GET SUBSCRIPTION ORDERS
// ==============================================
  static Future<Map<String, dynamic>> getSubscriptionOrders({
    required int subscriptionId,
    required String userEmail,
  }) async {
    try {
      print('=== GET SUBSCRIPTION ORDERS ===');
      print('subscriptionId: $subscriptionId');
      print('userEmail: $userEmail');

      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields['action'] = 'get_subscription_orders';
      request.fields['subscription_id'] = subscriptionId.toString();
      request.fields['user_email'] = userEmail;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print('Response: $responseBody');

      return json.decode(responseBody);
    } catch (e) {
      print('Error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }
  // ==============================================
  // GET DELIVERY TIME SLOTS
  // ==============================================
  static List<String> getDeliveryTimeSlots() {
    return [
      '12:00PM to 1:00PM (Delivery Timing)',
      '1:00PM to 2:00PM (Delivery Timing)',
      '11:30AM to 12PM (Pickup Timing)',
      '12:00PM to 12:30PM (Pickup Timing)',
      '12:30PM to 1:00PM (Pickup Timing)',
      '1:00PM to 1:30PM (Pickup Timing)',
      '1:30PM to 2:00PM (Pickup Timing)',
      '2:00PM to 2:30PM (Pickup Timing)',
      '2:30PM to 3:00PM (Pickup Timing)',
      '6:00PM to 6:30PM (Pickup Timing)',
      '6:30PM to 7:00PM (Pickup Timing)',
      '7:00PM to 7:30PM (Pickup Timing)',
      '7:30PM to 8:00PM (Pickup Timing)',
      '8:00PM to 8:30PM (Pickup Timing)',
      '8:30PM to 9:00PM (Pickup Timing)',
    ];
  }
}