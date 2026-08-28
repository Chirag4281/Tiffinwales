import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddressService {
  static const String ADDRESS_KEY = 'delivery_address';
  static const String LAST_SYNC_KEY = 'last_address_sync';
  static const String PENDING_SYNC_KEY = 'pending_address_sync';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final String apiUrl = 'https://quantorra.co/tiffinwales/Address.php';

  // =============================================
  // Save Address (Hybrid: Local + Server)
  // =============================================
  Future<bool> saveAddress(String email, String address) async {
    try {
      // 1. Save locally first (encrypted)
      await _saveLocal(address);

      // 2. Try to save on server
      bool serverSaved = await _saveServer(email, address);

      if (!serverSaved) {
        // If server fails, mark for background sync
        await _markForSync(address);
      }

      return true;
    } catch (e) {
      print('Error saving address: $e');
      // Still save locally even if server fails
      await _saveLocal(address);
      await _markForSync(address);
      return false;
    }
  }

  // =============================================
  // Get Address (Local first, then server)
  // =============================================
  Future<String?> getAddress(String email) async {
    try {
      // 1. Try local first (instant)
      String? localAddress = await _getLocal();

      if (localAddress != null) {
        // 2. Background sync to check for updates
        _backgroundSync(email);
        return localAddress;
      }

      // 3. Fallback to server
      String? serverAddress = await _getServer(email);

      if (serverAddress != null) {
        // Save to local for next time
        await _saveLocal(serverAddress);
        return serverAddress;
      }

      return null;
    } catch (e) {
      print('Error getting address: $e');
      // Try local one more time as fallback
      return await _getLocal();
    }
  }

  // =============================================
  // Delete Address
  // =============================================
  Future<bool> deleteAddress(String email) async {
    try {
      // Delete local
      await _deleteLocal();

      // Delete from server
      await _deleteServer(email);

      return true;
    } catch (e) {
      print('Error deleting address: $e');
      return false;
    }
  }

  // =============================================
  // PRIVATE METHODS - Local Storage
  // =============================================

  Future<void> _saveLocal(String address) async {
    await _secureStorage.write(key: ADDRESS_KEY, value: address);
    // Update last sync time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LAST_SYNC_KEY, DateTime.now().toIso8601String());
  }

  Future<String?> _getLocal() async {
    return await _secureStorage.read(key: ADDRESS_KEY);
  }

  Future<void> _deleteLocal() async {
    await _secureStorage.delete(key: ADDRESS_KEY);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LAST_SYNC_KEY);
  }

  Future<void> _markForSync(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PENDING_SYNC_KEY, address);
  }

  Future<String?> _getPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PENDING_SYNC_KEY);
  }

  Future<void> _clearPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PENDING_SYNC_KEY);
  }

  // =============================================
  // PRIVATE METHODS - Server API
  // =============================================

  Future<bool> _saveServer(String email, String address) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'save_address';
      request.fields['email'] = email;
      request.fields['address'] = address;

      var response = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      print('Save Address Response: $data'); // For debugging

      return data['status'] == 'success';
    } catch (e) {
      print('Server save error: $e');
      return false;
    }
  }

  Future<String?> _getServer(String email) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'get_address';
      request.fields['email'] = email;

      var response = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      print('Get Address Response: $data'); // For debugging

      if (data['status'] == 'success' && data['data'] != null) {
        return data['data']['address'];
      }

      return null;
    } catch (e) {
      print('Server get error: $e');
      return null;
    }
  }

  Future<bool> _deleteServer(String email) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'delete_address';
      request.fields['email'] = email;

      var response = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      return data['status'] == 'success';
    } catch (e) {
      print('Server delete error: $e');
      return false;
    }
  }

  // =============================================
  // Background Sync
  // =============================================
  Future<void> _backgroundSync(String email) async {
    try {
      // Check if there's pending sync data
      String? pendingAddress = await _getPendingSync();
      if (pendingAddress != null) {
        // Try to sync pending data
        bool synced = await _saveServer(email, pendingAddress);
        if (synced) {
          await _clearPendingSync();
        }
        return;
      }

      // Check if local data is stale (more than 24 hours old)
      final prefs = await SharedPreferences.getInstance();
      String? lastSync = prefs.getString(LAST_SYNC_KEY);

      if (lastSync != null) {
        DateTime lastSyncTime = DateTime.parse(lastSync);
        if (DateTime.now().difference(lastSyncTime).inHours > 24) {
          // Fetch latest from server
          String? serverAddress = await _getServer(email);
          String? localAddress = await _getLocal();

          if (serverAddress != null && serverAddress != localAddress) {
            // Server has newer data
            await _saveLocal(serverAddress);
          }
        }
      }
    } catch (e) {
      print('Background sync error: $e');
    }
  }
}