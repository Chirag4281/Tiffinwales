import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class MasterAdminScreen extends StatefulWidget {
  const MasterAdminScreen({super.key});

  @override
  State<MasterAdminScreen> createState() => _MasterAdminScreenState();
}

class _MasterAdminScreenState extends State<MasterAdminScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    darkGreen,
                    darkGreen.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Master Admin',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Manage Locations, Menu & Orders',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // In the header section, replace the IconButton for logout with:
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _showLogoutDialog,
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildTabButton('Locations', 0, Icons.location_on, brandGreen),
                  _buildTabButton('Menu', 1, Icons.restaurant_menu, brandGreen),
                  _buildTabButton('Orders', 2, Icons.receipt_long, brandGreen),
                ],
              ),
            ),

            // Content
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  LocationsTab(),
                  MenuTab(),
                  OrdersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _performLogout() {
    // Clear any session data if needed
    // For example, if you're using shared preferences:
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.clear();

    // Navigate to login screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }
  Widget _buildTabButton(String label, int index, IconData icon, Color brandGreen) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? brandGreen : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? brandGreen : Colors.grey[400],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? brandGreen : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================
// LOCATIONS TAB - With Manager Credentials
// ==============================================
class LocationsTab extends StatefulWidget {
  const LocationsTab({super.key});

  @override
  State<LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<LocationsTab> {
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  String? _errorMessage;

  final String apiUrl = 'https://quantorra.co/tiffinwales/Locations.php';

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'get_locations';

      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        setState(() {
          _locations = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load locations';
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

  Future<void> _addLocation() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3D335).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_location, color: Color(0xFFB3D335)),
                ),
                const SizedBox(width: 12),
                const Text('Add Location'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Location Name *',
                      hintText: 'e.g., Boston - North Indian',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Manager Email *',
                      hintText: 'manager@example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Manager Password *',
                      hintText: 'Enter password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      emailController.text.isNotEmpty &&
                      passwordController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _saveLocation(
                      nameController.text,
                      emailController.text,
                      passwordController.text,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB3D335),
                  foregroundColor: const Color(0xFF2E4A00),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveLocation(String name, String email, String password) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'add_location';
      request.fields['location_name'] = name;
      request.fields['manager_email'] = email;
      request.fields['manager_password'] = password;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location added successfully!'), backgroundColor: Colors.green),
        );
        _loadLocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to add location'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editLocation(Map<String, dynamic> location) async {
    final TextEditingController nameController = TextEditingController(text: location['name'] ?? '');
    final TextEditingController emailController = TextEditingController(text: location['manager_email'] ?? '');
    final TextEditingController passwordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_location, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text('Edit Location'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Location Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Manager Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password (leave blank to keep current)',
                      hintText: 'Enter new password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _updateLocation(
                      location['id'],
                      nameController.text,
                      emailController.text,
                      passwordController.text.isNotEmpty ? passwordController.text : null,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateLocation(int id, String name, String email, String? password) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'update_location';
      request.fields['id'] = id.toString();
      request.fields['location_name'] = name;
      request.fields['manager_email'] = email;
      if (password != null) {
        request.fields['manager_password'] = password;
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully!'), backgroundColor: Colors.blue),
        );
        _loadLocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to update location'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteLocation(int id, String name) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "$name"? This will also delete all menus and orders for this location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
                request.fields['action'] = 'delete_location';
                request.fields['id'] = id.toString();

                var response = await request.send();
                var responseBody = await response.stream.bytesToString();
                var data = json.decode(responseBody);

                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location deleted successfully!'), backgroundColor: Colors.green),
                  );
                  _loadLocations();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'] ?? 'Failed to delete'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        backgroundColor: brandGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB3D335)))
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLocations,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _locations.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('No locations found'),
            SizedBox(height: 8),
            Text('Tap + to add your first location'),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _locations.length,
        itemBuilder: (context, index) {
          final location = _locations[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: brandGreen.withOpacity(0.2),
                child: Text(
                  (location['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB3D335),
                  ),
                ),
              ),
              title: Text(
                location['name'] ?? 'Unknown',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: darkGreen,
                ),
              ),
              subtitle: Text(
                'Manager: ${location['manager_email'] ?? 'N/A'}',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _editLocation(location),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteLocation(
                      location['id'] ?? 0,
                      location['name'] ?? 'Unknown',
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Location ID', location['id']?.toString() ?? 'N/A'),
                      _buildInfoRow('Manager Email', location['manager_email'] ?? 'N/A'),
                      _buildInfoRow('Manager Password', '••••••••'),
                      _buildInfoRow('Created At', location['created_at'] ?? 'N/A'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================
// MENU TAB - WITH IMAGE UPLOAD
// ==============================================
class MenuTab extends StatefulWidget {
  const MenuTab({super.key});

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  List<Map<String, dynamic>> _menus = [];
  List<Map<String, dynamic>> _locations = [];
  String? _selectedLocation;
  bool _isLoading = true;
  bool _isLoadingLocations = true;
  String? _errorMessage;
  File? _selectedImage;
  String? _imageBase64;

  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';
  final String locationApiUrl = 'https://quantorra.co/tiffinwales/Locations.php';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadLocations();
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
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3D335).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant, color: Color(0xFFB3D335)),
                ),
                const SizedBox(width: 12),
                const Text('Add Menu Item'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Picker
                  GestureDetector(
                    onTap: () async {
                      await _pickImage();
                      setStateDialog(() {});
                    },
                    child: Container(
                      height: 120,
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.food_bank),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
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
                child: const Text('Cancel'),
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
                  backgroundColor: const Color(0xFFB3D335),
                  foregroundColor: const Color(0xFF2E4A00),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
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
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text('Edit Menu Item'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Picker
                  GestureDetector(
                    onTap: () async {
                      await _pickImage();
                      setStateDialog(() {});
                    },
                    child: Container(
                      height: 120,
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.food_bank),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _updateMenu(
                      menu['id'],
                      nameController.text,
                      descController.text,
                      double.parse(priceController.text),
                      selectedCategory,
                      _imageBase64,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveMenu(String name, String description, double price, String category, String? imageBase64) async {
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

  Future<void> _updateMenu(int id, String name, String description, double price, String category, String? imageBase64) async {
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

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu updated successfully!'), backgroundColor: Colors.blue),
        );
        _loadMenus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to update menu'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMenu(int id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: const Text('Are you sure you want to delete this menu item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
                request.fields['action'] = 'delete_menu';
                request.fields['menu_id'] = id.toString();

                var response = await request.send();
                var responseBody = await response.stream.bytesToString();
                var data = json.decode(responseBody);

                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Menu deleted successfully!'), backgroundColor: Colors.green),
                  );
                  _loadMenus();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'] ?? 'Failed to delete'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
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
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
      floatingActionButton: _selectedLocation != null
          ? FloatingActionButton(
        onPressed: _addMenu,
        backgroundColor: brandGreen,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      body: Column(
        children: [
          // Location Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingLocations
                ? const Center(child: CircularProgressIndicator())
                : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Select Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
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

          // Menu List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFB3D335)))
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _menus.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No menu items for this location'),
                  SizedBox(height: 8),
                  Text('Tap + to add your first item'),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _menus.length,
              itemBuilder: (context, index) {
                final menu = _menus[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.grey[50]!,
                        ],
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: brandGreen.withOpacity(0.2),
                        backgroundImage: menu['image_base64'] != null
                            ? MemoryImage(base64Decode(menu['image_base64']))
                            : null,
                        child: menu['image_base64'] == null
                            ? Text(
                          (menu['name'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB3D335),
                          ),
                        )
                            : null,
                      ),
                      title: Text(
                        menu['name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: darkGreen,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            menu['description'] ?? 'No description',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          Text(
                            'Category: ${menu['category'] ?? 'Main Course'}',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${menu['price']?.toString() ?? '0.00'}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: brandGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => _editMenu(menu),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _deleteMenu(menu['id'] ?? 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================
// ORDERS TAB
// ==============================================
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _locations = [];
  String? _selectedLocation;
  bool _isLoading = true;
  bool _isLoadingLocations = true;
  String? _errorMessage;

  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';
  final String locationApiUrl = 'https://quantorra.co/tiffinwales/Locations.php';

  @override
  void initState() {
    super.initState();
    _loadLocations();
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
            _loadOrders();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocations = false;
        _errorMessage = 'Failed to load locations';
      });
    }
  }

  Future<void> _loadOrders() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['location_name'] = _selectedLocation!;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load orders';
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

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'update_order_status';
      request.fields['order_id'] = orderId.toString();
      request.fields['order_status'] = newStatus;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus'), backgroundColor: Colors.green),
        );
        _loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to update'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Column(
      children: [
        // Location Filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoadingLocations
              ? const Center(child: CircularProgressIndicator())
              : Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedLocation,
              decoration: InputDecoration(
                labelText: 'Select Location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
              items: _getLocationDropdownItems(),
              onChanged: (value) {
                setState(() {
                  _selectedLocation = value;
                  _loadOrders();
                });
              },
            ),
          ),
        ),

        // Orders List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFB3D335)))
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _orders.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text('No orders for this location'),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final status = order['order_status'] ?? 'pending';

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: brandGreen.withOpacity(0.2),
                      child: Text(
                        '#${order['id'] ?? '?'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB3D335),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      order['customer_name'] ?? 'Unknown Customer',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: darkGreen,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: \$${order['total_amount']?.toString() ?? '0.00'}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: brandGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Customer', order['customer_name'] ?? 'N/A'),
                            _buildInfoRow('Phone', order['customer_phone'] ?? 'N/A'),
                            _buildInfoRow('Address', order['customer_address'] ?? 'N/A'),
                            _buildInfoRow('Instructions', order['special_instructions'] ?? 'None'),
                            _buildInfoRow('Created', order['created_at'] ?? 'N/A'),

                            const SizedBox(height: 16),
                            const Text(
                              'Update Status:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusButton('Pending', 'pending', status, order['id'] ?? 0),
                                _buildStatusButton('Preparing', 'preparing', status, order['id'] ?? 0),
                                _buildStatusButton('Ready', 'ready', status, order['id'] ?? 0),
                                _buildStatusButton('Delivered', 'delivered', status, order['id'] ?? 0),
                                _buildStatusButton('Cancelled', 'cancelled', status, order['id'] ?? 0),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String label, String statusValue, String currentStatus, int orderId) {
    final isSelected = currentStatus == statusValue;

    return ElevatedButton(
      onPressed: isSelected
          ? null
          : () => _updateOrderStatus(orderId, statusValue),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? _getStatusColor(statusValue) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}