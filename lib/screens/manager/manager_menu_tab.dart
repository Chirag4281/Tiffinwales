import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' as typed_data;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ManagerMenuTab extends StatefulWidget {
  final String locationName;

  const ManagerMenuTab({super.key, required this.locationName});

  @override
  State<ManagerMenuTab> createState() => _ManagerMenuTabState();
}

class _ManagerMenuTabState extends State<ManagerMenuTab>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _menus = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  File? _selectedImage;
  String? _imageBase64;
  final ImagePicker _picker = ImagePicker();
  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';

  // ==============================================
  // IMAGE CACHE
  // ==============================================
  final Map<String, typed_data.Uint8List> _imageCache = {};
  final Map<String, String> _imageUrlCache = {};

  // ==============================================
  // FILTER STATE
  // ==============================================
  String _selectedCategory = 'All';
  List<String> _categories = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMenus = [];
  bool _isSearching = false;

  // ==============================================
  // ANIMATION
  // ==============================================
  late AnimationController _animationController;

  // ==============================================
  // CATEGORY LIST FOR DROPDOWN
  // ==============================================
  final List<String> _categoryList = [
    'Starters',
    'Main Course',
    'Breads',
    'Desserts',
    'Beverages',
  ];

  @override
  void initState() {
    super.initState();
    _loadMenus();
    _searchController.addListener(_filterMenus);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMenus);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==============================================
  // LOAD MENUS
  // ==============================================
  Future<void> _loadMenus() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'get_menus';
      request.fields['location_name'] = widget.locationName;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (!mounted) return;

      if (data['status'] == 'success') {
        final menus = List<Map<String, dynamic>>.from(data['data'] ?? []);

        // Extract categories
        Set<String> categorySet = {};
        for (var item in menus) {
          String category = item['category'] ?? 'Main Course';
          categorySet.add(category);
        }

        // Pre-cache images
        for (var item in menus) {
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

        // Single setState for all updates
        setState(() {
          _menus = menus;
          _filteredMenus = menus;
          _isLoading = false;
          _categories = ['All', ...categorySet.toList()];
        });

      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load menus';
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
  // EXTRACT CATEGORIES
  // ==============================================


  // ==============================================
  // APPLY FILTERS
  // ==============================================
  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredMenus = _menus.where((item) {
        if (_selectedCategory != 'All') {
          final itemCategory = item['category'] ?? 'Main Course';
          if (itemCategory != _selectedCategory) return false;
        }

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

  void _filterMenus() {
    _applyFilters();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  // ==============================================
  // PRE-CACHE IMAGES
  // ==============================================
  void _extractCategories() {
    // Check if widget is mounted
    if (!mounted) return;

    Set<String> categorySet = {};
    for (var item in _menus) {
      String category = item['category'] ?? 'Main Course';
      categorySet.add(category);
    }

    // Use setState to update the UI
    setState(() {
      _categories = ['All', ...categorySet.toList()];
    });
  }

  void _preCacheImages() {
    // Check if widget is mounted
    if (!mounted) return;

    for (var item in _menus) {
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

  // ==============================================
  // PICK IMAGE
  // ==============================================
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _imageBase64 = base64Encode(File(image.path).readAsBytesSync());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==============================================
  // ADD MENU
  // ==============================================
  Future<void> _addMenu() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String selectedCategory = 'Main Course';
    _selectedImage = null;
    _imageBase64 = null;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Color(0xFFF97316), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add Menu Item',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _pickImage();
                      setStateDialog(() {});
                    },
                    child: Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 50, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add image',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.food_bank_rounded),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description_rounded),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category_rounded),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: _categoryList.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _saveMenu(
                      nameController.text,
                      descController.text,
                      double.parse(priceController.text),
                      selectedCategory,
                      _imageBase64,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==============================================
  // SAVE MENU
  // ==============================================
  Future<void> _saveMenu(String name, String description, double price, String category, String? imageBase64) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'add_menu';
      request.fields['location_name'] = widget.locationName;
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['price'] = price.toString();
      request.fields['category'] = category;
      if (imageBase64 != null) {
        request.fields['image_base64'] = imageBase64;
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu added successfully!'), backgroundColor: Colors.green),
        );
        _loadMenus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to add menu'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }





  // ==============================================
  // PARSE PRICE
  // ==============================================
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

  // ==============================================
  // LONG PRESS DIALOG - NEW FEATURE ONLY
  // ==============================================
  void _showLongPressDialog(Map<String, dynamic> menu) {
    final String name = menu['name'] ?? 'Unknown';
    final String description = menu['description'] ?? 'No description';
    final double price = _parsePrice(menu['price']);
    final String category = menu['category'] ?? 'Main Course';
    final String imageBase64 = menu['image_base64'] ?? '';
    final String imageUrl = menu['image_url'] ?? '';
    final cacheKey = 'menu_${menu['id'] ?? name}';

    typed_data.Uint8List? cachedImage = _imageCache[cacheKey];
    bool useNetworkImage = _imageUrlCache.containsKey(cacheKey);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              // Image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xFFFFF3E8),
                    child: _buildDialogImage(
                      cachedImage: cachedImage,
                      useNetworkImage: useNetworkImage,
                      imageUrl: imageUrl,
                      imageBase64: imageBase64,
                      name: name,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF97316),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        const Spacer(),

                        const SizedBox(width: 8),
                        // Delete button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),

                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================
  // DIALOG IMAGE WIDGET
  // ==============================================
  Widget _buildDialogImage({
    required typed_data.Uint8List? cachedImage,
    required bool useNetworkImage,
    required String imageUrl,
    required String imageBase64,
    required String name,
  }) {
    if (useNetworkImage && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: const Color(0xFFF97316),
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
                return _buildDialogFallback(name);
              },
            );
          }
          if (imageBase64.isNotEmpty) {
            try {
              return Image.memory(
                base64Decode(imageBase64),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDialogFallback(name);
                },
              );
            } catch (e) {
              return _buildDialogFallback(name);
            }
          }
          return _buildDialogFallback(name);
        },
      );
    }

    if (cachedImage != null) {
      return Image.memory(
        cachedImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDialogFallback(name);
        },
      );
    }

    if (imageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDialogFallback(name);
          },
        );
      } catch (e) {
        return _buildDialogFallback(name);
      }
    }

    return _buildDialogFallback(name);
  }

  // ==============================================
  // DIALOG FALLBACK IMAGE
  // ==============================================
  Widget _buildDialogFallback(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF97316).withOpacity(0.08),
            const Color(0xFFF97316).withOpacity(0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF97316).withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  // ==============================================
  // BUILD - VISUALLY APPEALING CARDS
  // ==============================================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color lightPurple = Color(0xFFFFF3E8);
    const Color darkColor = Color(0xFF1C1C1E);
    const Color lightBg = Color(0xFFFAFAFA);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMenus,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No menu items yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first item',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightBg,

      body: Column(
        children: [
          // ==============================================
          // SEARCH BAR
          // ==============================================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
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
          ),
          if (_isSearching) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${_filteredMenus.length} results found",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
          // ==============================================
          // CATEGORY FILTER
          // ==============================================
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () => _selectCategory(category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade200,
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
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : darkColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // ==============================================
          // CLEAR FILTERS
          // ==============================================
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _searchController.clear();
                    });
                    _applyFilters();
                  },
                  child: Text(
                    'Clear Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          // ==============================================
          // MENU LIST - WITH LONG PRESS
          // ==============================================
          Expanded(
            child: _filteredMenus.isEmpty && _isSearching
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 50,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No items found',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _searchController.clear();
                      });
                      _applyFilters();
                    },
                    child: Text(
                      'Show all items',
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadMenus,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredMenus.length,
                itemBuilder: (context, index) {
                  final menu = _filteredMenus[index];
                  final String imageBase64 = menu['image_base64'] ?? '';
                  final String imageUrl = menu['image_url'] ?? '';
                  final String name = menu['name'] ?? 'Unknown';
                  final cacheKey = 'menu_${menu['id'] ?? name}';

                  typed_data.Uint8List? cachedImage = _imageCache[cacheKey];
                  bool useNetworkImage = _imageUrlCache.containsKey(cacheKey);

                  return GestureDetector(
                    onLongPress: () => _showLongPressDialog(menu),
                    child: FadeTransition(
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
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.grey.shade100,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // ==========================================
                              // IMAGE SECTION
                              // ==========================================
                              Padding(
                                padding: const EdgeInsets.all(12),
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
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.15),
                                            blurRadius: 16,
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
                                  ],
                                ),
                              ),
                              // ==========================================
                              // CONTENT SECTION
                              // ==========================================
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 2,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: darkColor,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        menu['description'] ?? 'No description',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: primaryColor.withOpacity(0.1),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              menu['category'] ?? 'Main Course',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.green.withOpacity(0.1),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '\$${_parsePrice(menu['price']).toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // ==========================================
                              // ACTION BUTTONS
                              // ==========================================
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,

                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}