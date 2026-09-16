// lib/screens/manager/user_subscriptions_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserSubscriptionsScreen extends StatefulWidget {
  final String locationName;
  final String email;

  const UserSubscriptionsScreen({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  State<UserSubscriptionsScreen> createState() => _UserSubscriptionsScreenState();
}

class _UserSubscriptionsScreenState extends State<UserSubscriptionsScreen> {
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = true;
  bool _isMarking = false;
  bool _isDeleting = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterStatus = 'all';
  Set<int> _expandedCards = {};
  Set<String> _processingDishes = {};

  final String apiUrl = 'https://quantorra.co/tiffinwales/SubscriptionManager.php';

  final Map<String, Color> _statusColors = {
    'pending': Color(0xFFF59E0B),
    'active': Color(0xFF22C55E),
    'completed': Color(0xFF3B82F6),
    'cancelled': Color(0xFFEF4444),
  };

  final Map<String, String> _planEmojis = {
    '3days': '🌿',
    '5days': '🔥',
    '7days': '⭐',
    '15days': '👑',
    '30days': '💎',
    'custom': '🎯',
  };

  final Map<String, List<Color>> _planGradients = {
    '3days': [Color(0xFF667EEA), Color(0xFF764BA2)],
    '5days': [Color(0xFFF093FB), Color(0xFFF5576C)],
    '7days': [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    '15days': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    '30days': [Color(0xFFFA709A), Color(0xFFFEE140)],
    'custom': [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  };

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'get_user_subscriptions_by_location',
          'location_name': widget.locationName,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      var data = json.decode(response.body);

      if (!mounted) return;

      if (data['status'] == 'success') {
        final subscriptions = List<Map<String, dynamic>>.from(data['data'] ?? []);

        // Process each subscription to ensure data is properly parsed
        for (var i = 0; i < subscriptions.length; i++) {
          final sub = subscriptions[i];

          // Ensure selected_dishes is properly parsed
          if (sub['selected_dishes'] != null) {
            if (sub['selected_dishes'] is String) {
              try {
                final decoded = jsonDecode(sub['selected_dishes']);
                if (decoded is List) {
                  sub['selected_dishes'] = decoded;
                }
              } catch (e) {
                // If it's a comma-separated string
                final str = sub['selected_dishes'] as String;
                if (str.contains(',')) {
                  sub['selected_dishes'] = str.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                } else if (str.isNotEmpty) {
                  sub['selected_dishes'] = [str];
                } else {
                  sub['selected_dishes'] = [];
                }
              }
            }
          } else {
            sub['selected_dishes'] = [];
          }

          // Ensure delivered_dish_instances is a list
          if (sub['delivered_dish_instances'] != null && sub['delivered_dish_instances'] is! List) {
            sub['delivered_dish_instances'] = [];
          }

          subscriptions[i] = sub;
        }

        setState(() {
          _subscriptions = subscriptions;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load subscriptions';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // ==============================================
// GET DISH STATUS WITH COUNTS - FIXED
// ==============================================
  Map<String, dynamic> _getDishStatus(Map<String, dynamic> subscription, String dishName) {
    final List<String> deliveredInstances = List<String>.from(subscription['delivered_dish_instances'] ?? []);

    // Ensure selected_dishes is a List<String>
    List<String> selectedDishes = [];
    if (subscription['selected_dishes'] != null) {
      if (subscription['selected_dishes'] is List) {
        selectedDishes = List<String>.from(subscription['selected_dishes']);
      } else if (subscription['selected_dishes'] is String) {
        final str = subscription['selected_dishes'] as String;
        try {
          final decoded = jsonDecode(str);
          if (decoded is List) {
            selectedDishes = List<String>.from(decoded);
          }
        } catch (e) {
          // If it's a comma-separated string
          if (str.contains(',')) {
            selectedDishes = str.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          } else if (str.isNotEmpty) {
            selectedDishes = [str];
          }
        }
      }
    }

    final dishInstances = deliveredInstances.where((d) => d.startsWith(dishName + '|')).toList();
    final deliveredCount = dishInstances.length;

    // Count total occurrences of this dish in selected_dishes
    final totalOccurrences = selectedDishes.where((d) => d == dishName).length;

    return {
      'delivered_count': deliveredCount,
      'required_count': totalOccurrences > 0 ? totalOccurrences : 1,
      'is_completed': deliveredCount >= totalOccurrences && totalOccurrences > 0,
      'remaining': totalOccurrences - deliveredCount,
      'instances': dishInstances,
    };
  }
  // ==============================================
// TOGGLE DELIVERY - FIXED TO PRESERVE ALL FIELDS
// ==============================================
  Future<void> _toggleDelivery(Map<String, dynamic> subscription, String dishName, bool isRemove) async {
    final key = '${subscription['id']}_$dishName';
    if (_processingDishes.contains(key)) return;

    setState(() => _processingDishes.add(key));

    try {
      final action = isRemove ? 'remove_dish_delivery' : 'mark_dish_delivered';
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': action,
          'subscription_id': subscription['id'].toString(),
          'dish_name': dishName,
          'delivery_date': DateTime.now().toIso8601String().split('T').first,
        },
      );

      var data = json.decode(response.body);
      setState(() => _processingDishes.remove(key));

      if (data['status'] == 'success') {
        setState(() {
          final index = _subscriptions.indexWhere((s) => s['id'] == subscription['id']);
          if (index != -1 && data['data'] != null) {
            final updatedData = data['data'];

            // PRESERVE ALL FIELDS by merging with existing data
            _subscriptions[index] = {
              ..._subscriptions[index], // Keep all existing fields
              ...updatedData, // Override with updated fields
              // Ensure these fields are preserved
              'user_name': _subscriptions[index]['user_name'] ?? updatedData['user_name'],
              'user_email': _subscriptions[index]['user_email'] ?? updatedData['user_email'],
              'user_phone': _subscriptions[index]['user_phone'] ?? updatedData['user_phone'],
              'plan_name': _subscriptions[index]['plan_name'] ?? updatedData['plan_name'],
              'plan_type': _subscriptions[index]['plan_type'] ?? updatedData['plan_type'],
              'duration_days': _subscriptions[index]['duration_days'] ?? updatedData['duration_days'],
              'max_dishes': _subscriptions[index]['max_dishes'] ?? updatedData['max_dishes'],
              'total_price': _subscriptions[index]['total_price'] ?? updatedData['total_price'],
              'status': _subscriptions[index]['status'] ?? updatedData['status'],
              'delivery_address': _subscriptions[index]['delivery_address'] ?? updatedData['delivery_address'],
              'delivery_city': _subscriptions[index]['delivery_city'] ?? updatedData['delivery_city'],
              'delivery_postal_code': _subscriptions[index]['delivery_postal_code'] ?? updatedData['delivery_postal_code'],
              'delivery_phone': _subscriptions[index]['delivery_phone'] ?? updatedData['delivery_phone'],
              'meal_type': _subscriptions[index]['meal_type'] ?? updatedData['meal_type'],
              'bread_type': _subscriptions[index]['bread_type'] ?? updatedData['bread_type'],
              'spice_level': _subscriptions[index]['spice_level'] ?? updatedData['spice_level'],
              'delivery_option': _subscriptions[index]['delivery_option'] ?? updatedData['delivery_option'],
              'delivery_date': _subscriptions[index]['delivery_date'] ?? updatedData['delivery_date'],
              'delivery_time_slot': _subscriptions[index]['delivery_time_slot'] ?? updatedData['delivery_time_slot'],
              'special_instructions': _subscriptions[index]['special_instructions'] ?? updatedData['special_instructions'],
              'start_date': _subscriptions[index]['start_date'] ?? updatedData['start_date'],
              'end_date': _subscriptions[index]['end_date'] ?? updatedData['end_date'],
              'created_at': _subscriptions[index]['created_at'] ?? updatedData['created_at'],
              'updated_at': _subscriptions[index]['updated_at'] ?? updatedData['updated_at'],
            };
          }
        });

        _showSnackBar(
            isRemove ? '✅ Delivery removed!' : '✅ Dish marked as delivered!',
            Colors.green
        );
      } else {
        _showSnackBar(data['message'] ?? 'Failed to update', Colors.red);
      }
    } catch (e) {
      setState(() => _processingDishes.remove(key));
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }
  // ==============================================
  // SHOW CUSTOM DELIVERY MANAGEMENT DIALOG
  // ==============================================
// ==============================================
// SHOW CUSTOM DELIVERY MANAGEMENT DIALOG - REDESIGNED
// ==============================================
  void _showCustomDeliveryManagementDialog(Map<String, dynamic> subscription) {
    // Get the current selected dishes list
    List<String> selectedDishes = [];
    if (subscription['selected_dishes'] != null) {
      if (subscription['selected_dishes'] is List) {
        selectedDishes = List<String>.from(subscription['selected_dishes']);
      } else if (subscription['selected_dishes'] is String) {
        try {
          final decoded = jsonDecode(subscription['selected_dishes']);
          if (decoded is List) {
            selectedDishes = List<String>.from(decoded);
          }
        } catch (e) {
          final str = subscription['selected_dishes'] as String;
          if (str.contains(',')) {
            selectedDishes = str.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          } else if (str.isNotEmpty) {
            selectedDishes = [str];
          }
        }
      }
    }

    final totalDays = subscription['duration_days'] ?? 0;

    // Count current occurrences of each dish
    Map<String, int> dishCounts = {};
    for (var dish in selectedDishes) {
      dishCounts[dish] = (dishCounts[dish] ?? 0) + 1;
    }

    // Track delivered counts per dish
    final deliveredInstances = List<String>.from(subscription['delivered_dish_instances'] ?? []);
    Map<String, int> deliveredCounts = {};
    for (var instance in deliveredInstances) {
      final parts = instance.split('|');
      final dishName = parts.first;
      deliveredCounts[dishName] = (deliveredCounts[dishName] ?? 0) + 1;
    }

    // Get unique dishes list
    final uniqueDishes = dishCounts.keys.toList();
    int totalAssigned = selectedDishes.length;
    int remainingToAssign = totalDays - totalAssigned;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ==============================================
                  // HEADER
                  // ==============================================
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.settings_suggest,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Dish Counts',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Set how many times each dish appears',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==============================================
                  // SUMMARY CARDS
                  // ==============================================
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$totalDays',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                                Text(
                                  'Total Days',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$totalAssigned',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Assigned',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: remainingToAssign == 0
                                  ? Colors.green.withOpacity(0.08)
                                  : Colors.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: remainingToAssign == 0
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$remainingToAssign',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: remainingToAssign == 0 ? Colors.green : Colors.orange,
                                  ),
                                ),
                                Text(
                                  'Remaining',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==============================================
                  // DISH LIST
                  // ==============================================
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        itemCount: uniqueDishes.length,
                        itemBuilder: (context, index) {
                          final dish = uniqueDishes[index];
                          final currentCount = dishCounts[dish] ?? 1;
                          final delivered = deliveredCounts[dish] ?? 0;
                          final hasDelivered = delivered > 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasDelivered ? Colors.green.shade200 : Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Row(
                                children: [
                                  // Dish number
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: hasDelivered
                                          ? Colors.green.withOpacity(0.15)
                                          : const Color(0xFF6366F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: hasDelivered ? Colors.green : const Color(0xFF6366F1),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Dish name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dish,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1A202C),
                                          ),
                                        ),
                                        if (hasDelivered)
                                          Text(
                                            '$delivered already delivered',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: Colors.green.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Controls
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Minus button
                                      GestureDetector(
                                        onTap: currentCount > 1 && currentCount > delivered
                                            ? () {
                                          setStateDialog(() {
                                            dishCounts[dish] = currentCount - 1;
                                            totalAssigned = dishCounts.values.fold(0, (sum, count) => sum + count);
                                            remainingToAssign = totalDays - totalAssigned;
                                          });
                                        }
                                            : null,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: currentCount > 1 && currentCount > delivered
                                                ? Colors.red.withOpacity(0.1)
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.remove,
                                            color: currentCount > 1 && currentCount > delivered
                                                ? Colors.red
                                                : Colors.grey.shade400,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Count badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: hasDelivered
                                                ? [Colors.green, Colors.green.shade700]
                                                : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withOpacity(0.2),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '$currentCount',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Plus button
                                      GestureDetector(
                                        onTap: remainingToAssign > 0
                                            ? () {
                                          setStateDialog(() {
                                            dishCounts[dish] = currentCount + 1;
                                            totalAssigned = dishCounts.values.fold(0, (sum, count) => sum + count);
                                            remainingToAssign = totalDays - totalAssigned;
                                          });
                                        }
                                            : null,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: remainingToAssign > 0
                                                ? const Color(0xFF6366F1).withOpacity(0.1)
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.add,
                                            color: remainingToAssign > 0
                                                ? const Color(0xFF6366F1)
                                                : Colors.grey.shade400,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ==============================================
                  // FOOTER WITH ACTION BUTTONS
                  // ==============================================
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Status message
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                remainingToAssign == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                                color: remainingToAssign == 0 ? Colors.green : Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                remainingToAssign == 0
                                    ? '✅ All $totalDays days assigned'
                                    : '⚠️ $remainingToAssign days remaining to assign',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: remainingToAssign == 0 ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: Colors.grey[100],
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: remainingToAssign == 0
                                      ? const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  )
                                      : const LinearGradient(
                                    colors: [Colors.grey, Colors.grey],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: remainingToAssign == 0
                                      ? [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                      : null,
                                ),
                                child: ElevatedButton(
                                  onPressed: remainingToAssign == 0
                                      ? () async {
                                    Navigator.pop(context);
                                    await _saveCustomDishCounts(subscription['id'], dishCounts);
                                  }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.save, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        remainingToAssign == 0 ? 'Save Changes' : 'Assign All Days',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // ==============================================
  // SAVE CUSTOM DISH COUNTS TO DATABASE
  // ==============================================
// SAVE CUSTOM DISH COUNTS TO DATABASE - FIXED
// ==============================================
  // ==============================================
// SAVE CUSTOM DISH COUNTS TO DATABASE - FIXED
// ==============================================
  Future<void> _saveCustomDishCounts(int subscriptionId, Map<String, int> dishCounts) async {
    setState(() => _isMarking = true);

    try {
      // Convert counts to list format: each dish repeated based on count
      List<String> selectedDishes = [];
      dishCounts.forEach((dish, count) {
        for (int i = 0; i < count; i++) {
          selectedDishes.add(dish);
        }
      });

      print('📤 Saving dishes for subscription $subscriptionId: $selectedDishes');

      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'update_subscription_dishes',
          'subscription_id': subscriptionId.toString(),
          'selected_dishes': jsonEncode(selectedDishes),
        },
      );

      print('📥 Response: ${response.body}');

      var data = json.decode(response.body);
      setState(() => _isMarking = false);

      if (data['status'] == 'success') {
        // Update local data - preserve all fields
        setState(() {
          final index = _subscriptions.indexWhere((s) => s['id'] == subscriptionId);
          if (index != -1 && data['data'] != null) {
            final updatedData = data['data'];
            // Merge the updated data with existing data to preserve fields
            _subscriptions[index] = {
              ..._subscriptions[index],
              ...updatedData,
              // Ensure selected_dishes is properly set
              'selected_dishes': updatedData['selected_dishes'] ?? _subscriptions[index]['selected_dishes'],
            };
          }
        });

        _showSnackBar('✅ Dish counts updated successfully!', Colors.green);

        // Reload subscriptions to get fresh data
        await _loadSubscriptions();
      } else {
        _showSnackBar(data['message'] ?? 'Failed to update', Colors.red);
      }
    } catch (e) {
      setState(() => _isMarking = false);
      print('❌ Error saving dish counts: $e');
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == Colors.green ? Icons.check_circle : Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStatusColor(String status) {
    return _statusColors[status] ?? Colors.grey;
  }

  List<Map<String, dynamic>> get _filteredSubscriptions {
    var filtered = _subscriptions;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) =>
      (s['user_name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['user_email'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['plan_name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_filterStatus != 'all') {
      filtered = filtered.where((s) =>
      (s['status'] ?? '').toLowerCase() == _filterStatus.toLowerCase()
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _filteredSubscriptions.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadSubscriptions,
              color: const Color(0xFF6366F1),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredSubscriptions.length,
                itemBuilder: (context, index) {
                  final sub = _filteredSubscriptions[index];
                  return _buildSubscriptionCard(sub);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading subscriptions...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _loadSubscriptions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.08),
                  const Color(0xFF8B5CF6).withOpacity(0.08),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.people_outline,
              size: 80,
              color: const Color(0xFF6366F1).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Subscriptions Yet',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users will appear here once they subscribe',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // EXPANDABLE SUBSCRIPTION CARD
  // ==============================================
  // ==============================================
// EXPANDABLE SUBSCRIPTION CARD - FIXED
// ==============================================
  // ==============================================
// EXPANDABLE SUBSCRIPTION CARD - FIXED
// ==============================================
  Widget _buildSubscriptionCard(Map<String, dynamic> subscription) {
    final statusColor = _getStatusColor(subscription['status'] ?? 'pending');
    final deliveredCount = subscription['delivered_count'] ?? 0;
    final totalDishes = subscription['total_dishes'] ?? subscription['duration_days'] ?? 0;
    final remainingDishes = subscription['remaining_dishes'] ?? (totalDishes - deliveredCount);
    final progress = totalDishes > 0 ? deliveredCount / totalDishes : 0.0;
    final isCompleted = subscription['status'] == 'completed' || remainingDishes <= 0;
    final isExpanded = _expandedCards.contains(subscription['id']);

    // SAFELY PARSE SELECTED DISHES
    List<String> selectedDishes = [];
    if (subscription['selected_dishes'] != null) {
      if (subscription['selected_dishes'] is List) {
        selectedDishes = List<String>.from(subscription['selected_dishes']);
      } else if (subscription['selected_dishes'] is String) {
        final str = subscription['selected_dishes'] as String;
        try {
          final decoded = jsonDecode(str);
          if (decoded is List) {
            selectedDishes = List<String>.from(decoded);
          }
        } catch (e) {
          // If it's a comma-separated string
          if (str.contains(',')) {
            selectedDishes = str.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          } else if (str.isNotEmpty) {
            selectedDishes = [str];
          }
        }
      }
    }

    // Get user name safely
    final userName = subscription['user_name'] ??
        subscription['username'] ??
        subscription['name'] ??
        'Unknown User';

    final planType = subscription['plan_type'] ?? '3days';
    final gradientColors = _planGradients[planType] ?? [Color(0xFF6366F1), Color(0xFF8B5CF6)];
    final emoji = _planEmojis[planType] ?? '📦';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Always visible
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(subscription['id']);
                } else {
                  _expandedCards.add(subscription['id']);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                userName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isCompleted ? 'COMPLETED' : (subscription['status'] ?? 'pending').toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          subscription['plan_name'] ?? 'Meal Plan',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 400),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _buildExpandedContent(subscription, statusColor, gradientColors, selectedDishes),
            secondChild: _buildCollapsedContent(subscription, statusColor, gradientColors),
          ),
        ],
      ),
    );
  }
  // ==============================================
  // COLLAPSED CONTENT
  // ==============================================
  Widget _buildCollapsedContent(Map<String, dynamic> subscription, Color statusColor, List<Color> gradientColors) {
    final deliveredCount = subscription['delivered_count'] ?? 0;
    final totalDishes = subscription['total_dishes'] ?? subscription['duration_days'] ?? 0;
    final progress = totalDishes > 0 ? deliveredCount / totalDishes : 0.0;
    final isCompleted = subscription['status'] == 'completed' || deliveredCount >= totalDishes;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _buildChip('${subscription['duration_days']} Days', Icons.calendar_today, statusColor),
              const SizedBox(width: 8),
              _buildChip('${subscription['max_dishes'] ?? 0} Dishes', Icons.restaurant, statusColor),
              const SizedBox(width: 8),
              _buildChip('\$${subscription['total_price']?.toString() ?? '0.00'}', Icons.attach_money, statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$deliveredCount / $totalDishes',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        color: isCompleted ? Colors.green : statusColor,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showEditSubscriptionDialog(subscription),
                icon: const Icon(Icons.edit, color: Color(0xFF6366F1)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isDeleting ? null : () => _deleteSubscription(subscription),
                icon: _isDeleting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                )
                    : const Icon(Icons.delete_outline, color: Colors.red),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================
  // EXPANDED CONTENT - FULL DETAILS
  // ==============================================
  // ==============================================
// EXPANDED CONTENT - FULL DETAILS - FIXED
// ==============================================
  Widget _buildExpandedContent(Map<String, dynamic> subscription, Color statusColor, List<Color> gradientColors, List<String> selectedDishes) {
    final deliveredCount = subscription['delivered_count'] ?? 0;
    final totalDishes = subscription['total_dishes'] ?? subscription['duration_days'] ?? 0;
    final remainingDishes = subscription['remaining_dishes'] ?? (totalDishes - deliveredCount);
    final progress = totalDishes > 0 ? deliveredCount / totalDishes : 0.0;
    final isCompleted = subscription['status'] == 'completed' || remainingDishes <= 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan Info
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip('${subscription['duration_days']} Days', Icons.calendar_today, statusColor),
              _buildChip('${subscription['max_dishes'] ?? 0} Dishes', Icons.restaurant, statusColor),
              _buildChip('\$${subscription['total_price']?.toString() ?? '0.00'}', Icons.attach_money, statusColor),
            ],
          ),
          const SizedBox(height: 14),

          // Progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    Text(
                      '$deliveredCount / $totalDishes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: isCompleted ? Colors.green : statusColor,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCompleted
                      ? '✅ All dishes delivered!'
                      : '${remainingDishes} dish${remainingDishes > 1 ? 'es' : ''} remaining',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isCompleted ? Colors.green : Colors.grey[500],
                    fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dishes Section
          if (selectedDishes.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🍽️ Dishes',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selectedDishes.length} items',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFF59E0B).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => _showCustomDeliveryManagementDialog(subscription),
                        icon: const Icon(Icons.settings_suggest, color: Colors.white, size: 18),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: List.generate(selectedDishes.length, (index) {
                  final dish = selectedDishes[index];
                  final status = _getDishStatus(subscription, dish);
                  final isCompleted = status['is_completed'] ?? false;
                  final deliveredCount = status['delivered_count'] ?? 0;
                  final requiredCount = status['required_count'] ?? 1;
                  final remaining = status['remaining'] ?? 0;
                  final instances = status['instances'] ?? [];
                  final instanceNumber = deliveredCount + 1;

                  final deliveredInstances = List<String>.from(subscription['delivered_dish_instances'] ?? []);
                  final dishInstances = deliveredInstances.where((d) => d.startsWith(dish + '|')).toList();
                  final key = '${subscription['id']}_$dish';
                  final isProcessing = _processingDishes.contains(key);

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withOpacity(0.1)
                              : deliveredCount > 0
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green.shade300
                                : deliveredCount > 0
                                ? Colors.orange.shade300
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: isProcessing
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6366F1),
                            ),
                          )
                              : Icon(
                            isCompleted ? Icons.check_circle :
                            deliveredCount > 0 ? Icons.pending : Icons.food_bank,
                            color: isCompleted
                                ? Colors.green
                                : deliveredCount > 0
                                ? Colors.orange
                                : Colors.grey,
                            size: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        dish,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.green.shade700
                              : const Color(0xFF1A202C),
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            '$deliveredCount / $requiredCount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (dishInstances.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${dishInstances.length}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'DONE',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                          if (!isCompleted && remaining > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$remaining left',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // MINUS BUTTON - Remove delivery
                          IconButton(
                            onPressed: (isProcessing || deliveredCount <= 0)
                                ? null
                                : () => _toggleDelivery(subscription, dish, true),
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: (deliveredCount > 0)
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          // Counter Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: isCompleted
                                  ? const LinearGradient(
                                colors: [Colors.green, Colors.green],
                              )
                                  : deliveredCount > 0
                                  ? const LinearGradient(
                                colors: [Colors.orange, Colors.orange],
                              )
                                  : const LinearGradient(
                                colors: [Colors.grey, Colors.grey],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$deliveredCount',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // PLUS BUTTON - Add delivery
                          IconButton(
                            onPressed: (isProcessing || remaining <= 0 || isCompleted)
                                ? null
                                : () => _toggleDelivery(subscription, dish, false),
                            icon: Icon(
                              Icons.add_circle,
                              color: (remaining > 0 && !isCompleted)
                                  ? const Color(0xFF6366F1)
                                  : Colors.grey.shade300,
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Action Buttons
          // ==============================================
// ACTION BUTTONS - UPDATED WITH VIEW DETAILS
// ==============================================
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showEditSubscriptionDialog(subscription),
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showSubscriptionDetailsDialog(subscription),
                    icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                    label: Text(
                      'Details',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isDeleting ? null : () => _deleteSubscription(subscription),
                    icon: _isDeleting
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    label: Text(
                      _isDeleting ? 'Deleting...' : 'Delete',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // EDIT SUBSCRIPTION DIALOG
  // ==============================================
  void _showEditSubscriptionDialog(Map<String, dynamic> subscription) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditSheet(subscription),
    );
  }

  Widget _buildEditSheet(Map<String, dynamic> subscription) {
    String selectedStatus = subscription['status'] ?? 'pending';
    String selectedMealType = subscription['meal_type'] ?? 'veg';
    String selectedBreadType = subscription['bread_type'] ?? 'naan';
    String selectedSpiceLevel = subscription['spice_level'] ?? 'mild';

    final TextEditingController deliveryDateController = TextEditingController(
      text: subscription['delivery_date'] ?? '',
    );
    final TextEditingController timeSlotController = TextEditingController(
      text: subscription['delivery_time_slot'] ?? '',
    );
    final TextEditingController instructionsController = TextEditingController(
      text: subscription['special_instructions'] ?? '',
    );

    return StatefulBuilder(
      builder: (context, setStateSheet) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 60,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Subscription',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A202C),
                                    ),
                                  ),
                                  Text(
                                    'Update subscription details',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              _buildEditInfoRow('Customer', subscription['user_name'] ?? 'N/A'),
                              _buildEditInfoRow('Email', subscription['user_email'] ?? 'N/A'),
                              _buildEditInfoRow('Plan', subscription['plan_name'] ?? 'N/A'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDropdown('Status', selectedStatus, ['pending', 'active', 'completed', 'cancelled'],
                                (v) => setStateSheet(() => selectedStatus = v!), _statusColors[selectedStatus] ?? Colors.grey),
                        const SizedBox(height: 16),
                        _buildDropdown('Meal Type', selectedMealType, ['veg', 'nonveg', 'both'],
                                (v) => setStateSheet(() => selectedMealType = v!), const Color(0xFF6366F1)),
                        const SizedBox(height: 16),
                        _buildDropdown('Bread Type', selectedBreadType, ['naan', 'roti', 'both'],
                                (v) => setStateSheet(() => selectedBreadType = v!), const Color(0xFFF59E0B)),
                        const SizedBox(height: 16),
                        _buildDropdown('Spice Level', selectedSpiceLevel, ['mild', 'medium', 'hot'],
                                (v) => setStateSheet(() => selectedSpiceLevel = v!), const Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.calendar_today, color: Color(0xFF6366F1)),
                            title: Text(
                              'Delivery Date',
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                            ),
                            subtitle: Text(
                              deliveryDateController.text.isEmpty ? 'Select date' : deliveryDateController.text,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A202C),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_calendar, color: Color(0xFF6366F1)),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 30)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF6366F1),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setStateSheet(() {
                                    deliveryDateController.text = date.toIso8601String().split('T').first;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: TextField(
                            controller: timeSlotController,
                            style: GoogleFonts.poppins(fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'Time Slot',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                              prefixIcon: const Icon(Icons.access_time, color: Color(0xFF6366F1)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              hintText: 'e.g., 12:00 PM - 1:00 PM',
                              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: TextField(
                            controller: instructionsController,
                            style: GoogleFonts.poppins(fontSize: 15),
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Special Instructions',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                              prefixIcon: const Icon(Icons.note, color: Color(0xFF6366F1)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              hintText: 'Enter special instructions...',
                              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: Colors.grey[100],
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _executeUpdate(
                                      subscription['id'],
                                      selectedStatus,
                                      selectedMealType,
                                      selectedBreadType,
                                      selectedSpiceLevel,
                                      deliveryDateController.text,
                                      timeSlotController.text,
                                      instructionsController.text,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: Text(
                                    'Update',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
          Text(
            ':',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.circle, color: color, size: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item.toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6366F1)),
      ),
    );
  }

  Future<void> _executeUpdate(
      int id,
      String status,
      String mealType,
      String breadType,
      String spiceLevel,
      String deliveryDate,
      String timeSlot,
      String instructions,
      ) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'update_subscription',
          'subscription_id': id.toString(),
          'status': status,
          'meal_type': mealType,
          'bread_type': breadType,
          'spice_level': spiceLevel,
          'delivery_date': deliveryDate,
          'delivery_time_slot': timeSlot,
          'special_instructions': instructions,
        },
      );

      var data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackBar('✅ Subscription updated!', Colors.green);
        _loadSubscriptions();
      } else {
        throw Exception(data['message'] ?? 'Failed to update');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  // ==============================================
  // DELETE SUBSCRIPTION
  // ==============================================
// DELETE SUBSCRIPTION - FIXED
// ==============================================
  Future<void> _deleteSubscription(Map<String, dynamic> subscription) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Delete Subscription',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this subscription?',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeleteRow('Customer', subscription['user_name'] ?? 'N/A'),
                  _buildDeleteRow('Plan', subscription['plan_name'] ?? 'N/A'),
                  _buildDeleteRow('Status', (subscription['status'] ?? 'pending').toUpperCase()),
                  _buildDeleteRow('Progress',
                      '${subscription['delivered_count'] ?? 0} / ${subscription['total_dishes'] ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              minimumSize: const Size(0, 44),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Delete',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeDeleteSubscription(subscription['id']);
    }
  }
// ==============================================
// SHOW SUBSCRIPTION DETAILS DIALOG
// ==============================================
  void _showSubscriptionDetailsDialog(Map<String, dynamic> subscription) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subscription Details',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Complete subscription information',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info Section
                      _buildDetailSection(
                        title: '👤 Customer Information',
                        icon: Icons.person,
                        color: const Color(0xFF6366F1),
                        children: [
                          _buildDetailRow('Name', subscription['user_name'] ?? 'N/A'),
                          _buildDetailRow('Email', subscription['user_email'] ?? 'N/A'),
                          _buildDetailRow('Phone', subscription['user_phone'] ?? 'N/A'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Plan Info Section
                      _buildDetailSection(
                        title: '📋 Plan Information',
                        icon: Icons.workspace_premium,
                        color: const Color(0xFF8B5CF6),
                        children: [
                          _buildDetailRow('Plan Name', subscription['plan_name'] ?? 'N/A'),
                          _buildDetailRow('Plan Type', subscription['plan_type'] ?? 'N/A'),
                          _buildDetailRow('Duration', '${subscription['duration_days'] ?? 0} Days'),
                          _buildDetailRow('Max Dishes', '${subscription['max_dishes'] ?? 0}'),
                          _buildDetailRow('Total Price', '\$${subscription['total_price']?.toString() ?? '0.00'}'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Meal Preferences Section
                      _buildDetailSection(
                        title: '🍽️ Meal Preferences',
                        icon: Icons.restaurant_menu,
                        color: const Color(0xFF22C55E),
                        children: [
                          _buildDetailRow('Meal Type', (subscription['meal_type'] ?? 'veg').toUpperCase()),
                          _buildDetailRow('Bread Type', (subscription['bread_type'] ?? 'naan').toUpperCase()),
                          _buildDetailRow('Spice Level', (subscription['spice_level'] ?? 'mild').toUpperCase()),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Delivery Details Section
                      _buildDetailSection(
                        title: '🚚 Delivery Details',
                        icon: Icons.delivery_dining,
                        color: const Color(0xFFF59E0B),
                        children: [
                          _buildDetailRow('Delivery Option', (subscription['delivery_option'] ?? 'delivery').toUpperCase()),
                          _buildDetailRow('Delivery Date', subscription['delivery_date'] ?? 'N/A'),
                          _buildDetailRow('Time Slot', subscription['delivery_time_slot'] ?? 'N/A'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Delivery Address Section
                      if (subscription['delivery_address'] != null && subscription['delivery_address'].toString().isNotEmpty)
                        _buildDetailSection(
                          title: '📍 Delivery Address',
                          icon: Icons.location_on,
                          color: const Color(0xFFEF4444),
                          children: [
                            _buildDetailRow('Address', subscription['delivery_address'] ?? 'N/A'),
                            _buildDetailRow('City', subscription['delivery_city'] ?? 'N/A'),
                            _buildDetailRow('Postal Code', subscription['delivery_postal_code'] ?? 'N/A'),
                            _buildDetailRow('Phone', subscription['delivery_phone'] ?? 'N/A'),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // Status & Progress Section
                      _buildDetailSection(
                        title: '📊 Status & Progress',
                        icon: Icons.analytics,
                        color: const Color(0xFF3B82F6),
                        children: [
                          _buildDetailRow('Status', (subscription['status'] ?? 'pending').toUpperCase()),
                          _buildDetailRow('Progress', '${subscription['delivered_count'] ?? 0} / ${subscription['total_dishes'] ?? 0}'),
                          _buildDetailRow('Days Remaining', '${subscription['days_remaining'] ?? 0}'),
                          _buildDetailRow('Order Count', '${subscription['order_count'] ?? 0}'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Special Instructions Section
                      if (subscription['special_instructions'] != null &&
                          subscription['special_instructions'].toString().isNotEmpty)
                        _buildDetailSection(
                          title: '📝 Special Instructions',
                          icon: Icons.note,
                          color: const Color(0xFFF97316),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.format_quote,
                                    color: Colors.orange.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subscription['special_instructions'] ?? 'No special instructions',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF1A202C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // Dishes Section
                      if (subscription['selected_dishes'] != null)
                        _buildDetailSection(
                          title: '🍽️ Selected Dishes',
                          icon: Icons.food_bank,
                          color: const Color(0xFFEC4899),
                          children: [
                            _buildDishesList(subscription),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // Dates Section
                      _buildDetailSection(
                        title: '📅 Dates',
                        icon: Icons.calendar_today,
                        color: const Color(0xFF14B8A6),
                        children: [
                          _buildDetailRow('Start Date', subscription['start_date'] ?? 'N/A'),
                          _buildDetailRow('End Date', subscription['end_date'] ?? 'N/A'),
                          _buildDetailRow('Created At', subscription['created_at'] ?? 'N/A'),
                          _buildDetailRow('Updated At', subscription['updated_at'] ?? 'N/A'),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ==============================================
// DETAIL SECTION WIDGET
// ==============================================
  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

// ==============================================
// DETAIL ROW WIDGET
// ==============================================
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ==============================================
// DISHES LIST WIDGET
// ==============================================
  Widget _buildDishesList(Map<String, dynamic> subscription) {
    List<String> selectedDishes = [];
    if (subscription['selected_dishes'] != null) {
      if (subscription['selected_dishes'] is List) {
        selectedDishes = List<String>.from(subscription['selected_dishes']);
      } else if (subscription['selected_dishes'] is String) {
        try {
          final decoded = jsonDecode(subscription['selected_dishes']);
          if (decoded is List) {
            selectedDishes = List<String>.from(decoded);
          }
        } catch (e) {
          final str = subscription['selected_dishes'] as String;
          if (str.contains(',')) {
            selectedDishes = str.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          } else if (str.isNotEmpty) {
            selectedDishes = [str];
          }
        }
      }
    }

    if (selectedDishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'No dishes selected',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
      );
    }

    final deliveredInstances = List<String>.from(subscription['delivered_dish_instances'] ?? []);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selectedDishes.map((dish) {
        final dishInstances = deliveredInstances.where((d) => d.startsWith(dish + '|')).toList();
        final isDelivered = dishInstances.isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDelivered ? Colors.green.shade50 : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDelivered ? Colors.green.shade300 : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dish,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDelivered ? Colors.green.shade700 : const Color(0xFF1A202C),
                ),
              ),
              if (isDelivered) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${dishInstances.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 12,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildDeleteRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            ':',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteSubscription(int subscriptionId) async {
    setState(() => _isDeleting = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'action': 'delete_user_subscription',
          'subscription_id': subscriptionId.toString(),
        },
      );

      var data = json.decode(response.body);
      setState(() => _isDeleting = false);

      if (data['status'] == 'success') {
        setState(() {
          _subscriptions.removeWhere((s) => s['id'] == subscriptionId);
        });
        _showSnackBar('✅ Subscription deleted!', Colors.green);
      } else {
        _showSnackBar(data['message'] ?? 'Failed to delete', Colors.red);
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }
}