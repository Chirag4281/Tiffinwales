// lib/services/support_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

// ============================================================
// DATA MODEL
// ============================================================
class SupportInfo {
  final String phone;
  final String whatsapp;
  final String email;
  final String address;
  final String openingTime;
  final String closingTime;
  final String openingDays;
  final String averageResponse;
  final bool isOpenNow;

  SupportInfo({
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.address,
    required this.openingTime,
    required this.closingTime,
    required this.openingDays,
    required this.averageResponse,
    required this.isOpenNow,
  });

  factory SupportInfo.fromJson(Map<String, dynamic> j) {
    return SupportInfo(
      phone:           (j['phone'] ?? '').toString(),
      whatsapp:        (j['whatsapp'] ?? '').toString(),
      email:           (j['email'] ?? '').toString(),
      address:         (j['address'] ?? '').toString(),
      openingTime:     (j['opening_time'] ?? '').toString(),
      closingTime:     (j['closing_time'] ?? '').toString(),
      openingDays:     (j['opening_days'] ?? '').toString(),
      averageResponse: (j['average_response'] ?? 'under 5 minutes').toString(),
      isOpenNow:       j['is_open_now'] == true,
    );
  }

  SupportInfo copyWith({
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    String? openingTime,
    String? closingTime,
    String? openingDays,
    String? averageResponse,
    bool? isOpenNow,
  }) {
    return SupportInfo(
      phone:           phone           ?? this.phone,
      whatsapp:        whatsapp        ?? this.whatsapp,
      email:           email           ?? this.email,
      address:         address         ?? this.address,
      openingTime:     openingTime     ?? this.openingTime,
      closingTime:     closingTime     ?? this.closingTime,
      openingDays:     openingDays     ?? this.openingDays,
      averageResponse: averageResponse ?? this.averageResponse,
      isOpenNow:       isOpenNow       ?? this.isOpenNow,
    );
  }

  /// "09:00:00" → "9:00 AM"
  static String prettyTime(String hms) {
    if (hms.isEmpty) return '';
    try {
      final p = hms.split(':');
      final h = int.parse(p[0]);
      final m = p.length > 1 ? int.parse(p[1]) : 0;
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:${m.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return hms;
    }
  }
}

// ============================================================
// SERVICE
// ============================================================
class SupportService {
  static const String _apiUrl =
      'https://quantorra.co/tiffinwales/support_info.php';

  // ----------------------------------------------------------
  // CUSTOMER / MANAGER READ — returns SupportInfo or null
  // ----------------------------------------------------------
  static Future<SupportInfo?> fetch(String locationName) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      req.fields['action']        = 'get_support_info';
      req.fields['location_name'] = locationName;

      final res  = await req.send().timeout(const Duration(seconds: 15));
      final body = await res.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] == 'success' && data['data'] != null) {
        return SupportInfo.fromJson(Map<String, dynamic>.from(data['data']));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------
  // MANAGER UPDATE — returns null on success, error string on fail
  // Requires the manager's email so the PHP can authorize the branch.
  // ----------------------------------------------------------
  static Future<String?> update({
    required String locationName,
    required String email,
    required String supportPhone,
    required String supportWhatsapp,
    required String supportEmail,
    required String supportAddress,
    required String openingTime,   // "HH:MM" or "HH:MM:SS"
    required String closingTime,   // "HH:MM" or "HH:MM:SS"
    required String openingDays,
    required String averageResponse,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      req.fields['action']           = 'update_support_info';
      req.fields['location_name']    = locationName;
      req.fields['email']            = email;
      req.fields['support_phone']    = supportPhone;
      req.fields['support_whatsapp'] = supportWhatsapp;
      req.fields['support_email']    = supportEmail;
      req.fields['support_address']  = supportAddress;
      req.fields['opening_time']     = openingTime;
      req.fields['closing_time']     = closingTime;
      req.fields['opening_days']     = openingDays;
      req.fields['average_response'] = averageResponse;

      final res  = await req.send().timeout(const Duration(seconds: 15));
      final body = await res.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] == 'success') return null;
      return (data['message'] ?? 'Update failed').toString();
    } catch (e) {
      return 'Network error: $e';
    }
  }

  // ----------------------------------------------------------
  // OPTIONAL — Same as update() but returns the refreshed row
  // on success. Useful if your tab wants to show live "is_open_now".
  // ----------------------------------------------------------
  static Future<SupportInfo?> updateAndRefresh({
    required String locationName,
    required String email,
    required String supportPhone,
    required String supportWhatsapp,
    required String supportEmail,
    required String supportAddress,
    required String openingTime,
    required String closingTime,
    required String openingDays,
    required String averageResponse,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      req.fields['action']           = 'update_support_info';
      req.fields['location_name']    = locationName;
      req.fields['email']            = email;
      req.fields['support_phone']    = supportPhone;
      req.fields['support_whatsapp'] = supportWhatsapp;
      req.fields['support_email']    = supportEmail;
      req.fields['support_address']  = supportAddress;
      req.fields['opening_time']     = openingTime;
      req.fields['closing_time']     = closingTime;
      req.fields['opening_days']     = openingDays;
      req.fields['average_response'] = averageResponse;

      final res  = await req.send().timeout(const Duration(seconds: 15));
      final body = await res.stream.bytesToString();
      final data = json.decode(body);

      if (data['status'] == 'success' && data['data'] != null) {
        return SupportInfo.fromJson(Map<String, dynamic>.from(data['data']));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}