import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'notification_service.dart';

// 🔥 GLOBAL NAVIGATION KEY FOR DEEP LINKING
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class InitializationService {
  static bool _isInitialized = false;
  static bool _oneSignalInitialized = false;

  static const String oneSignalAppId = '1be25b22-5e27-418f-8c0a-9a68cc6c39e5';

  // ==============================================
  // INITIALIZE APP (Firebase + Local Notifications)
  // ==============================================
  static Future<void> initializeApp() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();
      await NotificationService().initialize();
      _isInitialized = true;
      print('✅ App initialization complete (Firebase + Local Notifications)');
    } catch (e) {
      print('❌ App initialization failed: $e');
      rethrow;
    }
  }

  // ==============================================
  // INITIALIZE ONESIGNAL AFTER LOGIN
  // ==============================================
  static Future<void> initializeOneSignalAfterLogin({
    required String email,
    required String role,
    String? locationName,
  }) async {
    try {
      print('🚀 Initializing OneSignal for: $email ($role) | Location: $locationName');

      // 1. Initialize SDK (Only if not already initialized)
      if (!_oneSignalInitialized) {
        await OneSignal.initialize(oneSignalAppId);
        _oneSignalInitialized = true;
        print('✅ OneSignal SDK initialized');
      }

      // 2. Request Permission
      await OneSignal.Notifications.requestPermission(true);

      // 3. Set Identity (Always update)
      await OneSignal.User.addEmail(email);
      await OneSignal.User.addAlias('external_id', email);
      print('✅ OneSignal identity set for: $email');

      // 4. Update User Tags (Always update with latest role and location)
      await _updateUserTags(email, role, locationName);
      print('✅ OneSignal tags updated');

      // 5. Get OneSignal ID
      String? osId = await OneSignal.User.getOnesignalId();

      if (osId == null || osId.isEmpty) {
        // Wait a bit and try again if ID is not ready
        await Future.delayed(const Duration(seconds: 2));
        osId = await OneSignal.User.getOnesignalId();
      }

      // 6. Save locally
      if (osId != null && osId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('onesignal_id', osId);
        await prefs.setString('user_email', email);
        await prefs.setString('user_role', role);
        if (locationName != null) {
          await prefs.setString('user_location', locationName);
        }
        print('✅ OneSignal ID saved locally: $osId');

        // 7. Sync to Database
        await syncOneSignalIdToDatabase(
          email: email,
          role: role,
          locationName: locationName,
        );
      } else {
        print('⚠️ OneSignal ID not ready yet. Will retry on next sync.');
      }

      print('✅ OneSignal initialization complete');
    } catch (e) {
      print('❌ OneSignal initialization failed: $e');
    }
  }

  // ==============================================
  // UPDATE USER TAGS (Always updates with latest data)
  // ==============================================
  static Future<void> _updateUserTags(String email, String role, String? locationName) async {
    try {
      // Build tags map with all user data
      final Map<String, String> tags = {
        'role': role,
        'email': email,
      };

      // Add location if available
      if (locationName != null && locationName.isNotEmpty) {
        tags['location'] = locationName;
      }

      // Add role-specific tags for better targeting
      if (role == 'manager' || role == 'master') {
        tags['user_type'] = 'admin';
      } else {
        tags['user_type'] = 'user';
      }

      // Update tags on OneSignal
      await OneSignal.User.addTags(tags);
      print('✅ OneSignal tags updated: $tags');

      // Verify tags were set
      final currentTags = await OneSignal.User.getTags();
      print('📋 Current OneSignal tags: $currentTags');

    } catch (e) {
      print('❌ Failed to update OneSignal tags: $e');
    }
  }

  // ==============================================
  // SYNC ONESIGNAL ID TO DATABASE
  // ==============================================
  static Future<bool> syncOneSignalIdToDatabase({
    required String email,
    required String role,
    String? locationName,
  }) async {
    try {
      // Get fresh OneSignal ID
      String? onesignalId = await OneSignal.User.getOnesignalId();

      // If not available, try local storage
      if (onesignalId == null || onesignalId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        onesignalId = prefs.getString('onesignal_id');
      }

      if (onesignalId == null || onesignalId.isEmpty) {
        print('❌ No OneSignal ID to sync');
        return false;
      }

      print('📤 Syncing OneSignal ID to database: $onesignalId');
      print('📤 Email: $email, Role: $role, Location: $locationName');

      final url = Uri.parse('https://quantorra.co/tiffinwales/send_notification.php');
      final response = await http.post(
        url,
        body: {
          'action': 'update_onesignal_id',
          'email': email,
          'onesignal_id': onesignalId,
          'role': role,
          'location_name': locationName ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          print('✅ OneSignal ID synced to database successfully');

          // Save sync timestamp
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('onesignal_sync_time', DateTime.now().toIso8601String());

          return true;
        } else {
          print('❌ Server error during sync: ${data['message']}');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error syncing OneSignal ID: $e');
      return false;
    }
  }

  // ==============================================
  // UPDATE USER DATA (Call this when user data changes)
  // ==============================================
  static Future<void> updateUserData({
    required String email,
    required String role,
    String? locationName,
  }) async {
    try {
      print('🔄 Updating user data in OneSignal...');

      // Update tags with new data
      await _updateUserTags(email, role, locationName);

      // Get fresh OneSignal ID
      String? osId = await OneSignal.User.getOnesignalId();

      if (osId != null && osId.isNotEmpty) {
        // Save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('onesignal_id', osId);
        await prefs.setString('user_email', email);
        await prefs.setString('user_role', role);
        if (locationName != null) {
          await prefs.setString('user_location', locationName);
        }

        // Sync to database
        await syncOneSignalIdToDatabase(
          email: email,
          role: role,
          locationName: locationName,
        );
      }

      print('✅ User data updated successfully');
    } catch (e) {
      print('❌ Failed to update user data: $e');
    }
  }

  // ==============================================
  // GET CURRENT USER DATA FROM LOCAL STORAGE
  // ==============================================
  static Future<Map<String, String?>> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('user_email'),
        'role': prefs.getString('user_role'),
        'location': prefs.getString('user_location'),
        'onesignal_id': prefs.getString('onesignal_id'),
      };
    } catch (e) {
      print('❌ Failed to get user data: $e');
      return {};
    }
  }

  // ==============================================
  // FORCE REFRESH ONESIGNAL TOKEN
  // ==============================================
  static Future<void> refreshOneSignalToken() async {
    try {
      print('🔄 Refreshing OneSignal token...');

      // Get current user data
      final userData = await getUserData();
      final email = userData['email'];
      final role = userData['role'];
      final location = userData['location'];

      if (email == null || role == null) {
        print('❌ No user data found to refresh');
        return;
      }

      // Re-initialize with current user data
      await initializeOneSignalAfterLogin(
        email: email,
        role: role,
        locationName: location,
      );

      print('✅ OneSignal token refreshed');
    } catch (e) {
      print('❌ Failed to refresh OneSignal token: $e');
    }
  }

  // ==============================================
  // HANDLE NOTIFICATION CLICK (Deep Linking)
  // ==============================================
  static void handleNotificationClick(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;

    try {
      final String target = data['target']?.toString() ?? '';
      final String orderId = data['order_id']?.toString() ?? '';

      print('🔔 Notification clicked - Target: $target | Order ID: $orderId');

      if (navigatorKey.currentState == null) {
        print('⚠️ Navigator not ready yet, skipping deep link');
        return;
      }

      switch (target) {
        case 'orders':
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/manager',
                (route) => false,
            arguments: {
              'initialTab': 2, // Orders tab index
              'highlightOrderId': orderId,
            },
          );
          break;

        case 'menu':
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/manager',
                (route) => false,
            arguments: {'initialTab': 1}, // Menu tab index
          );
          break;

        case 'promotions':
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/manager',
                (route) => false,
            arguments: {'initialTab': 3}, // Promos tab index
          );
          break;

        default:
          print('ℹ️ No specific route for target: $target');
          break;
      }
    } catch (e) {
      print('❌ Error handling notification click: $e');
    }
  }
}