import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';

class ManagerScreen extends StatefulWidget {
  final String locationName;

  const ManagerScreen({
    super.key,
    required this.locationName,
  });

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
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
                      Icons.storefront,
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
                          'Manager Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.locationName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
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
                  _buildTabButton('Menu', 0, Icons.restaurant_menu, brandGreen),
                  _buildTabButton('Orders', 1, Icons.receipt_long, brandGreen),
                ],
              ),
            ),

            // Content
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  ManagerMenuTab(locationName: widget.locationName),
                  ManagerOrdersTab(locationName: widget.locationName),
                ],
              ),
            ),
          ],
        ),
      ),
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
// MANAGER MENU TAB
// ==============================================
class ManagerMenuTab extends StatefulWidget {
  final String locationName;

  const ManagerMenuTab({super.key, required this.locationName});

  @override
  State<ManagerMenuTab> createState() => _ManagerMenuTabState();
}

class _ManagerMenuTabState extends State<ManagerMenuTab> {
  List<Map<String, dynamic>> _menus = [];
  bool _isLoading = true;
  String? _errorMessage;

  final String menuApiUrl = 'https://quantorra.co/tiffinwales/Menu.php';

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
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

  Future<void> _addMenu() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String selectedCategory = 'Main Course';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'Starters', child: Text('Starters')),
                  DropdownMenuItem(value: 'Main Course', child: Text('Main Course')),
                  DropdownMenuItem(value: 'Breads', child: Text('Breads')),
                  DropdownMenuItem(value: 'Desserts', child: Text('Desserts')),
                  DropdownMenuItem(value: 'Beverages', child: Text('Beverages')),
                ],
                onChanged: (value) {
                  if (value != null) selectedCategory = value;
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
      ),
    );
  }

  Future<void> _saveMenu(String name, String description, double price, String category) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(menuApiUrl));
      request.fields['action'] = 'add_menu';
      request.fields['location_name'] = widget.locationName;
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['price'] = price.toString();
      request.fields['category'] = category;

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

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addMenu,
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
              onPressed: _loadMenus,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _menus.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('No menu items yet'),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: brandGreen.withOpacity(0.2),
                child: Text(
                  (menu['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB3D335),
                  ),
                ),
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
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  Text(
                    'Category: ${menu['category'] ?? 'Main Course'}',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '\$${menu['price']?.toString() ?? '0.00'}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: brandGreen,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteMenu(menu['id'] ?? 0),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==============================================
// MANAGER ORDERS TAB
// ==============================================
class ManagerOrdersTab extends StatefulWidget {
  final String locationName;

  const ManagerOrdersTab({super.key, required this.locationName});

  @override
  State<ManagerOrdersTab> createState() => _ManagerOrdersTabState();
}

class _ManagerOrdersTabState extends State<ManagerOrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  final String ordersApiUrl = 'https://quantorra.co/tiffinwales/Orders.php';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ordersApiUrl));
      request.fields['action'] = 'get_orders';
      request.fields['location_name'] = widget.locationName;

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

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Scaffold(
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
              onPressed: _loadOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _orders.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('No orders yet'),
            SizedBox(height: 8),
            Text('Orders will appear here'),
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
                borderRadius: BorderRadius.circular(12),
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