import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffinwales/screens/login_screen.dart';
import 'package:tiffinwales/screens/manager/pending_orders_dialog.dart';
import 'package:tiffinwales/theme/app_theme.dart';
import 'manager_analytics_tab.dart';
import 'manager_help_support_tab.dart';
import 'manager_menu_tab.dart';
import 'manager_orders_tab.dart';
import 'manager_subscriptions_tab.dart';
import 'manager_users_tab.dart';
import 'manager_promotions_tab.dart';

// ==============================================
// MODERN MANAGER SCREEN WITH ELEGANT DRAWER
// ==============================================

class ManagerScreen extends StatefulWidget {
  final String locationName;
  final String email;
  final int initialTabIndex;
  const ManagerScreen({
    super.key,
    required this.locationName,
    required this.email,
    this.initialTabIndex = 0,
  });

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;


  // Navigation items with enhanced styling
  final List<Map<String, dynamic>> _navItems = [
    {
      'icon': Icons.dashboard_rounded,
      'label': 'Dashboard',
      'color': const Color(0xFFF97316),  // Tiffin Wales primary orange
      'bgColor': const Color(0xFFF97316).withOpacity(0.15),
    },
    {
      'icon': Icons.restaurant_menu_rounded,
      'label': 'Menu',
      'color': const Color(0xFFEA580C),  // Deep orange
      'bgColor': const Color(0xFFEA580C).withOpacity(0.15),
    },
    {
      'icon': Icons.subscriptions_rounded,
      'label': 'Subscriptions',
      'color': const Color(0xFFFB923C),  // Light orange
      'bgColor': const Color(0xFFFB923C).withOpacity(0.15),
    },
    {
      'icon': Icons.receipt_long_rounded,
      'label': 'Orders',
      'color': const Color(0xFFF59E0B),  // Warm amber
      'bgColor': const Color(0xFFF59E0B).withOpacity(0.15),
    },
    {
      'icon': Icons.people_rounded,
      'label': 'Users',
      'color': const Color(0xFFD97706),  // Dark amber
      'bgColor': const Color(0xFFD97706).withOpacity(0.15),
    },
    {
      'icon': Icons.campaign_rounded,
      'label': 'Promotions',
      'color': const Color(0xFFC2410C),  // Burnt orange
      'bgColor': const Color(0xFFC2410C).withOpacity(0.15),
    },
    {
      'icon': Icons.support_agent_rounded,
      'label': 'Help & Support',
      'color': const Color(0xFF0EA5E9),
      'bgColor': const Color(0xFF0EA5E9).withOpacity(0.15),
    },
  ];

  final List<Widget> _tabs = [];
  void _showPendingOrdersDialog() {
    // Wait for the widget to build completely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PendingOrdersDialog(
            locationName: widget.locationName,
            email: widget.email,
            onNavigateToOrders: () {
              // Navigate to Orders tab (index 3)
              if (mounted) {
                // Close the drawer if open
                if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
                // Change the tab
                setState(() {
                  _selectedIndex = 3; // Orders tab index
                });
              }
            },
          );
        },
      );
    });
  }
  @override
  void initState() {
    super.initState();
    _initializeTabs();
    _selectedIndex = widget.initialTabIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPendingOrdersDialog();
    });
  }

  void _initializeTabs() {
    _tabs.clear();
    _tabs.addAll([
      ManagerAnalyticsTab(
        locationName: widget.locationName,
        email: widget.email,
      ),
      ManagerMenuTab(locationName: widget.locationName),
      ManagerSubscriptionsTab(
        locationName: widget.locationName,
        email: widget.email,
      ),
      ManagerOrdersTab(
        locationName: widget.locationName,
        email: widget.email,
      ),
      ManagerUsersTab(
        locationName: widget.locationName,
        email: widget.email,
      ),
      ManagerPromotionsTab(
        locationName: widget.locationName,
        email: widget.email,
      ),
      ManagerHelpSupportTab(               // ← NEW
        locationName: widget.locationName,
        email: widget.email,
      ),
    ]);
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 14),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.remove('user_username');
      await prefs.remove('user_location');
      await prefs.remove('user_role');
      await prefs.remove('user_user_type');
      await prefs.setBool('is_logged_in', false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  void _onTabChanged(int index) {
    if (_selectedIndex != index) {
      _animationController.reset();
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward();
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);
    const Color lightBg = Color(0xFFFAFAFA);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: lightBg,
      drawer: _buildElegantDrawer(primaryColor, darkColor),
      body: SafeArea(
        child: Column(
          children: [
            // ==============================================
            // ELEGANT HEADER
            // ==============================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF97316),
                    Color(0xFFEA580C),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Menu Button
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Store Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manager Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.locationName,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
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

            // ==============================================
            // SECTION TITLE
            // ==============================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _navItems[_selectedIndex]['color'] as Color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _navItems[_selectedIndex]['label'],
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_navItems[_selectedIndex]['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: _navItems[_selectedIndex]['color'],
                          size: 8,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedIndex + 1}/${_navItems.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==============================================
            // CONTENT WITH ANIMATION
            // ==============================================
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _tabs,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // ELEGANT MODERN DRAWER
  // ==============================================
  Widget _buildElegantDrawer(Color primaryColor, Color darkColor) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ==============================================
            // DRAWER HEADER - Premium
            // ==============================================
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF97316),
                    Color(0xFFEA580C),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Icon with glow
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Manager Panel',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.locationName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Email chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.email_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.email,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ==============================================
            // NAVIGATION ITEMS - Modern Icons
            // ==============================================
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = _selectedIndex == index;
                  final color = item['color'] as Color;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: color.withOpacity(0.2), width: 1.5)
                          : null,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.15) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: color.withOpacity(0.3), width: 1)
                              : null,
                        ),
                        child: Icon(
                          item['icon'],
                          color: isSelected ? color : Colors.grey[500],
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item['label'],
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? color : Colors.grey[700],
                          letterSpacing: 0.2,
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      )
                          : null,
                      onTap: () => _onTabChanged(index),
                    ),
                  );
                },
              ),
            ),

            // ==============================================
            // LOGOUT BUTTON - Elegant
            // ==============================================
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                      letterSpacing: 0.2,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Exit',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  onTap: _logout,
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}