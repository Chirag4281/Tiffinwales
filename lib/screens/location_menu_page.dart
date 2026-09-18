import 'dart:typed_data' as typed_data;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import 'meal_plan_order_screen.dart';

class LocationMenuPage extends StatefulWidget {
  final String locationName;
  final List<Map<String, dynamic>> menuItems;
  final Function(Map<String, dynamic>) onAddToCart;
  final String email;      // ✅ NEW
  final String username;

  const LocationMenuPage({
    super.key,
    required this.locationName,
    required this.menuItems,
    required this.email,      // ✅ NEW
    required this.username,
    required this.onAddToCart,
  });

  @override
  State<LocationMenuPage> createState() => _LocationMenuPageState();
}

class _LocationMenuPageState extends State<LocationMenuPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isSearching = false;
  late AnimationController _animationController;

  // ==============================================
  // INSTANCE LEVEL CACHE (NOT STATIC) - FIXED
  // ==============================================
  final Map<String, typed_data.Uint8List> _imageCache = {};
  final Map<String, String> _imageUrlCache = {};
  bool _imagesPreCached = false;

  // ==============================================
  // FILTER STATE
  // ==============================================
  String _selectedCategory = 'All';
  List<String> _categories = [];
  final ScrollController _categoryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.menuItems;
    _extractCategories();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();
    _searchController.addListener(_filterMenuItems);

    // ==============================================
    // PRE-CACHE IMAGES - USING INSTANCE CACHE
    // ==============================================
    _preCacheImages();
  }

  // ==============================================
  // EXTRACT UNIQUE CATEGORIES
  // ==============================================
  void _extractCategories() {
    Set<String> categorySet = {};
    for (var item in widget.menuItems) {
      String category = item['category'] ?? 'Main Course';
      categorySet.add(category);
    }
    _categories = ['All', ...categorySet.toList()];
  }

  // ==============================================
  // APPLY ALL FILTERS
  // ==============================================
  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredItems = widget.menuItems.where((item) {
        // Category filter
        if (_selectedCategory != 'All') {
          final itemCategory = item['category'] ?? 'Main Course';
          if (itemCategory != _selectedCategory) return false;
        }

        // Search filter
        if (query.isNotEmpty) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          final description = (item['description'] ?? '').toString().toLowerCase();
          if (!name.contains(query) && !description.contains(query)) return false;
        }

        return true;
      }).toList();

      _isSearching = query.isNotEmpty || _selectedCategory != 'All';
    });
  }

  void _filterMenuItems() {
    _applyFilters();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  // ==============================================
  // PRE-CACHE IMAGES - INSTANCE LEVEL
  // ==============================================
  void _preCacheImages() {
    for (var item in widget.menuItems) {
      final imageUrl = item['image_url'] ?? '';
      final imageBase64 = item['image_base64'] ?? '';
      final cacheKey = 'menu_${item['id'] ?? item['name']}';

      if (imageUrl.isNotEmpty && !_imageUrlCache.containsKey(cacheKey)) {
        _imageUrlCache[cacheKey] = imageUrl;
      }

      if (imageUrl.isEmpty &&
          imageBase64.isNotEmpty &&
          !imageBase64.startsWith('SVG:') &&
          !_imageCache.containsKey(cacheKey)) {
        try {
          final bytes = base64Decode(imageBase64);
          String content = utf8.decode(bytes, allowMalformed: true);
          if (!content.contains('<svg') && !content.contains('<?xml')) {
            _imageCache[cacheKey] = bytes;
          }
        } catch (e) {
          // Ignore
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMenuItems);
    _searchController.dispose();
    _animationController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      final cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  String _formatRatingCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  bool _isSvgData(typed_data.Uint8List bytes) {
    try {
      String content = utf8.decode(bytes);
      return content.contains('<svg') || content.contains('<?xml');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);   // Logo orange
    const Color lightPurple = Color(0xFFFFF3E8);     // Warm orange tint
    const Color darkColor = Color(0xFF1C1C1E);       // Logo charcoal
    const Color lightBg = Color(0xFFFAFAFA);         // Clean background

    // Group menu items by category
    Map<String, List<Map<String, dynamic>>> groupedMenu = {};
    for (var item in _filteredItems) {
      String category = item['category'] ?? 'Main Course';
      if (!groupedMenu.containsKey(category)) {
        groupedMenu[category] = [];
      }
      groupedMenu[category]!.add(item);
    }

    if (groupedMenu.isEmpty && _filteredItems.isNotEmpty) {
      groupedMenu['Menu Items'] = _filteredItems;
    }

    return Scaffold(
      backgroundColor: lightBg,
      body: CustomScrollView(
        slivers: [
          // Modern Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "🍽️ Our Menu",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: darkColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Explore delicious dishes from ${widget.locationName}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ==============================================
                  // SEARCH BAR
                  // ==============================================
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search menu items...",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (_isSearching) ...[
                    const SizedBox(height: 8),
                    Text(
                      "${_filteredItems.length} results found",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // ==============================================
                  // SCROLLABLE CATEGORY FILTER (Like Zomato/Swiggy)
                  // ==============================================
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      controller: _categoryScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () => _selectCategory(category),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                category,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : darkColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Menu Items
          if (widget.menuItems.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyState(primaryColor),
            )
          else if (_filteredItems.isEmpty && _isSearching)
            SliverToBoxAdapter(
              child: _buildNoResultsState(),
            )
          else if (_filteredItems.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(primaryColor),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final entries = groupedMenu.entries.toList();
                      if (index >= entries.length * 2) return null;

                      final entryIndex = index ~/ 2;
                      final isHeader = index.isEven;

                      if (isHeader) {
                        return _buildCategoryHeader(entries[entryIndex].key, darkColor);
                      } else {
                        final items = entries[entryIndex].value;
                        return Column(
                          children: items.asMap().entries.map((entry) =>
                              _buildMenuItemCard(
                                entry.value,
                                primaryColor,
                                lightPurple,
                                entry.key,
                              )).toList(),
                        );
                      }
                    },
                    childCount: groupedMenu.entries.length * 2,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ==============================================
  // BUILD METHODS
  // ==============================================

  Widget _buildCategoryHeader(String category, Color darkColor) {
    final itemCount = _filteredItems
        .where((item) => (item['category'] ?? 'Main Course') == category)
        .length;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),   // Logo orange bar
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            category,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkColor,
            ),
          ),
          const Spacer(),
          Text(
            '$itemCount items',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
  int _parseDishCountFromName(String itemName) {
    if (itemName.isEmpty) return 3;
    final lower = itemName.toLowerCase();
    final match = RegExp(r'(\d+)\s*[-\s]?\s*days?').firstMatch(lower);
    if (match != null) {
      final parsed = int.tryParse(match.group(1) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    if (lower.contains('weekly')) return 7;
    if (lower.contains('monthly')) return 30;
    if (lower.contains('daily')) return 1;
    return 3;
  }
  // ==============================================
  // MENU ITEM CARD - USING CACHED IMAGES
  // ==============================================
  Widget _buildMenuItemCard(
      Map<String, dynamic> item,
      Color primaryColor,
      Color lightPurple,
      int index,
      ) {
    final String imageBase64 = item['image_base64'] ?? '';
    final String imageUrl = item['image_url'] ?? '';
    final String name = item['name'] ?? 'Unknown';
    final double price = _parsePrice(item['price']);
    final String description = item['description'] ?? '';
    final String? category = item['category'];

    final double? rating = () {
      final val = item['rating'];
      if (val == null) return null;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }();

    final bool isVeg = item['is_veg'] ?? true;
    final int? totalRatings = () {
      final val = item['total_ratings'];
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }();

    final String? discount = item['discount'];
    final bool popular = item['popular'] == true;
    final double? originalPrice = () {
      final val = item['original_price'];
      if (val == null) return null;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }();
    bool _isMealPlanItem(String itemName) {
      final lowerName = itemName.toLowerCase();
      return lowerName.contains('meal plan') ||
          lowerName.contains('meal-plan') ||
          RegExp(r'\d+\s*days?\s*meal').hasMatch(lowerName);
    }
    final cacheKey = 'menu_${item['id'] ?? name}';

    // =============================================
    // GET FROM INSTANCE CACHE
    // =============================================
    typed_data.Uint8List? cachedImage = _imageCache[cacheKey];
    bool useNetworkImage = _imageUrlCache.containsKey(cacheKey);

    return FadeTransition(
      opacity: _animationController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              0.0,
              0.5 + (index * 0.015),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade50,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Padding(
                padding: const EdgeInsets.all(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.08),
                            primaryColor.withOpacity(0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: lightPurple,
                          child: _buildCachedImageWidget(
                            cachedImage: cachedImage,
                            useNetworkImage: useNetworkImage,
                            imageUrl: imageUrl,
                            name: name,
                            primaryColor: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    // Veg Badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isVeg ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVeg ? Icons.circle : Icons.square,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                      ),
                    ),
                    // Discount Badge
                    if (discount != null && discount.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF6B6B),
                                const Color(0xFFFF3366),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            discount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Content Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Rating Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1C1E),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rating != null && rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.green,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if (totalRatings != null) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '(${_formatRatingCount(totalRatings)})',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Category Chip
                      if (category != null && category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Description
                      Text(
                        description.isNotEmpty ? description : 'Delicious dish',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Price & Add Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${price.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              if (originalPrice != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '\$${originalPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey[400],
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Add Button
                          GestureDetector(
                            onTap: () {
                              if (_isMealPlanItem(item['name'] ?? '')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MealPlanOrderScreen(
                                      locationName: widget.locationName,
                                      userEmail: widget.email, // Make sure this is passed
                                      username: widget.username,   // Make sure this is passed
                                      menuItem: item,
                                      requiredDishCount: _parseDishCountFromName(name), // ✅
                                      onAddToCart: widget.onAddToCart,
                                    ),
                                  ),
                                );
                              } else {
                                widget.onAddToCart(item);
                              }
                            },                            child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: primaryColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Add",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                        ],
                      ),
                      // Popular tag
                      if (popular)
                        Padding(
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.whatshot_rounded,
                                size: 12,
                                color: const Color(0xFFFF6B6B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Popular',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF6B6B),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
  // CACHED IMAGE WIDGET
  // ==============================================
  Widget _buildCachedImageWidget({
    required typed_data.Uint8List? cachedImage,
    required bool useNetworkImage,
    required String imageUrl,
    required String name,
    required Color primaryColor,
  }) {
    // =============================================
    // PRIORITY 1: Network image from URL
    // =============================================
    if (useNetworkImage && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade50,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (cachedImage != null) {
            return Image.memory(
              cachedImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildCircularFallback(name, primaryColor);
              },
            );
          }
          return _buildCircularFallback(name, primaryColor);
        },
      );
    }

    // =============================================
    // PRIORITY 2: Base64 image from cache
    // =============================================
    if (cachedImage != null) {
      return Image.memory(
        cachedImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildCircularFallback(name, primaryColor);
        },
      );
    }

    // =============================================
    // PRIORITY 3: Placeholder fallback
    // =============================================
    return _buildCircularFallback(name, primaryColor);
  }

  // ==============================================
  // CIRCULAR FALLBACK IMAGE
  // ==============================================
  Widget _buildCircularFallback(String name, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.08),
            primaryColor.withOpacity(0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: primaryColor.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu_outlined,
                size: 50,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No Menu Items Available",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Check back later for delicious dishes",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "No results found",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try searching for something else",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}