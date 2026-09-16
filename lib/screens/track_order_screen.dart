import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mhj_maps/mhj_maps.dart';

class TrackOrderScreen extends StatefulWidget {
  final String email;
  final String locationName;
  final String orderId;
  final double total;
  final String deliveryAddress;

  const TrackOrderScreen({
    super.key,
    required this.email,
    required this.locationName,
    required this.orderId,
    required this.total,
    required this.deliveryAddress,
  });

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> with SingleTickerProviderStateMixin {
  // ==============================================
  // MAP CONTROLLER & INSTANCE
  // ==============================================
  MhjMapsMapController? _mapController;
  final MhjMaps _mhjMaps = MhjMaps();

  // ==============================================
  // LOCATIONS
  // ==============================================
  MhjMapsLatLng? _restaurantLocation;
  MhjMapsLatLng? _customerLocation;
  MhjMapsLatLng? _driverLocation;

  // ==============================================
  // ROUTE
  // ==============================================
  RouteResult? _routeResult;
  bool _isRouteCalculated = false;

  // ==============================================
  // TIMER VARIABLES
  // ==============================================
  static const int _totalDeliveryTime = 30; // 30 minutes
  int _remainingSeconds = _totalDeliveryTime * 60;
  Timer? _timer;
  Timer? _driverMovementTimer;
  bool _isTimerRunning = false;
  bool _isOrderDelivered = false;
  String _orderStatus = 'Preparing';

  // ==============================================
  // ANIMATION
  // ==============================================
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ==============================================
  // STATE
  // ==============================================
  bool _isLoading = true;
  String? _errorMessage;
  String _routeDistance = '';
  String _routeDuration = '';

  // Track if user is manually interacting with map to avoid fighting camera
  bool _isUserInteracting = false;
  DateTime _lastInteractionTime = DateTime.now();

  // ==============================================
  // API ENDPOINTS
  // ==============================================
  final String locationApiUrl = 'https://quantorra.co/tiffinwales/Locations.php';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _driverMovementTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ==============================================
  // INITIALIZE TRACKING
  // ==============================================
  Future<void> _initializeTracking() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Step 1: Get restaurant location
      await _getRestaurantLocation();

      if (_restaurantLocation == null) {
        throw Exception('Failed to get restaurant location');
      }

      // Step 2: Geocode delivery address to get customer location
      await _geocodeDeliveryAddress();

      if (_customerLocation == null) {
        throw Exception('Failed to locate delivery address. Please check the address and try again.');
      }

      // Step 3: Calculate route
      await _calculateRoute();

      // Step 4: Update UI
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRouteCalculated = true;
      });

      // Step 5: Draw markers and route
      _updateMapVisuals();

      // Step 6: Start timer and driver movement
      await _startTimer();
      _startDriverMovement();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
      debugPrint('Initialization error: $e');
    }
  }

  // ==============================================
  // RESTAURANT LOCATION
  // ==============================================
  Future<void> _getRestaurantLocation() async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(locationApiUrl));
      request.fields['action'] = 'get_locations';

      var response = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success' && data['data'] != null) {
        final locations = List<Map<String, dynamic>>.from(data['data']);
        final location = locations.firstWhere(
              (loc) => loc['name'] == widget.locationName,
          orElse: () => locations.first,
        );

        if (location['latitude'] != null && location['longitude'] != null) {
          _restaurantLocation = MhjMapsLatLng(
            lat: double.parse(location['latitude'].toString()),
            lng: double.parse(location['longitude'].toString()),
          );
          debugPrint('Restaurant location: ${_restaurantLocation}');
        }
      }
    } catch (e) {
      debugPrint('Error getting restaurant location: $e');
      rethrow;
    }
  }

  // ==============================================
  // GEOCODE DELIVERY ADDRESS (NO GPS)
  // ==============================================
  Future<void> _geocodeDeliveryAddress() async {
    if (widget.deliveryAddress.isEmpty) {
      throw Exception('Delivery address is empty');
    }

    try {
      debugPrint('Geocoding address: ${widget.deliveryAddress}');

      // Use mhj_maps geocoding - Returns a single GeocodeResult
      final result = await _mhjMaps.geocode(widget.deliveryAddress);

      // Check if result is valid (not null and has coordinates)
      if (result != null && result.lat != null && result.lng != null) {
        _customerLocation = MhjMapsLatLng(
          lat: result.lat!,
          lng: result.lng!,
        );
        debugPrint('Customer location: $_customerLocation');
        debugPrint('Full address: ${result.displayName}');
      } else {
        throw Exception('No results found for address');
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      throw Exception('Could not locate delivery address: ${widget.deliveryAddress}');
    }
  }

  // ==============================================
  // ROUTE CALCULATION
  // ==============================================
  Future<void> _calculateRoute() async {
    if (_restaurantLocation == null || _customerLocation == null) {
      throw Exception('Missing location data for route calculation');
    }

    try {
      debugPrint('Calculating route from restaurant to customer...');

      final result = await _mhjMaps.route(
        origin: _restaurantLocation!,
        destination: _customerLocation!,
        costing: 'auto', // Driving profile
      );

      _routeResult = result;

      if (result.polyline.isNotEmpty) {
        debugPrint('Route calculated successfully');
        debugPrint('Route points: ${result.polyline.length}');

        _routeDistance = result.distanceText;
        _routeDuration = result.durationText;
      } else {
        throw Exception('Route polyline is empty');
      }
    } catch (e) {
      debugPrint('Route calculation error: $e');
      rethrow;
    }
  }

  // ==============================================
  // UPDATE MAP VISUALS (Route + Markers)
  // ==============================================
  void _updateMapVisuals() {
    if (_mapController == null) return;

    // Clear only markers, not the route
    _mapController!.clearMarkers();

    // Restaurant Marker
    if (_restaurantLocation != null) {
      _mapController!.addMarker(
        position: _restaurantLocation!,
        icon: const Icon(
          Icons.restaurant,
          color: Colors.blue,
          size: 42,
        ),
      );
    }

    // Customer Marker
    if (_customerLocation != null) {
      _mapController!.addMarker(
        position: _customerLocation!,
        icon: const Icon(
          Icons.location_on,
          color: Colors.green,
          size: 42,
        ),
      );
    }

    // Driver Marker (navigation pointer)
    if (_driverLocation != null && !_isOrderDelivered) {
      final rotation = _calculateBearing();
      _mapController!.addMarker(
        position: _driverLocation!,
        icon: Transform.rotate(
          angle: rotation,
          child: const Icon(
            Icons.navigation,
            color: Colors.red,
            size: 48,
          ),
        ),
      );
    }

    // After delivery, show checkmark at customer location
    if (_isOrderDelivered && _customerLocation != null) {
      _mapController!.addMarker(
        position: _customerLocation!,
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 56,
        ),
      );
    }
  }

  // ==============================================
  // DRAW ROUTE ON MAP
  // ==============================================
  void _drawRouteOnMap() {
    if (_mapController == null || _routeResult == null) return;

    try {
      debugPrint('Drawing route on map...');

      // Draw the route using Color object
      _mapController!.drawRoute(
        _routeResult!.polyline,
        color: const Color(0xFF6366F1),
        width: 4.0,
        borderColor: Colors.black26,
        borderWidth: 1,
      );

      // Fit the map to show the entire route with padding
      _mapController!.fitRoute(_routeResult!.polyline);

      debugPrint('Route drawn successfully');
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  // ==============================================
  // START DRIVER MOVEMENT
  // ==============================================
  // ==============================================
  // START DRIVER MOVEMENT (OPTIMIZED)
  // ==============================================
  void _startDriverMovement() {
    if (_routeResult == null || _routeResult!.polyline.isEmpty) {
      debugPrint('Cannot start driver movement - no route available');
      return;
    }

    final routePoints = _routeResult!.polyline;
    _driverMovementTimer?.cancel();

    final startTime = DateTime.now();
    final totalDurationMs = _totalDeliveryTime * 60 * 1000;

    _driverMovementTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _isOrderDelivered) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final elapsedMs = now.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch;
      final progress = (elapsedMs / totalDurationMs).clamp(0.0, 1.0);

      if (progress >= 1.0) {
        timer.cancel();
        setState(() {
          _isOrderDelivered = true;
          _orderStatus = 'Delivered';
          _driverLocation = routePoints.last;
        });
        _timer?.cancel();
        _updateMapVisuals();
        _showDeliveryCompleteDialog();
      } else {
        // Interpolate position
        final targetIndex = (progress * (routePoints.length - 1)).floor();
        final currentIndex = targetIndex.clamp(0, routePoints.length - 1);

        setState(() {
          _driverLocation = routePoints[currentIndex];
          _driverRouteIndex = currentIndex;
        });

        // CRITICAL FIX: Only update the marker visual.
        // Do NOT call moveTo() here. This allows you to zoom freely.
        _updateMapVisuals();
      }
    });
  }

  // ==============================================
  // MAP ON CREATED
  // ==============================================
  void _onMapCreated(MhjMapsMapController controller) {
    _mapController = controller;
    debugPrint('Map controller created');

    // If route is already calculated, draw it and fit bounds ONCE.
    // After this, the user controls the zoom/pan.
    if (_isRouteCalculated && _routeResult != null) {
      _drawRouteOnMap();
      _updateMapVisuals();
    } else if (_restaurantLocation != null) {
      _mapController!.moveTo(_restaurantLocation!, zoom: 13);
    }
  }

  // ==============================================
  // MAP WIDGET
  // ==============================================
  Widget _buildMap(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _restaurantLocation == null
            ? Container(
          color: Colors.grey[100],
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          ),
        )
            : Stack(
          children: [
            MhjMapsMap(
              onMapCreated: _onMapCreated,
              center: _restaurantLocation!,
              zoom: 13,
              // Allow full zoom range
              minZoom: 3,
              maxZoom: 19,
              tileProvider: MhjMapsTileProvider.openStreetMap,
              showZoomControls: true,
              onTap: (point) {},
            ),
            // Driver Pulse Animation (Visual only)
            if (_driverLocation != null && !_isOrderDelivered)
              Positioned(
                bottom: 20,
                right: 20,
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            // Manual "Focus on Driver" Button
            // Only use this if you WANT to jump back to the driver
            Positioned(
              bottom: 20,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  if (_driverLocation != null && _mapController != null) {
                    _mapController!.moveTo(_driverLocation!, zoom: 16);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Helper for driver index (used in bearing calc)
  int _driverRouteIndex = 0;

  // ==============================================
  // CALCULATE BEARING FOR ROTATION
  // ==============================================
  double _calculateBearing() {
    if (_routeResult == null || _driverRouteIndex >= _routeResult!.polyline.length - 1) {
      return 0.0;
    }

    final current = _routeResult!.polyline[_driverRouteIndex];
    final next = _routeResult!.polyline[_driverRouteIndex + 1];

    final lat1 = current.lat * math.pi / 180;
    final lat2 = next.lat * math.pi / 180;
    final lngDiff = (next.lng - current.lng) * math.pi / 180;

    final y = math.sin(lngDiff) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lngDiff);

    double bearing = math.atan2(y, x);

    // Convert to degrees and normalize
    bearing = bearing * 180 / math.pi;
    if (bearing < 0) bearing += 360;

    return bearing * math.pi / 180; // Convert back to radians for Transform.rotate
  }

  // ==============================================
  // TIMER FUNCTIONS
  // ==============================================
  Future<void> _startTimer() async {
    setState(() => _isTimerRunning = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _updateOrderStatus();
        } else {
          timer.cancel();
          _isTimerRunning = false;
          _orderStatus = 'Delayed';
        }
      });
    });
  }

  void _updateOrderStatus() {
    final elapsed = (_totalDeliveryTime * 60) - _remainingSeconds;
    final progress = elapsed / (_totalDeliveryTime * 60);

    if (progress < 0.2) {
      _orderStatus = 'Preparing';
    } else if (progress < 0.5) {
      _orderStatus = 'Ready';
    } else if (progress < 0.8) {
      _orderStatus = 'On the Way';
    } else if (progress < 1.0) {
      _orderStatus = 'Nearby';
    } else {
      _orderStatus = 'Delivered';
    }
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _timerProgress => 1 - (_remainingSeconds / (_totalDeliveryTime * 60));

  // ==============================================
  // MAP ON CREATED
  // ==============================================


  // ==============================================
  // SHOW DELIVERY COMPLETE DIALOG
  // ==============================================
  void _showDeliveryCompleteDialog() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Order Delivered! 🎉',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your order has been delivered successfully!',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Total:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    Text(
                      '\$${widget.total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              if (_routeDistance.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.route, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Route: $_routeDistance • $_routeDuration',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Thank you for ordering from ${widget.locationName}!',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ==============================================
  // BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1);
    const Color darkColor = Color(0xFF1A202C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(
          'Track Order',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#${widget.orderId}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : Column(
        children: [
          _buildStatusHeader(primaryColor, darkColor),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: _buildMap(primaryColor),
          ),
          _buildOrderDetails(primaryColor, darkColor),
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
          const CircularProgressIndicator(
            color: Color(0xFF6366F1),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your order...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to load tracking',
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

  // ==============================================
  // STATUS HEADER WITH TIMER
  // ==============================================
  Widget _buildStatusHeader(Color primaryColor, Color darkColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor().withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _orderStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!_isOrderDelivered)
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formattedTime,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isOrderDelivered) ...[
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  width: MediaQuery.of(context).size.width * 0.85 * _timerProgress,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        const Color(0xFF8B5CF6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Placed',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
                Text(
                  'Delivered',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
          if (_isOrderDelivered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '🎉 Order Delivered Successfully!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_orderStatus) {
      case 'Preparing':
        return Colors.orange;
      case 'Ready':
        return Colors.blue;
      case 'On the Way':
        return const Color(0xFF6366F1);
      case 'Nearby':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      case 'Delayed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ==============================================
  // MAP
  // ==============================================
 
  // ==============================================
  // ORDER DETAILS
  // ==============================================
  Widget _buildOrderDetails(Color primaryColor, Color darkColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                    ),
                    Text(
                      'From ${widget.locationName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '\$${widget.total.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.grey[400],
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.deliveryAddress,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_routeDistance.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.route,
                  color: Colors.grey[400],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Route: $_routeDistance • $_routeDuration',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.grey[400],
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Estimated Delivery: $_totalDeliveryTime min',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isOrderDelivered)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _remainingSeconds = _totalDeliveryTime * 60;
                    _isTimerRunning = false;
                    _timer?.cancel();
                    _startTimer();
                    _driverRouteIndex = 0;
                    _startDriverMovement();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor.withOpacity(0.08),
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Refresh Tracking',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}