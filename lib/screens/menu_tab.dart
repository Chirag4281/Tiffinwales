import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MenuTab extends StatefulWidget {
  const MenuTab({super.key});

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _menus = [];
  List<Map<String, dynamic>> _locations = [];
  String? _selectedLocation;
  bool _isLoading = true;
  bool _isLoadingLocations = true;
  bool _isProcessing = false;
  String? _errorMessage;
  File? _selectedImage;
  String? _imageBase64;
  late AnimationController _animationController;

  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';
  final String locationApiUrl = 'https://quantorra.co/tiffinwales/Locations.php';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(locationApiUrl));
      request.fields['action'] = 'get_locations';

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        setState(() {
          _locations = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoadingLocations = false;
          if (_locations.isNotEmpty) {
            _selectedLocation = _locations[0]['name'];
            _loadMenus();
          }
        });
        _animationController.forward();
      } else {
        setState(() {
          _isLoadingLocations = false;
          _errorMessage = 'Failed to load locations';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocations = false;
        _errorMessage = 'Failed to load locations';
      });
    }
  }

  Future<void> _loadMenus() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'get_menus';
      request.fields['location_name'] = _selectedLocation!;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        setState(() {
          _menus = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load menus';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

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
        SnackBar(content: Text('Error picking image: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    const Color primaryColor = Color(0xFF6366F1);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  SnackBar _buildSuccessSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  SnackBar _buildErrorSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _addMenu() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String selectedCategory = 'Main Course';
    _selectedImage = null;
    _imageBase64 = null;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Text(
                  'Add Menu Item',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[400]),
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
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: nameController,
                    label: 'Item Name *',
                    hint: 'e.g., Butter Chicken',
                    icon: Icons.food_bank,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: descController,
                    label: 'Description',
                    hint: 'Describe the dish',
                    icon: Icons.description,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: priceController,
                    label: 'Price *',
                    hint: '0.00',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      prefixIcon: const Icon(Icons.category, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Starters', child: Text('Starters')),
                      DropdownMenuItem(value: 'Main Course', child: Text('Main Course')),
                      DropdownMenuItem(value: 'Breads', child: Text('Breads')),
                      DropdownMenuItem(value: 'Desserts', child: Text('Desserts')),
                      DropdownMenuItem(value: 'Beverages', child: Text('Beverages')),
                    ],
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
                onPressed: _isProcessing ? null : () async {
                  if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _saveMenu(
                      name: nameController.text,
                      description: descController.text,
                      price: double.parse(priceController.text),
                      category: selectedCategory,
                      imageBase64: _imageBase64,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      _buildErrorSnackBar('Please fill in all required fields'),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                child: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  'Add Item',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveMenu({
    required String name,
    required String description,
    required double price,
    required String category,
    String? imageBase64,
  }) async {
    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'add_menu';
      request.fields['location_name'] = _selectedLocation!;
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

      setState(() => _isProcessing = false);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar('Menu added successfully!'),
        );
        _loadMenus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(data['message'] ?? 'Failed to add menu'),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        _buildErrorSnackBar('Error: ${e.toString()}'),
      );
    }
  }

  Future<void> _editMenu(Map<String, dynamic> menu) async {
    final TextEditingController nameController = TextEditingController(text: menu['name'] ?? '');
    final TextEditingController descController = TextEditingController(text: menu['description'] ?? '');
    final TextEditingController priceController = TextEditingController(text: menu['price']?.toString() ?? '');
    String selectedCategory = menu['category'] ?? 'Main Course';
    _selectedImage = null;
    _imageBase64 = null;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue, Colors.lightBlueAccent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Text(
                  'Edit Menu Item',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                          : menu['image_base64'] != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(menu['image_base64']),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported, size: 50);
                          },
                        ),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to change image',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: nameController,
                    label: 'Item Name *',
                    hint: 'e.g., Butter Chicken',
                    icon: Icons.food_bank,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: descController,
                    label: 'Description',
                    hint: 'Describe the dish',
                    icon: Icons.description,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: priceController,
                    label: 'Price *',
                    hint: '0.00',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      prefixIcon: const Icon(Icons.category, color: Color(0xFF6366F1)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Starters', child: Text('Starters')),
                      DropdownMenuItem(value: 'Main Course', child: Text('Main Course')),
                      DropdownMenuItem(value: 'Breads', child: Text('Breads')),
                      DropdownMenuItem(value: 'Desserts', child: Text('Desserts')),
                      DropdownMenuItem(value: 'Beverages', child: Text('Beverages')),
                    ],
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
                onPressed: _isProcessing ? null : () async {
                  if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _updateMenu(
                      id: menu['id'] ?? 0,
                      name: nameController.text,
                      description: descController.text,
                      price: double.parse(priceController.text),
                      category: selectedCategory,
                      imageBase64: _imageBase64,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                child: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  'Update',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateMenu({
    required int id,
    required String name,
    required String description,
    required double price,
    required String category,
    String? imageBase64,
  }) async {
    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'update_menu';
      request.fields['menu_id'] = id.toString();
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

      setState(() => _isProcessing = false);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar('Menu updated successfully!'),
        );
        _loadMenus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(data['message'] ?? 'Failed to update menu'),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        _buildErrorSnackBar('Error: ${e.toString()}'),
      );
    }
  }

  Future<void> _deleteMenu(int id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red, Colors.redAccent],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Text(
              'Delete Menu Item',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this menu item?',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isProcessing = true);
              try {
                var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
                request.fields['action'] = 'delete_menu';
                request.fields['menu_id'] = id.toString();

                var response = await request.send();
                var responseBody = await response.stream.bytesToString();
                var data = json.decode(responseBody);

                setState(() => _isProcessing = false);

                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    _buildSuccessSnackBar('Menu deleted successfully!'),
                  );
                  _loadMenus();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    _buildErrorSnackBar(data['message'] ?? 'Failed to delete'),
                  );
                }
              } catch (e) {
                setState(() => _isProcessing = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  _buildErrorSnackBar('Error: ${e.toString()}'),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _getLocationDropdownItems() {
    return _locations.map<DropdownMenuItem<String>>((location) {
      return DropdownMenuItem<String>(
        value: location['name'] as String,
        child: Text(location['name'] ?? 'Unknown'),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _selectedLocation != null
          ? FloatingActionButton.extended(
        onPressed: _addMenu,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Item',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      )
          : null,
      body: Column(
        children: [
          // Location Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _isLoadingLocations
                ? const Center(child: CircularProgressIndicator())
                : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Select Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF6366F1)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: _getLocationDropdownItems(),
                onChanged: (value) {
                  setState(() {
                    _selectedLocation = value;
                    _loadMenus();
                  });
                },
              ),
            ),
          ),

          // Menu Count
          if (!_isLoading && _menus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_menus.length} Menu Items',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Menu List
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            )
                : _errorMessage != null
                ? _buildErrorState()
                : _menus.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadMenus,
              color: primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _menus.length,
                itemBuilder: (context, index) {
                  final menu = _menus[index];
                  return _buildMenuItemCard(menu, index);
                },
              ),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Menu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMenus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
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
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 50,
              color: const Color(0xFF6366F1).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Menu Items',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first item',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> menu, int index) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: menu['image_base64'] != null
                ? Image.memory(
              base64Decode(menu['image_base64']),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildInitialsAvatar(menu['name'] ?? '?', primaryColor);
              },
            )
                : _buildInitialsAvatar(menu['name'] ?? '?', primaryColor),
          ),
        ),
        title: Text(
          menu['name'] ?? 'Unknown',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: darkColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              menu['description'] ?? 'No description',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 8),
                Text(
                  '\$${menu['price']?.toString() ?? '0.00'}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.blue, size: 18),
              ),
              onPressed: () => _editMenu(menu),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              ),
              onPressed: () => _deleteMenu(menu['id'] ?? 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}