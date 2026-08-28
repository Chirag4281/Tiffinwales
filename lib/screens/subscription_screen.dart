// lib/screens/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tiffinwales/screens/subscription_order_details_screen.dart';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';
import 'subscription_order_screen.dart';
import 'subscription_list_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final String locationName;
  final String userEmail;
  final String username;

  const SubscriptionScreen({
    super.key,
    required this.locationName,
    required this.userEmail,
    required this.username,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  List<UserSubscription> _activeSubscriptions = [];
  List<UserSubscription> _subscriptions = [];
  bool _isLoading = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _loadUserSubscriptions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserSubscriptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://quantorra.co/tiffinwales/SubscriptionManager.php'),
        body: {
          'action': 'get_user_subscriptions',
          'user_email': widget.userEmail.trim(),
          'location_name': widget.locationName.trim(),
        },
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var data = json.decode(response.body);

      if (data['status'] == 'success' && data['data'] != null) {
        final List<dynamic> subscriptionsData = data['data'];

        if (subscriptionsData.isNotEmpty) {
          final List<UserSubscription> parsedSubscriptions = [];

          for (var item in subscriptionsData) {
            final plan = SubscriptionPlan(
              id: item['plan_id'] as int? ?? 0,
              locationName: item['location_name']?.toString() ?? widget.locationName,
              planType: item['plan_type']?.toString() ?? '',
              planName: item['plan_name']?.toString() ?? 'Meal Plan',
              description: item['plan_description']?.toString() ?? '',
              price: double.tryParse(item['plan_price']?.toString() ?? '0') ?? 0,
              durationDays: int.tryParse(item['duration_days']?.toString() ?? '0') ?? 0,
              maxDishes: int.tryParse(item['max_dishes']?.toString() ?? '0') ?? 0,
            );

            final subscription = UserSubscription.fromJson(item, plan);
            parsedSubscriptions.add(subscription);
          }

          final Map<int, UserSubscription> uniqueMap = {};
          for (var sub in parsedSubscriptions) {
            if (!uniqueMap.containsKey(sub.id)) {
              uniqueMap[sub.id] = sub;
            }
          }

          _subscriptions = uniqueMap.values.toList();
          _subscriptions.sort((a, b) => b.startDate.compareTo(a.startDate));

          _activeSubscriptions = _subscriptions.where((sub) {
            return sub.status == 'active' ||
                (sub.status == 'pending' && sub.daysRemaining > 0);
          }).toList();

          for (int i = 0; i < _activeSubscriptions.length; i++) {
            if (_activeSubscriptions[i].status == 'pending') {
              final sub = _activeSubscriptions[i];
              _activeSubscriptions[i] = UserSubscription(
                id: sub.id,
                userEmail: sub.userEmail,
                locationName: sub.locationName,
                plan: sub.plan,
                mealType: sub.mealType,
                breadType: sub.breadType,
                spiceLevel: sub.spiceLevel,
                selectedDishes: sub.selectedDishes,
                totalPrice: sub.totalPrice,
                deliveryOption: sub.deliveryOption,
                deliveryDate: sub.deliveryDate,
                deliveryTimeSlot: sub.deliveryTimeSlot,
                specialInstructions: sub.specialInstructions,
                startDate: sub.startDate,
                endDate: sub.endDate,
                daysRemaining: sub.daysRemaining,
                status: 'active',
                orderCount: sub.orderCount,
              );
            }
          }

          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _isLoading = false;
        _activeSubscriptions = [];
        _subscriptions = [];
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
            ? _buildErrorState()
            : FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: _loadUserSubscriptions,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildPageHeader(primaryColor, darkColor),
                  const SizedBox(height: 16),

                  if (_activeSubscriptions.isNotEmpty)
                    _buildActiveSubscriptionsSection(primaryColor, darkColor)
                  else
                    _buildNoSubscriptionCard(primaryColor, darkColor),
                  const SizedBox(height: 16),

                  _buildStatsSection(primaryColor, darkColor),
                  const SizedBox(height: 16),

                  _buildHistorySection(primaryColor, darkColor),
                  const SizedBox(height: 16),

                  _buildExploreSection(primaryColor, darkColor),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // PAGE HEADER
  // ==============================================
  Widget _buildPageHeader(Color primaryColor, Color darkColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [

          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Subscriptions',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                ),
                Text(
                  '${_activeSubscriptions.length} active • ${_subscriptions.length} total',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadUserSubscriptions,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: Color(0xFF6366F1), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // LOADING STATE
  // ==============================================
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your subscriptions...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // ERROR STATE
  // ==============================================
  Widget _buildErrorState() {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red[300],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUserSubscriptions,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // ACTIVE SUBSCRIPTIONS SECTION
  // ==============================================
  Widget _buildActiveSubscriptionsSection(Color primaryColor, Color darkColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Active Plans (${_activeSubscriptions.length})',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._activeSubscriptions.map((subscription) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPremiumSubscriptionCard(subscription, primaryColor, darkColor),
          );
        }).toList(),
      ],
    );
  }

  // ==============================================
  // PREMIUM SUBSCRIPTION CARD - COMPLETE REDESIGN
  // ==============================================
  Widget _buildPremiumSubscriptionCard(UserSubscription subscription, Color primaryColor, Color darkColor) {
    final plan = subscription.plan;
    final totalDays = plan.durationDays;
    final usedDays = totalDays - subscription.daysRemaining;
    final double progress = totalDays > 0 ? usedDays / totalDays : 0.0;

    List<Color> gradientColors = [primaryColor, const Color(0xFF8B5CF6)];
    if (plan.planType == '3days') {
      gradientColors = [const Color(0xFF667EEA), const Color(0xFF764BA2)];
    } else if (plan.planType == '5days') {
      gradientColors = [const Color(0xFFF093FB), const Color(0xFFF5576C)];
    } else if (plan.planType == '7days') {
      gradientColors = [const Color(0xFF4FACFE), const Color(0xFF00F2FE)];
    } else if (plan.planType == '15days') {
      gradientColors = [const Color(0xFF43E97B), const Color(0xFF38F9D7)];
    } else if (plan.planType == '30days') {
      gradientColors = [const Color(0xFFFA709A), const Color(0xFFFEE140)];
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(
          color: gradientColors[0].withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
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
                    child: Icon(plan.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${plan.durationDays} Days • ${plan.maxDishes} Dishes',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${subscription.daysRemaining}d',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status and Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% Complete',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(gradientColors[0]),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Info Grid
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.restaurant,
                        label: '${subscription.selectedDishes.length} Dishes',
                        color: gradientColors[0],
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: Icons.attach_money,
                        label: subscription.formattedPrice,
                        color: gradientColors[1],
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: _formatDate(subscription.endDate),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubscriptionOrderDetailsScreen(
                                  subscription: subscription,
                                  userEmail: widget.userEmail,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gradientColors[0],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'View Details',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showCancelDialog(subscription),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.withOpacity(0.5), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.red,
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
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // NO SUBSCRIPTION CARD
  // ==============================================
  Widget _buildNoSubscriptionCard(Color primaryColor, Color darkColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF5F3FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.subscriptions_rounded,
              color: primaryColor,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Active Subscription',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Subscribe to a meal plan and enjoy delicious\nfood delivered to your doorstep.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionListScreen(
                    locationName: widget.locationName,
                    userEmail: widget.userEmail,
                    username: widget.username,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.3),
            ),
            child: Text(
              'Browse Plans',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // STATS SECTION
  // ==============================================
  Widget _buildStatsSection(Color primaryColor, Color darkColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total Orders',
              _subscriptions.fold<int>(0, (sum, sub) => sum + sub.orderCount).toString(),
              Icons.receipt_long,
              primaryColor,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey[200],
          ),
          Expanded(
            child: _buildStatItem(
              'Total Spend',
              '\$${_subscriptions.fold<double>(0, (sum, sub) => sum + sub.totalPrice).toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey[200],
          ),
          Expanded(
            child: _buildStatItem(
              'Active Plans',
              _activeSubscriptions.length.toString(),
              Icons.check_circle,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // ==============================================
  // HISTORY SECTION
  // ==============================================
  Widget _buildHistorySection(Color primaryColor, Color darkColor) {
    final pastSubscriptions = _subscriptions
        .where((s) => s.status != 'active' && s.status != 'pending')
        .toList();

    if (pastSubscriptions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.history, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Past Subscriptions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pastSubscriptions.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pastSubscriptions.length > 3 ? 3 : pastSubscriptions.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[100],
              height: 1,
            ),
            itemBuilder: (context, index) {
              final sub = pastSubscriptions[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sub.statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        sub.status == 'completed' ? Icons.check_circle : Icons.cancel,
                        color: sub.statusColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.plan.planName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: darkColor,
                            ),
                          ),
                          Text(
                            '${_formatDate(sub.startDate)} - ${_formatDate(sub.endDate)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          sub.formattedPrice,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: sub.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sub.statusDisplay.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: sub.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          if (pastSubscriptions.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('View all past subscriptions coming soon!'),
                      ),
                    );
                  },
                  child: Text(
                    'View All (${pastSubscriptions.length})',
                    style: GoogleFonts.poppins(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==============================================
  // EXPLORE SECTION
  // ==============================================
  Widget _buildExploreSection(Color primaryColor, Color darkColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.04),
            const Color(0xFF8B5CF6).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Explore More Plans',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Looking for something different? Check out our other subscription plans.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubscriptionListScreen(
                      locationName: widget.locationName,
                      userEmail: widget.userEmail,
                      username: widget.username,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.restaurant_menu),
              label: Text(
                'View All Plans',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // CANCEL DIALOG
  // ==============================================
  void _showCancelDialog(UserSubscription subscription) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cancel Subscription?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to cancel your ${subscription.plan.planName}? You will lose access to remaining days.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Keep It',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                          ),
                        );

                        try {
                          final response = await SubscriptionService.updateSubscriptionStatus(
                            subscriptionId: subscription.id,
                            status: 'cancelled',
                          );

                          if (mounted) {
                            Navigator.pop(context);
                          }

                          if (response['status'] == 'success') {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Subscription cancelled successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadUserSubscriptions();
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(response['message'] ?? 'Failed to cancel subscription'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
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
    );
  }

  // ==============================================
  // HELPER METHODS
  // ==============================================
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}