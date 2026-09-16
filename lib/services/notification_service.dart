import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'initialization_service.dart';

class NotificationService {
  // ==========================================================
  // SINGLETON
  // ==========================================================

  static final NotificationService _instance =
  NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  // ==========================================================
  // LOCAL NOTIFICATION PLUGIN
  // ==========================================================

  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // ==========================================================
  // CHANNEL IDS
  // ==========================================================

  // This channel is ONLY for notifications generated locally
  // by your Flutter application.
  //
  // It is NOT the OneSignal channel.
  static const String urgentChannelId =
      'tiffinwales_local_urgent';

  static const String regularChannelId =
      'tiffinwales_local_regular';

  // ==========================================================
  // INITIALIZATION FLAG
  // ==========================================================

  bool _isInitialized = false;

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> initialize() async {
    if (_isInitialized) {
      print('ℹ️ NotificationService already initialized');
      return;
    }

    try {
      print('');
      print('==========================================');
      print('🚀 INITIALIZING LOCAL NOTIFICATIONS');
      print('==========================================');

      // ------------------------------------------------------
      // 1. Initialize plugin
      // ------------------------------------------------------

      await _initializeLocalNotifications();

      // ------------------------------------------------------
      // 2. Create local Android channels
      // ------------------------------------------------------

      await _createNotificationChannels();

      _isInitialized = true;

      print('✅ Local Notification Service initialized');
      print('');
    } catch (e, stackTrace) {
      print('❌ Local notification initialization failed');
      print('Error: $e');
      print('StackTrace: $stackTrace');

      rethrow;
    }
  }

  // ==========================================================
  // INITIALIZE LOCAL NOTIFICATIONS
  // ==========================================================

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings =
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse:
      _onNotificationResponse,
    );

    print('✅ Flutter Local Notifications initialized');
  }

  // ==========================================================
  // LOCAL NOTIFICATION CLICK
  // ==========================================================

  void _onNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          InitializationService.handleNotificationClick(decoded);
        }
      } catch (e) {
        print(' Error parsing notification payload: $e');
      }
    }
  }
  // ==========================================================
  // CREATE ANDROID CHANNELS
  // ==========================================================

  // In your NotificationService.dart

  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
    _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return;

    // 🔥 Create the OneSignal channel
    final AndroidNotificationChannel onesignalChannel = AndroidNotificationChannel(
      '4a8700a6-dfb8-40de-aef2-4675c9b41f06', // Your OneSignal channel ID
      'TiffinWales Urgent',
      description: 'Urgent notifications from TiffinWales',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      ledColor: const Color(0xFF6366F1),
    );

    try {
      await android.createNotificationChannel(onesignalChannel);
      print('✅ OneSignal channel created');
    } catch (e) {
      print('❌ Failed to create OneSignal channel: $e');
    }
  }

  // ==========================================================
  // SHOW LOCAL URGENT NOTIFICATION
  // ==========================================================

  Future<void> showUrgentNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      urgentChannelId,
      'TiffinWales Local Urgent',
      channelDescription:
      'Urgent notifications generated locally',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      vibrationPattern: Int64List.fromList([
        0,
        500,
        200,
        500,
      ]),
      fullScreenIntent: false,
      timeoutAfter: 60000,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
      visibility: NotificationVisibility.public,
      ledColor: const Color(0xFF6366F1),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails details =
    NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String? payload =
    data.isNotEmpty ? jsonEncode(data) : null;

    try {
      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );

      print(
        '🔔 Local urgent notification shown: $title',
      );
    } catch (e) {
      print(
        '❌ Failed to show local urgent notification: $e',
      );
    }
  }

  // ==========================================================
  // SHOW LOCAL REGULAR NOTIFICATION
  // ==========================================================

  Future<void> showRegularNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      regularChannelId,
      'TiffinWales Local Notifications',
      channelDescription:
      'Regular TiffinWales notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details =
    NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String? payload =
    data.isNotEmpty ? jsonEncode(data) : null;

    try {
      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );

      print(
        '🔔 Local regular notification shown: $title',
      );
    } catch (e) {
      print(
        '❌ Failed to show local notification: $e',
      );
    }
  }

  // ==========================================================
  // SAVE FCM TOKEN
  // ==========================================================
  //
  // This is kept because your application may use the FCM
  // token elsewhere.
  //
  // IMPORTANT:
  // This service does NOT register Firebase foreground/
  // background handlers for notification display.
  //
  // OneSignal handles OneSignal push notifications.
  // ==========================================================

  Future<void> saveFCMToken(String token) async {
    try {
      final SharedPreferences prefs =
      await SharedPreferences.getInstance();

      await prefs.setString(
        'fcm_token',
        token,
      );

      print('✅ FCM Token saved');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // ==========================================================
  // HANDLE LOCAL NOTIFICATION CLICK
  // ==========================================================

  void _handleNotificationClick(
      Map<String, dynamic> data,
      ) {
    print('');
    print('==========================================');
    print('🔔 LOCAL NOTIFICATION CLICKED');
    print('==========================================');

    print('Data: $data');

    final String target =
        data['target']?.toString() ?? 'home';

    final String orderId =
        data['order_id']?.toString() ?? '';

    print('🎯 Target: $target');

    if (orderId.isNotEmpty) {
      print('📦 Order ID: $orderId');
    }

    // --------------------------------------------------------
    // ADD YOUR NAVIGATION LOGIC HERE
    // --------------------------------------------------------
  }

  // ==========================================================
  // GET INITIALIZATION STATUS
  // ==========================================================

  bool get isInitialized => _isInitialized;
}