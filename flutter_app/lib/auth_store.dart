import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';

class AuthStore {
  final _storage = const FlutterSecureStorage();
  final _crypto = CryptoService();

  static const _kToken = "jwt_token";
  static const _kUserId = "user_id";
  static const _kEmail = "email";
  static const _kPrivKey = "x25519_keypair_json";

  Future<void> saveSession({
    required String token,
    required int userId,
    required String email,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUserId, value: userId.toString());
    await _storage.write(key: _kEmail, value: email);
  }

  Future<String?> token() => _storage.read(key: _kToken);

  Future<int?> userId() async {
    final v = await _storage.read(key: _kUserId);
    return v == null ? null : int.tryParse(v);
  }

  Future<String?> email() => _storage.read(key: _kEmail);

  Future<SimpleKeyPair> getOrCreateIdentityKeyPair() async {
    final existing = await _storage.read(key: _kPrivKey);
    if (existing != null) {
      final m = jsonDecode(existing) as Map<String, dynamic>;
      final privBytes = base64Decode(m["privateKeyB64"] as String);
      final pubBytes = base64Decode(m["publicKeyB64"] as String);
      return SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    }

    final kp = await _crypto.generateIdentityKeyPair();
    final pubB64 = await _crypto.exportPublicKeyB64(kp);
    final extracted = await kp.extract();

    final payload = jsonEncode({
      "privateKeyB64": base64Encode(extracted.bytes),
      "publicKeyB64": pubB64,
    });

    await _storage.write(key: _kPrivKey, value: payload);
    return kp;
  }

  Future<String> myPublicKeyB64() async {
    final kp = await getOrCreateIdentityKeyPair();
    return _crypto.exportPublicKeyB64(kp);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
