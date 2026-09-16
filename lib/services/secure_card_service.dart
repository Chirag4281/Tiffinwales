import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure card storage using:
/// - iOS: Keychain (hardware-encrypted, app sandbox)
/// - Android: EncryptedSharedPreferences (backed by Keystore)
class SecureCardService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Optional: require device to be unlocked to read
      // resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // This means: value readable only on THIS device, after first unlock post-reboot
      synchronizable: false,
    ),
  );

  static const _kCardNumber = 'card_number_v1';
  static const _kExpiry = 'card_expiry_v1';
  static const _kHolderName = 'card_holder_v1';
  static const _kLast4 = 'card_last4_v1';
  static const _kBrand = 'card_brand_v1';
  static const _kHasSaved = 'card_has_saved_v1';

  /// Save card details securely.
  /// ⚠️ Never pass CVV here — CVV must NEVER be stored.
  static Future<void> saveCard({
    required String cardNumber,
    required String expiry,
    required String holderName,
  }) async {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\s+'), '');
    final last4 = cleanNumber.length >= 4
        ? cleanNumber.substring(cleanNumber.length - 4)
        : cleanNumber;
    final brand = _detectBrand(cleanNumber);

    await Future.wait([
      _storage.write(key: _kCardNumber, value: cleanNumber),
      _storage.write(key: _kExpiry, value: expiry),
      _storage.write(key: _kHolderName, value: holderName),
      _storage.write(key: _kLast4, value: last4),
      _storage.write(key: _kBrand, value: brand),
      _storage.write(key: _kHasSaved, value: 'true'),
    ]);
  }

  /// Load saved card. Returns null if nothing is saved.
  static Future<SavedCard?> loadCard() async {
    final hasSaved = await _storage.read(key: _kHasSaved);
    if (hasSaved != 'true') return null;

    final number = await _storage.read(key: _kCardNumber);
    final expiry = await _storage.read(key: _kExpiry);
    final holder = await _storage.read(key: _kHolderName);
    final last4 = await _storage.read(key: _kLast4);
    final brand = await _storage.read(key: _kBrand);

    if (number == null || expiry == null) return null;

    return SavedCard(
      cardNumber: number,
      expiry: expiry,
      holderName: holder ?? '',
      last4: last4 ?? '****',
      brand: brand ?? 'Card',
    );
  }

  /// Returns a lightweight display object (safe for UI) without the full number.
  static Future<SavedCardDisplay?> loadDisplayInfo() async {
    final hasSaved = await _storage.read(key: _kHasSaved);
    if (hasSaved != 'true') return null;

    final last4 = await _storage.read(key: _kLast4);
    final brand = await _storage.read(key: _kBrand);
    final expiry = await _storage.read(key: _kExpiry);
    final holder = await _storage.read(key: _kHolderName);

    return SavedCardDisplay(
      last4: last4 ?? '****',
      brand: brand ?? 'Card',
      expiry: expiry ?? 'MM/YY',
      holderName: holder ?? '',
    );
  }

  static Future<void> clearCard() async {
    await Future.wait([
      _storage.delete(key: _kCardNumber),
      _storage.delete(key: _kExpiry),
      _storage.delete(key: _kHolderName),
      _storage.delete(key: _kLast4),
      _storage.delete(key: _kBrand),
      _storage.delete(key: _kHasSaved),
    ]);
  }

  static Future<bool> hasSavedCard() async {
    final v = await _storage.read(key: _kHasSaved);
    return v == 'true';
  }

  static String _detectBrand(String number) {
    if (number.startsWith('4')) return 'Visa';
    if (RegExp(r'^5[1-5]').hasMatch(number)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(number)) return 'Amex';
    if (RegExp(r'^6(?:011|5)').hasMatch(number)) return 'Discover';
    if (RegExp(r'^3(?:0[0-5]|[68])').hasMatch(number)) return 'Diners';
    if (RegExp(r'^35').hasMatch(number)) return 'JCB';
    return 'Card';
  }
}

class SavedCard {
  final String cardNumber;
  final String expiry;
  final String holderName;
  final String last4;
  final String brand;

  SavedCard({
    required this.cardNumber,
    required this.expiry,
    required this.holderName,
    required this.last4,
    required this.brand,
  });
}

class SavedCardDisplay {
  final String last4;
  final String brand;
  final String expiry;
  final String holderName;

  SavedCardDisplay({
    required this.last4,
    required this.brand,
    required this.expiry,
    required this.holderName,
  });
}