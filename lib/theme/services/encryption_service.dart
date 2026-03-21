// lib/theme/services/encryption_service.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CBC field-level encryption for sensitive database columns.
///
/// The key is generated on first launch and stored in platform secure storage
/// (Android Keystore / iOS Keychain). Each encrypted value embeds a random
/// 16-byte IV so identical plaintexts produce different ciphertexts.
///
/// Encrypted values are prefixed with [_prefix] so plaintext legacy values
/// (from before encryption was introduced) can be detected and returned as-is,
/// allowing a zero-downtime migration inside DatabaseService.onUpgrade.
class EncryptionService {
  static final EncryptionService instance = EncryptionService._();
  EncryptionService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyName = 'comic_vault_field_enc_key';
  static const _prefix  = '__enc__';

  Encrypter? _encrypter;

  Future<void> init() async {
    var keyBase64 = await _storage.read(key: _keyName);
    if (keyBase64 == null) {
      final key = Key.fromSecureRandom(32); // AES-256
      keyBase64 = base64Encode(key.bytes);
      await _storage.write(key: _keyName, value: keyBase64);
    }
    final key = Key(base64Decode(keyBase64));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  }

  /// Encrypts [value] and returns a prefixed base64 string, or returns [value]
  /// unchanged if it is null, empty, or the service is not yet initialised.
  String? encrypt(String? value) {
    if (value == null || value.isEmpty || _encrypter == null) return value;
    final iv        = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(value, iv: iv);
    // Prepend the 16-byte IV to the ciphertext so each call produces a unique output.
    final combined  = Uint8List(16 + encrypted.bytes.length)
      ..setAll(0, iv.bytes)
      ..setAll(16, encrypted.bytes);
    return '$_prefix${base64Encode(combined)}';
  }

  /// Decrypts a value produced by [encrypt], or returns [value] unchanged if
  /// it is null, empty, lacks the prefix (legacy plaintext), or fails to decrypt.
  String? decrypt(String? value) {
    if (value == null || value.isEmpty) return value;
    if (!value.startsWith(_prefix))    return value; // Legacy plaintext — pass through
    if (_encrypter == null)            return value;
    try {
      final combined  = base64Decode(value.substring(_prefix.length));
      final iv        = IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encrypted = Encrypted(Uint8List.fromList(combined.sublist(16)));
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (_) {
      return value; // Graceful degradation — never crash on a bad decrypt
    }
  }

  /// Convenience — reads a value from secure storage.
  static Future<String?> secureRead(String key) => _storage.read(key: key);

  /// Convenience — writes a value to secure storage.
  static Future<void> secureWrite(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Convenience — deletes a key from secure storage.
  static Future<void> secureDelete(String key) => _storage.delete(key: key);
}
