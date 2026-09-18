import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:mhj_maps/mhj_maps.dart';
import 'package:location/location.dart' as loc;

class LocationsTab extends StatefulWidget {
  const LocationsTab({super.key});

  @override
  State<LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<LocationsTab> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  String _searchQuery = '';
  late AnimationController _animationController;
  MhjMapsMapController? _mapController;

  // mhj_maps related
  MhjMapsLatLng? _selectedPoint;

  final String apiUrl = 'https://quantorra.co/tiffinwales/Locations.php';

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
        _animationController.forward();
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

  List<Map<String, dynamic>> get _filteredLocations {
    if (_searchQuery.isEmpty) return _locations;
    return _locations.where((loc) {
      final name = (loc['name'] ?? '').toString().toLowerCase();
      final email = (loc['manager_email'] ?? '').toString().toLowerCase();
      final address = (loc['address'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query) || address.contains(query);
    }).toList();
  }

  // ==============================================
  // GEOCODE ADDRESS - Get coordinates from address
  // ==============================================
  Future<Map<String, double>?> _geocodeAddress({
    required String address,
    String city = '',
    String postalCode = '',
  }) async {
    try {
      // Build full address string
      String fullAddress = address;
      if (city.isNotEmpty) {
        fullAddress += ', $city';
      }
      if (postalCode.isNotEmpty) {
        fullAddress += ', $postalCode';
      }

      print('📍 Geocoding address: $fullAddress');

      List<Location> locations = await locationFromAddress(fullAddress);

      if (locations.isNotEmpty) {
        final lat = locations.first.latitude;
        final lng = locations.first.longitude;
        print('📍 Found coordinates: Lat: $lat, Lng: $lng');
        return {'latitude': lat, 'longitude': lng};
      }
      return null;
    } catch (e) {
      print('❌ Geocoding error: $e');
      return null;
    }
  }

  // ==============================================
  // SEARCH LOCATION
  // ==============================================
  Future<List<Map<String, dynamic>>> _searchLocation(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      List<Map<String, dynamic>> results = [];

      for (var location in locations) {
        // Get detailed address for each result
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        String address = '';
        String city = '';
        String postalCode = '';

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          address = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.postalCode,
          ].where((e) => e != null && e.isNotEmpty).join(', ');

          city = place.locality ??
              place.administrativeArea ??
              place.subAdministrativeArea ??
              place.subLocality ??
              '';

          postalCode = place.postalCode ?? '';

          if (postalCode.isEmpty) {
            RegExp regExp = RegExp(r'\b\d{5,6}\b');
            Match? match = regExp.firstMatch(address);
            if (match != null) {
              postalCode = match.group(0) ?? '';
            }
          }
        }

        results.add({
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': address.isNotEmpty ? address : query,
          'city': city,
          'postalCode': postalCode,
        });
      }

      return results;
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  // ==============================================
  // MHJ_MAPS SELECTION DIALOG - WITH SEARCH & OPENSTREETMAP
  // ==============================================
  Future<MhjMapsLatLng?> _showMapPicker({MhjMapsLatLng? initialLocation}) async {
    // Default location - Mumbai
    final MhjMapsLatLng defaultLocation = const MhjMapsLatLng(lat: 19.0760, lng: 72.8777);
    MhjMapsLatLng selectedPoint = initialLocation ?? defaultLocation;
    String selectedAddress = '';
    String selectedCity = '';
    String selectedPostalCode = '';
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    bool showResults = false;

    return showDialog<MhjMapsLatLng>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Location on Map',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 550,
              child: Column(
                children: [
                  // ==========================================
                  // SEARCH BAR
                  // ==========================================
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: (value) async {
                              if (value.length >= 3) {
                                setStateDialog(() {
                                  isSearching = true;
                                  showResults = true;
                                });
                                // Search for locations
                                final results = await _searchLocation(value);
                                setStateDialog(() {
                                  searchResults = results;
                                  isSearching = false;
                                });
                              } else {
                                setStateDialog(() {
                                  showResults = false;
                                  searchResults = [];
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Search for address, city, or place...',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            onPressed: () {
                              searchController.clear();
                              setStateDialog(() {
                                showResults = false;
                                searchResults = [];
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ==========================================
                  // SEARCH RESULTS LIST
                  // ==========================================
                  if (showResults && searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isSearching
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length > 5 ? 5 : searchResults.length,
                        itemBuilder: (context, index) {
                          final result = searchResults[index];
                          return InkWell(
                            onTap: () {
                              final lat = result['latitude'];
                              final lng = result['longitude'];
                              final address = result['address'] ?? '';
                              final city = result['city'] ?? '';
                              final postalCode = result['postalCode'] ?? '';

                              final point = MhjMapsLatLng(lat: lat, lng: lng);
                              setStateDialog(() {
                                selectedPoint = point;
                                selectedAddress = address;
                                selectedCity = city;
                                selectedPostalCode = postalCode;
                                showResults = false;
                                searchController.text = address;
                              });
                              // Update marker on map
                              _mapController?.clearMarkers();
                              _mapController?.addMarker(
                                position: point,
                                icon: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 42,
                                ),
                              );
                              _mapController?.moveTo(
                                point,
                                zoom: 15,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[100]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: const Color(0xFF6366F1),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          result['address'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (result['city'] != null &&
                                            result['city'].isNotEmpty)
                                          Text(
                                            '${result['city']}${result['postalCode'] != null && result['postalCode'].isNotEmpty ? ', ${result['postalCode']}' : ''}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
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
                    ),

                  if (showResults && searchResults.isEmpty && !isSearching)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_off,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'No results found',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ==========================================
                  // MHJ_MAPS WITH OPENSTREETMAP
                  // ==========================================
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MhjMapsMap(
                        center: selectedPoint,
                        zoom: 14,
                        tileProvider: MhjMapsTileProvider.openStreetMap,
                        showZoomControls: true,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          // Add initial marker
                          controller.addMarker(
                            position: selectedPoint,
                            icon: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 42,
                            ),
                          );
                        },
                        onTap: (MhjMapsLatLng point) async {
                          _mapController?.clearMarkers();
                          _mapController?.addMarker(
                            position: point,
                            icon: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 42,
                            ),
                          );
                          _mapController?.moveTo(
                            point,
                            zoom: 15,
                          );

                          setStateDialog(() {
                            selectedPoint = point;
                            showResults = false;
                            searchController.clear();
                            searchResults = [];
                          });
                          // Get address details from coordinates
                          final addressData = await _getAddressFromLatLng(
                            LatLng(point.lat, point.lng),
                          );
                          if (addressData != null) {
                            setStateDialog(() {
                              selectedAddress = addressData['address'] ?? '';
                              selectedCity = addressData['city'] ?? '';
                              selectedPostalCode = addressData['postalCode'] ?? '';
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ==========================================
                  // ADDRESS PREVIEW WITH CITY & POSTAL CODE
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF6366F1), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Location',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Lat: ${selectedPoint.lat.toStringAsFixed(6)}, Lng: ${selectedPoint.lng.toStringAsFixed(6)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A202C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              onPressed: () {
                                Navigator.pop(context, selectedPoint);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        // City & Postal Code Display
                        if (selectedCity.isNotEmpty || selectedPostalCode.isNotEmpty) ...[
                          const Divider(height: 8, thickness: 1),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (selectedCity.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_city, size: 14, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'City: $selectedCity',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (selectedPostalCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.pin_drop, size: 14, color: Colors.green.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Postal: $selectedPostalCode',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (selectedAddress.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.home_outlined, size: 14, color: Colors.purple.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        selectedAddress.length > 30
                                            ? '${selectedAddress.substring(0, 30)}...'
                                            : selectedAddress,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.purple.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📌 Tap anywhere on the map or search for a location',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, selectedPoint);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm',
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

  // ==============================================
  // GET ADDRESS FROM LATLNG
  // ==============================================
  Future<Map<String, String>?> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        String city = place.locality ??
            place.administrativeArea ??
            place.subAdministrativeArea ??
            place.subLocality ??
            '';

        String postalCode = place.postalCode ?? '';

        if (postalCode.isEmpty) {
          RegExp regExp = RegExp(r'\b\d{5,6}\b');
          Match? match = regExp.firstMatch(address);
          if (match != null) {
            postalCode = match.group(0) ?? '';
          }
        }

        return {
          'address': address,
          'city': city,
          'postalCode': postalCode,
        };
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  // ==============================================
  // ADD LOCATION WITH GEOCODING
  // ==============================================
  Future<void> _addLocation() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController cityController = TextEditingController();
    final TextEditingController postalCodeController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    MhjMapsLatLng? selectedPoint;
    String selectedAddress = '';
    String selectedCity = '';
    String selectedPostalCode = '';
    bool _isGeocoding = false;

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
                  child: const Icon(Icons.add_location, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Text(
                  'Add New Location',
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
                  // Location Name
                  _buildTextField(
                    controller: nameController,
                    label: 'Location Name *',
                    hint: 'e.g., Mumbai - Andheri',
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 14),

                  // Manager Email
                  _buildTextField(
                    controller: emailController,
                    label: 'Manager Email *',
                    hint: 'manager@example.com',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Manager Password
                  _buildTextField(
                    controller: passwordController,
                    label: 'Manager Password *',
                    hint: 'Enter password',
                    icon: Icons.lock,
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),

                  // Address
                  _buildTextField(
                    controller: addressController,
                    label: 'Street Address',
                    hint: 'Enter full street address',
                    icon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 14),

                  // City & Postal Code Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: cityController,
                          label: 'City',
                          hint: 'Enter city',
                          icon: Icons.location_city_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: postalCodeController,
                          label: 'Postal Code',
                          hint: 'Enter postal code',
                          icon: Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Phone
                  _buildTextField(
                    controller: phoneController,
                    label: 'Contact Phone',
                    hint: 'Enter phone number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  // Geocoding Status
                  if (_isGeocoding)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '📍 Finding coordinates for address...',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Map Location Selector Button
                  GestureDetector(
                    onTap: () async {
                      final point = await _showMapPicker();
                      if (point != null) {
                        setStateDialog(() {
                          selectedPoint = point;
                        });
                        // Get address from coordinates
                        final addressData = await _getAddressFromLatLng(
                          LatLng(point.lat, point.lng),
                        );
                        if (addressData != null) {
                          setStateDialog(() {
                            selectedAddress = addressData['address'] ?? '';
                            selectedCity = addressData['city'] ?? '';
                            selectedPostalCode = addressData['postalCode'] ?? '';
                            addressController.text = selectedAddress;
                            cityController.text = selectedCity;
                            postalCodeController.text = selectedPostalCode;
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedPoint != null ? const Color(0xFFEEF2FF) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedPoint != null ? const Color(0xFF6366F1) : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedPoint != null ? Icons.location_on : Icons.map_rounded,
                            color: selectedPoint != null ? const Color(0xFF6366F1) : Colors.grey[600],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedPoint != null ? 'Location Selected' : 'Select Location on Map',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selectedPoint != null ? const Color(0xFF6366F1) : Colors.grey[600],
                                  ),
                                ),
                                if (selectedPoint != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lat: ${selectedPoint?.lat.toStringAsFixed(6)}, Lng: ${selectedPoint?.lng.toStringAsFixed(6)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      if (selectedAddress.isNotEmpty)
                                        Text(
                                          selectedAddress,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            selectedPoint != null ? Icons.check_circle : Icons.arrow_forward_ios,
                            color: selectedPoint != null ? Colors.green : Colors.grey[400],
                            size: 18,
                          ),
                        ],
                      ),
                    ),
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
                  if (nameController.text.isNotEmpty &&
                      emailController.text.isNotEmpty &&
                      passwordController.text.isNotEmpty) {

                    // Show geocoding status
                    setStateDialog(() {
                      _isGeocoding = true;
                    });

                    // Get coordinates from address if not selected from map
                    double? latitude = selectedPoint?.lat;
                    double? longitude = selectedPoint?.lng;

                    // If no map selection, try geocoding
                    if (latitude == null || longitude == null) {
                      final coords = await _geocodeAddress(
                        address: addressController.text,
                        city: cityController.text,
                        postalCode: postalCodeController.text,
                      );
                      if (coords != null) {
                        latitude = coords['latitude'];
                        longitude = coords['longitude'];
                      }
                    }

                    setStateDialog(() {
                      _isGeocoding = false;
                    });

                    Navigator.pop(context);
                    await _saveLocation(
                      name: nameController.text,
                      email: emailController.text,
                      password: passwordController.text,
                      address: addressController.text,
                      city: cityController.text,
                      postalCode: postalCodeController.text,
                      phone: phoneController.text,
                      latitude: latitude,
                      longitude: longitude,
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
                  'Add Location',
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

  Future<void> _saveLocation({
    required String name,
    required String email,
    required String password,
    String address = '',
    String city = '',
    String postalCode = '',
    String phone = '',
    double? latitude,
    double? longitude,
  }) async {
    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'add_location';
      request.fields['location_name'] = name;
      request.fields['manager_email'] = email;
      request.fields['manager_password'] = password;
      request.fields['address'] = address;
      request.fields['city'] = city;
      request.fields['postal_code'] = postalCode;
      request.fields['phone'] = phone;

      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      setState(() => _isProcessing = false);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar(
              'Location added successfully! ${latitude != null ? "📍 Coordinates found" : ""}'
          ),
        );
        _loadLocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(data['message'] ?? 'Failed to add location'),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        _buildErrorSnackBar('Error: ${e.toString()}'),
      );
    }
  }

  // ==============================================
  // EDIT LOCATION WITH GEOCODING
  // ==============================================
  Future<void> _editLocation(Map<String, dynamic> location) async {
    final TextEditingController nameController = TextEditingController(text: location['name'] ?? '');
    final TextEditingController emailController = TextEditingController(text: location['manager_email'] ?? '');
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController addressController = TextEditingController(text: location['address'] ?? '');
    final TextEditingController cityController = TextEditingController(text: location['city'] ?? '');
    final TextEditingController postalCodeController = TextEditingController(text: location['postal_code'] ?? '');
    final TextEditingController phoneController = TextEditingController(text: location['phone'] ?? '');
    MhjMapsLatLng? selectedPoint;
    bool _isGeocoding = false;

    // Parse existing location from latitude and longitude fields
    if (location['latitude'] != null &&
        location['latitude'].toString().isNotEmpty &&
        location['longitude'] != null &&
        location['longitude'].toString().isNotEmpty) {
      try {
        final lat = double.parse(location['latitude'].toString());
        final lng = double.parse(location['longitude'].toString());
        selectedPoint = MhjMapsLatLng(lat: lat, lng: lng);
      } catch (e) {
        // Ignore parse errors
      }
    }

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
                  child: const Icon(Icons.edit_location, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Text(
                  'Edit Location',
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
                  _buildTextField(
                    controller: nameController,
                    label: 'Location Name *',
                    hint: 'e.g., Mumbai - Andheri',
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: emailController,
                    label: 'Manager Email *',
                    hint: 'manager@example.com',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: passwordController,
                    label: 'New Password (leave blank to keep current)',
                    hint: 'Enter new password',
                    icon: Icons.lock,
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: addressController,
                    label: 'Street Address',
                    hint: 'Enter full street address',
                    icon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: cityController,
                          label: 'City',
                          hint: 'Enter city',
                          icon: Icons.location_city_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: postalCodeController,
                          label: 'Postal Code',
                          hint: 'Enter postal code',
                          icon: Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: phoneController,
                    label: 'Contact Phone',
                    hint: 'Enter phone number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  // Geocoding Status
                  if (_isGeocoding)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '📍 Finding coordinates for address...',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Map Location Selector Button
                  GestureDetector(
                    onTap: () async {
                      final point = await _showMapPicker(initialLocation: selectedPoint);
                      if (point != null) {
                        setStateDialog(() {
                          selectedPoint = point;
                        });
                        // Get address from coordinates
                        final addressData = await _getAddressFromLatLng(
                          LatLng(point.lat, point.lng),
                        );
                        if (addressData != null) {
                          setStateDialog(() {
                            addressController.text = addressData['address'] ?? addressController.text;
                            cityController.text = addressData['city'] ?? cityController.text;
                            postalCodeController.text = addressData['postalCode'] ?? postalCodeController.text;
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedPoint != null ? const Color(0xFFEEF2FF) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedPoint != null ? const Color(0xFF6366F1) : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedPoint != null ? Icons.location_on : Icons.map_rounded,
                            color: selectedPoint != null ? const Color(0xFF6366F1) : Colors.grey[600],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedPoint != null ? 'Location Selected' : 'Select Location on Map',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selectedPoint != null ? const Color(0xFF6366F1) : Colors.grey[600],
                                  ),
                                ),
                                if (selectedPoint != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lat: ${selectedPoint?.lat.toStringAsFixed(6)}, Lng: ${selectedPoint?.lng.toStringAsFixed(6)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      if (addressController.text.isNotEmpty)
                                        Text(
                                          addressController.text,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            selectedPoint != null ? Icons.check_circle : Icons.arrow_forward_ios,
                            color: selectedPoint != null ? Colors.green : Colors.grey[400],
                            size: 18,
                          ),
                        ],
                      ),
                    ),
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
                  if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {

                    // Show geocoding status
                    setStateDialog(() {
                      _isGeocoding = true;
                    });

                    // Get coordinates from address if not selected from map
                    double? latitude = selectedPoint?.lat;
                    double? longitude = selectedPoint?.lng;

                    // If no map selection, try geocoding
                    if (latitude == null || longitude == null) {
                      final coords = await _geocodeAddress(
                        address: addressController.text,
                        city: cityController.text,
                        postalCode: postalCodeController.text,
                      );
                      if (coords != null) {
                        latitude = coords['latitude'];
                        longitude = coords['longitude'];
                      }
                    }

                    setStateDialog(() {
                      _isGeocoding = false;
                    });

                    Navigator.pop(context);
                    await _updateLocation(
                      id: location['id'] ?? 0,
                      name: nameController.text,
                      email: emailController.text,
                      password: passwordController.text.isNotEmpty ? passwordController.text : null,
                      address: addressController.text,
                      city: cityController.text,
                      postalCode: postalCodeController.text,
                      phone: phoneController.text,
                      latitude: latitude,
                      longitude: longitude,
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

  Future<void> _updateLocation({
    required int id,
    required String name,
    required String email,
    String? password,
    String address = '',
    String city = '',
    String postalCode = '',
    String phone = '',
    double? latitude,
    double? longitude,
  }) async {
    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'update_location';
      request.fields['id'] = id.toString();
      request.fields['location_name'] = name;
      request.fields['manager_email'] = email;
      request.fields['address'] = address;
      request.fields['city'] = city;
      request.fields['postal_code'] = postalCode;
      request.fields['phone'] = phone;

      if (password != null && password.isNotEmpty) {
        request.fields['manager_password'] = password;
      }
      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      setState(() => _isProcessing = false);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar(
              'Location updated successfully! ${latitude != null ? "📍 Coordinates found" : ""}'
          ),
        );
        _loadLocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(data['message'] ?? 'Failed to update location'),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        _buildErrorSnackBar('Error: ${e.toString()}'),
      );
    }
  }

  // ==============================================
  // DELETE LOCATION
  // ==============================================
  Future<void> _deleteLocation(int id, String name) async {
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
              'Delete Location',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$name"?',
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
                  Text(
                    '⚠️ This will permanently delete:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• All menu items for this location\n• All orders for this location\n• Manager account for this location',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
                request.fields['action'] = 'delete_location';
                request.fields['id'] = id.toString();

                var response = await request.send();
                var responseBody = await response.stream.bytesToString();
                var data = json.decode(responseBody);

                setState(() => _isProcessing = false);

                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    _buildSuccessSnackBar('Location deleted successfully!'),
                  );
                  _loadLocations();
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

  // ==============================================
  // UI BUILD METHODS
  // ==============================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    const Color primaryColor = Color(0xFF6366F1);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to format latitude/longitude
  String _formatLatLng(String value) {
    try {
      final num = double.parse(value);
      return num.toStringAsFixed(6);
    } catch (e) {
      return value;
    }
  }

  Widget _buildLocationCard(Map<String, dynamic> location, int index) {
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
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              (location['name'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          location['name'] ?? 'Unknown Location',
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
              '📧 ${location['manager_email'] ?? 'N/A'}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (location['address'] != null && location['address'].toString().isNotEmpty)
              Text(
                '🏠 ${location['address']}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (location['city'] != null && location['city'].toString().isNotEmpty)
              Text(
                '📍 ${location['city']} ${location['postal_code'] ?? ''}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            // Show coordinates if available
            if (location['latitude'] != null &&
                location['latitude'].toString().isNotEmpty &&
                location['longitude'] != null &&
                location['longitude'].toString().isNotEmpty)
              Text(
                '🌐 ${_formatLatLng(location['latitude'])}, ${_formatLatLng(location['longitude'])}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
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
              onPressed: () => _editLocation(location),
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
              onPressed: () => _deleteLocation(
                location['id'] ?? 0,
                location['name'] ?? 'Unknown',
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow('Location ID', location['id']?.toString() ?? 'N/A'),
                _buildInfoRow('Location Name', location['name'] ?? 'N/A'),
                _buildInfoRow('Manager Email', location['manager_email'] ?? 'N/A'),
                if (location['address'] != null && location['address'].toString().isNotEmpty)
                  _buildInfoRow('Address', location['address']),
                if (location['city'] != null && location['city'].toString().isNotEmpty)
                  _buildInfoRow('City', location['city']),
                if (location['postal_code'] != null && location['postal_code'].toString().isNotEmpty)
                  _buildInfoRow('Postal Code', location['postal_code']),
                if (location['phone'] != null && location['phone'].toString().isNotEmpty)
                  _buildInfoRow('Phone', location['phone']),
                if (location['latitude'] != null && location['latitude'].toString().isNotEmpty)
                  _buildInfoRow('Latitude', _formatLatLng(location['latitude'])),
                if (location['longitude'] != null && location['longitude'].toString().isNotEmpty)
                  _buildInfoRow('Longitude', _formatLatLng(location['longitude'])),
                _buildInfoRow('Created At', location['created_at'] ?? 'N/A'),
              ],
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
            'Failed to Load Locations',
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
            onPressed: _loadLocations,
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
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.location_off,
              size: 50,
              color: const Color(0xFF6366F1).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No locations found'
                : 'No Locations Added Yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap the + button to add your first location',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Location',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
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
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search locations...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ),

          // Location Count
          if (!_isLoading && _locations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredLocations.length} Locations',
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

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            )
                : _errorMessage != null
                ? _buildErrorState()
                : _filteredLocations.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadLocations,
              color: primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _filteredLocations.length,
                itemBuilder: (context, index) {
                  final location = _filteredLocations[index];
                  return _buildLocationCard(location, index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}