// lib/models/subscription_models.dart

import 'dart:convert';
import 'dart:typed_data' show Uint8List;  // ✅ ADD THIS IMPORT
import 'package:flutter/material.dart';

class SubscriptionPlan {
  final int id;
  final String locationName;
  final String planType;
  final String planName;
  final String description;
  final double price;
  final int durationDays;
  final int maxDishes;
  final int? imageId;
  final bool isActive;
  final String? imageBase64;
  final String? imageName;
  final int? imageSize;
  final String? mimeType;
  final String? imageTitle;

  SubscriptionPlan({
    required this.id,
    required this.locationName,
    required this.planType,
    required this.planName,
    this.description = '',
    required this.price,
    required this.durationDays,
    required this.maxDishes,
    this.imageId,
    this.isActive = true,
    this.imageBase64,
    this.imageName,
    this.imageSize,
    this.mimeType,
    this.imageTitle,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    // Debug: Print the image data
    print('Plan: ${json['plan_name']}, Image Base64: ${json['image_base64'] != null ? 'Has Image (${json['image_base64'].length} chars)' : 'No Image'}');

    return SubscriptionPlan(
      id: json['id'] as int,
      locationName: json['location_name']?.toString() ?? '',
      planType: json['plan_type']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      durationDays: int.tryParse(json['duration_days']?.toString() ?? '0') ?? 0,
      maxDishes: int.tryParse(json['max_dishes']?.toString() ?? '0') ?? 0,
      imageId: json['image_id'] as int?,
      isActive: json['is_active'] == 1,
      imageBase64: json['image_base64']?.toString(),
      imageName: json['image_name']?.toString(),
      imageSize: json['image_size'] as int?,
      mimeType: json['mime_type']?.toString(),
      imageTitle: json['image_title']?.toString(),
    );
  }

  factory SubscriptionPlan.fromBackend(Map<String, dynamic> json) {
    return SubscriptionPlan.fromJson(json);
  }

  // ✅ ADD THIS: Check if plan has a valid image
  bool get hasImage {
    return imageBase64 != null && imageBase64!.isNotEmpty;
  }

  // ✅ ADD THIS: Get image bytes if available
  Uint8List? get imageBytes {
    if (!hasImage) return null;
    try {
      return base64Decode(imageBase64!);
    } catch (e) {
      print('Error decoding image for ${planName}: $e');
      return null;
    }
  }

  String get formattedPrice => '\$${price.toStringAsFixed(2)}';
  String get planLabel => '$planName - ${durationDays} Days';

  Color get gradientColor1 {
    switch (planType) {
      case '3days':
        return const Color(0xFF667EEA);
      case '5days':
        return const Color(0xFFF093FB);
      case '7days':
        return const Color(0xFF4FACFE);
      case '15days':
        return const Color(0xFF43E97B);
      case '30days':
        return const Color(0xFFFA709A);
      default:
        return const Color(0xFF667EEA);
    }
  }

  Color get gradientColor2 {
    switch (planType) {
      case '3days':
        return const Color(0xFF764BA2);
      case '5days':
        return const Color(0xFFF5576C);
      case '7days':
        return const Color(0xFF00F2FE);
      case '15days':
        return const Color(0xFF38F9D7);
      case '30days':
        return const Color(0xFFFEE140);
      default:
        return const Color(0xFF764BA2);
    }
  }

  IconData get icon {
    switch (planType) {
      case '3days':
        return Icons.weekend;
      case '5days':
        return Icons.work;
      case '7days':
        return Icons.calendar_view_week;
      case '15days':
        return Icons.calendar_month;
      case '30days':
        return Icons.calendar_today;
      default:
        return Icons.restaurant;
    }
  }

  String get tag {
    if (durationDays == 3) return 'TRIAL';
    if (durationDays == 5) return 'POPULAR';
    if (durationDays == 7) return 'BEST VALUE';
    if (durationDays == 15) return 'SAVE MAX';
    if (durationDays == 30) return 'PREMIUM';
    return 'PLAN';
  }

  bool get isPopular => durationDays == 5 || durationDays == 7;
}

// ==============================================
// REST OF YOUR FILE (UserSubscription, SubscriptionDish, SubscriptionPlanFull)
// ==============================================

class UserSubscription {
  final int id;
  final String userEmail;
  final String locationName;
  final SubscriptionPlan plan;
  final String mealType;
  final String breadType;
  final String spiceLevel;
  final List<String> selectedDishes;
  final double totalPrice;
  final String deliveryOption;
  final DateTime deliveryDate;
  final String deliveryTimeSlot;
  final String specialInstructions;
  final DateTime startDate;
  final DateTime endDate;
  final int daysRemaining;
  final String status;
  final int orderCount;

  UserSubscription({
    required this.id,
    required this.userEmail,
    required this.locationName,
    required this.plan,
    this.mealType = 'veg',
    this.breadType = 'naan',
    this.spiceLevel = 'mild',
    this.selectedDishes = const [],
    required this.totalPrice,
    this.deliveryOption = 'delivery',
    required this.deliveryDate,
    required this.deliveryTimeSlot,
    this.specialInstructions = '',
    required this.startDate,
    required this.endDate,
    this.daysRemaining = 0,
    this.status = 'pending',
    this.orderCount = 0,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json, SubscriptionPlan plan) {
    List<String> dishes = [];
    if (json['selected_dishes'] != null) {
      if (json['selected_dishes'] is List) {
        dishes = List<String>.from(json['selected_dishes']);
      } else if (json['selected_dishes'] is String) {
        try {
          final decoded = jsonDecode(json['selected_dishes']);
          if (decoded is List) {
            dishes = List<String>.from(decoded);
          }
        } catch (e) {}
      }
    }

    return UserSubscription(
      id: json['id'] as int,
      userEmail: json['user_email']?.toString() ?? '',
      locationName: json['location_name']?.toString() ?? '',
      plan: plan,
      mealType: json['meal_type']?.toString() ?? 'veg',
      breadType: json['bread_type']?.toString() ?? 'naan',
      spiceLevel: json['spice_level']?.toString() ?? 'mild',
      selectedDishes: dishes,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      deliveryOption: json['delivery_option']?.toString() ?? 'delivery',
      deliveryDate: DateTime.tryParse(json['delivery_date']?.toString() ?? '') ?? DateTime.now(),
      deliveryTimeSlot: json['delivery_time_slot']?.toString() ?? '',
      specialInstructions: json['special_instructions']?.toString() ?? '',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now(),
      daysRemaining: json['days_remaining'] as int? ?? 0,
      status: json['status']?.toString() ?? 'pending',
      orderCount: json['order_count'] as int? ?? 0,
    );
  }

  String get formattedPrice => '\$${totalPrice.toStringAsFixed(2)}';

  Color get statusColor {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }
}

class SubscriptionDish {
  final int id;
  final String dishName;
  final String category;
  final bool isAvailable;

  SubscriptionDish({
    required this.id,
    required this.dishName,
    this.category = 'veg',
    this.isAvailable = true,
  });

  factory SubscriptionDish.fromJson(Map<String, dynamic> json) {
    return SubscriptionDish(
      id: json['id'] as int,
      dishName: json['dish_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'veg',
      isAvailable: json['is_available'] == 1,
    );
  }
}

class SubscriptionPlanFull {
  final int id;
  final String locationName;
  final String planType;
  final String planName;
  final String description;
  final double price;
  final int durationDays;
  final int maxDishes;
  final String? imageBase64;
  final List<String> dishes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  SubscriptionPlanFull({
    required this.id,
    required this.locationName,
    required this.planType,
    required this.planName,
    this.description = '',
    required this.price,
    required this.durationDays,
    required this.maxDishes,
    this.imageBase64,
    this.dishes = const [],
    this.isActive = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory SubscriptionPlanFull.fromJson(Map<String, dynamic> json) {
    List<String> dishList = [];
    if (json['dishes'] != null) {
      if (json['dishes'] is List) {
        dishList = List<String>.from(json['dishes']);
      } else if (json['dishes'] is String && json['dishes'].isNotEmpty) {
        try {
          final decoded = jsonDecode(json['dishes']);
          if (decoded is List) {
            dishList = List<String>.from(decoded);
          }
        } catch (e) {}
      }
    }

    return SubscriptionPlanFull(
      id: json['id'] as int,
      locationName: json['location_name']?.toString() ?? '',
      planType: json['plan_type']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      durationDays: int.tryParse(json['duration_days']?.toString() ?? '0') ?? 0,
      maxDishes: int.tryParse(json['max_dishes']?.toString() ?? '0') ?? 0,
      imageBase64: json['image_base64']?.toString(),
      dishes: dishList,
      isActive: json['is_active'] == 1,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location_name': locationName,
      'plan_type': planType,
      'plan_name': planName,
      'description': description,
      'price': price,
      'duration_days': durationDays,
      'max_dishes': maxDishes,
      'image_base64': imageBase64,
      'dishes': jsonEncode(dishes),
      'is_active': isActive ? 1 : 0,
    };
  }

  String get formattedPrice => '\$${price.toStringAsFixed(2)}';
}