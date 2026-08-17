import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LocationScreen extends StatefulWidget {
  final String locationName;

  const LocationScreen({
    super.key,
    required this.locationName,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLoadingOrders = false;

  // API URLs
  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';
  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';

  // Featured dishes for slider
  List<Map<String, dynamic>> _featuredDishes = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  // Load menu items for this location using location_name
  Future<void> _loadMenuItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'get_menus';
      request.fields['location_name'] = widget.locationName; // Using location_name

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        setState(() {
          _menuItems = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          _isLoading = false;

          // Populate featured dishes from menu items (first 3 items)
          _featuredDishes = _menuItems.take(3).map((item) {
            return {
              "name": item['name'] ?? 'Special Dish',
              "desc": item['description'] ?? 'Freshly prepared',
              "price": item['price']?.toString() ?? '\$0.00',
            };
          }).toList();

          // If no menu items, add default featured items
          if (_featuredDishes.isEmpty) {
            _featuredDishes = [
              {"name": "Chef's Special", "desc": "Authentic Cuisine", "price": "\$12.99"},
              {"name": "Flavorful Delight", "desc": "Freshly prepared daily", "price": "\$14.99"},
              {"name": "Signature Dish", "desc": "Best of ${widget.locationName}", "price": "\$16.99"},
            ];
          }
        });
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to load menu';
          _isLoading = false;
        });
      }
    } on http.ClientException {
      setState(() {
        _errorMessage = 'Network error. Please check your internet connection.';
        _isLoading = false;
      });
    } on FormatException {
      setState(() {
        _errorMessage = 'Invalid response from server.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Load orders for this location using location_name
  Future<void> _loadOrders() async {
    setState(() {
      _isLoadingOrders = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['location_name'] = widget.locationName; // Using location_name

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await streamedResponse.stream.bytesToString();
      var responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          _isLoadingOrders = false;
        });
      } else {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingOrders = false;
      });
    }
  }

  // Navigation pages
  List<Widget> get _pages => [
    LocationHomeTab(
      locationName: widget.locationName,
      featuredDishes: _featuredDishes,
      menuItems: _menuItems,
    ),
    LocationMenuPage(
      locationName: widget.locationName,
      menuItems: _menuItems,
    ),
    LocationOrdersPage(
      locationName: widget.locationName,
      orders: _orders,
      isLoading: _isLoadingOrders,
      onRefresh: _loadOrders,
    ),
    LocationProfilePage(
      locationName: widget.locationName,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // Glass Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFE8F5E9),
                      Colors.white,
                      const Color(0xFFF1F8E9),
                    ],
                  ),
                ),
              ),
            ),
            // Floating Blob
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB3D335).withOpacity(0.1),
                ),
              ),
            ),

            // Content Pages
            _isLoading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFB3D335),
                  ),
                  SizedBox(height: 16),
                  Text('Loading menu...'),
                ],
              ),
            )
                : _errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadMenuItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGreen,
                      foregroundColor: darkGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : _pages[_selectedIndex],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF2E4A00),
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          showUnselectedLabels: true,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
              // Load orders when switching to orders tab
              if (index == 2 && _orders.isEmpty) {
                _loadOrders();
              }
            });
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "Menu"),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Orders"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// LOCATION HOME TAB
// ==============================================
class LocationHomeTab extends StatefulWidget {
  final String locationName;
  final List<Map<String, dynamic>> featuredDishes;
  final List<Map<String, dynamic>> menuItems;

  const LocationHomeTab({
    super.key,
    required this.locationName,
    required this.featuredDishes,
    required this.menuItems,
  });

  @override
  State<LocationHomeTab> createState() => _LocationHomeTabState();
}

class _LocationHomeTabState extends State<LocationHomeTab> {
  final PageController _sliderController = PageController();
  int _currentSliderIndex = 0;
  late Timer _sliderTimer;

  @override
  void initState() {
    super.initState();
    _sliderTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_sliderController.hasClients) {
        int next = (_currentSliderIndex + 1) % widget.featuredDishes.length;
        _sliderController.animateToPage(
          next,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _sliderTimer.cancel();
    _sliderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.locationName,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: darkGreen,
                      ),
                    ),
                    Text(
                      "Authentic Cuisine",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: darkGreen, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Change",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, color: brandGreen, size: 30),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Free Delivery",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: darkGreen,
                      ),
                    ),
                    Text(
                      "On orders above \$35",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Featured Dishes",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkGreen,
            ),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 200,
          child: widget.featuredDishes.isEmpty
              ? const Center(
            child: Text('No featured dishes available'),
          )
              : PageView.builder(
            controller: _sliderController,
            onPageChanged: (index) {
              setState(() {
                _currentSliderIndex = index;
              });
            },
            itemCount: widget.featuredDishes.length,
            itemBuilder: (context, index) {
              final dish = widget.featuredDishes[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withOpacity(0.4),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: brandGreen.withOpacity(0.2),
                        child: Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 60,
                            color: brandGreen.withOpacity(0.5),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dish['name'] ?? 'Special Dish',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      dish['desc'] ?? 'Delicious dish',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      dish['price'] ?? '\$0.00',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: brandGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Text(
                                  "Order Now",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.featuredDishes.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentSliderIndex == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentSliderIndex == index ? brandGreen : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Today's Specials",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkGreen,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            children: widget.menuItems.take(3).map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: brandGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          item['name']?.substring(0, 1).toUpperCase() ?? '?',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: brandGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item['name'] ?? 'Unknown Item',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '\$${item['price'] ?? '0.00'}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: brandGreen,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }
}

// ==============================================
// LOCATION MENU PAGE
// ==============================================
class LocationMenuPage extends StatelessWidget {
  final String locationName;
  final List<Map<String, dynamic>> menuItems;

  const LocationMenuPage({
    super.key,
    required this.locationName,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    // Group menu items by category
    Map<String, List<Map<String, dynamic>>> groupedMenu = {};
    for (var item in menuItems) {
      String category = item['category'] ?? 'Main Course';
      if (!groupedMenu.containsKey(category)) {
        groupedMenu[category] = [];
      }
      groupedMenu[category]!.add(item);
    }

    // If no categories, create a default one
    if (groupedMenu.isEmpty) {
      groupedMenu['Menu Items'] = menuItems;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Our Menu",
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: darkGreen,
            ),
          ),
          Text(
            "Authentic Cuisine from $locationName",
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          if (menuItems.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No menu items available",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else
            ...groupedMenu.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...entry.value.map((item) => _buildMenuItem(
                    name: item['name'] ?? 'Unknown',
                    desc: item['description'] ?? 'Delicious dish',
                    price: '\$${item['price'] ?? '0.00'}',
                    brandGreen: brandGreen,
                  )),
                  const SizedBox(height: 20),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String name,
    required String desc,
    required String price,
    required Color brandGreen,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: brandGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: brandGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: brandGreen,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E4A00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Add",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E4A00),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==============================================
// LOCATION ORDERS PAGE
// ==============================================
class LocationOrdersPage extends StatelessWidget {
  final String locationName;
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final VoidCallback onRefresh;

  const LocationOrdersPage({
    super.key,
    required this.locationName,
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Orders",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: darkGreen,
              ),
            ),
            Text(
              "Orders from $locationName",
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    color: Color(0xFFB3D335),
                  ),
                ),
              )
            else if (orders.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No orders yet",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Your orders will appear here",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...orders.map((order) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Order #${order['id'] ?? 'N/A'}",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (order['order_status'] == 'completed' || order['order_status'] == 'delivered')
                                ? Colors.green.withOpacity(0.2)
                                : brandGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order['order_status']?.toUpperCase() ?? 'ACTIVE',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (order['order_status'] == 'completed' || order['order_status'] == 'delivered')
                                  ? Colors.green
                                  : darkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order['items'] ?? 'Order details',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${order['total'] ?? '0.00'}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: brandGreen,
                          ),
                        ),
                        Text(
                          order['created_at'] ?? 'Just now',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// LOCATION PROFILE PAGE
// ==============================================
class LocationProfilePage extends StatelessWidget {
  final String locationName;

  const LocationProfilePage({
    super.key,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF2E4A00);
    const Color brandGreen = Color(0xFFB3D335);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and Name
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandGreen.withOpacity(0.2),
                  border: Border.all(color: brandGreen, width: 2),
                ),
                child: const Icon(Icons.person, size: 40, color: darkGreen),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "John Doe",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: darkGreen,
                    ),
                  ),
                  Text(
                    "john.doe@email.com",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: brandGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      locationName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: darkGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 30),

          Text(
            "Account Settings",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 16),

          _buildProfileOption(Icons.person_outline, "Edit Profile"),
          _buildProfileOption(Icons.location_on_outlined, "Delivery Addresses"),
          _buildProfileOption(Icons.credit_card, "Payment Methods"),
          _buildProfileOption(Icons.notifications_outlined, "Notifications"),

          const SizedBox(height: 20),
          const Divider(color: Colors.grey),
          const SizedBox(height: 10),

          _buildProfileOption(Icons.help_outline, "Help & Support", isDanger: false),
          _buildProfileOption(Icons.logout, "Log Out", isDanger: true),
        ],
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, {bool isDanger = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDanger ? Colors.red : const Color(0xFF2E4A00)),
          const SizedBox(width: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: isDanger ? Colors.red : const Color(0xFF1B3B1B),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: isDanger ? Colors.red.withOpacity(0.5) : Colors.grey,
          ),
        ],
      ),
    );
  }
}