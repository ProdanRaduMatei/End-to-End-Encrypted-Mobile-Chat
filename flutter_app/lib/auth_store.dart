import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';

class AuthStore {
  final _storage = const FlutterSecureStorage();
  final _crypto = CryptoService();

  static const _kToken = "jwt_token";
  static const _kUserId = "user_id";
  static const _kEmail = "email";

  // stores JSON: {"privateKeyB64":"...","publicKeyB64":"..."}
  static const _kKeypairJson = "x25519_keypair_json";

  static const _kContacts = "contacts_json";

  // ---------------- Session ----------------

  Future<void> saveSession({
    required String token,
    required int userId,
    required String email,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUserId, value: userId.toString());
    await _storage.write(key: _kEmail, value: email.trim().toLowerCase());
  }

  Future<String?> token() => _storage.read(key: _kToken);

  Future<int?> userId() async {
    final v = await _storage.read(key: _kUserId);
    return v == null ? null : int.tryParse(v);
  }

  Future<String?> email() => _storage.read(key: _kEmail);

  // ---------------- Crypto identity ----------------
  //
  // IMPORTANT: Use SimpleKeyPairData everywhere (it contains private bytes + public key).
  //

  Future<SimpleKeyPairData> getOrCreateIdentityKeyPair() async {
    final existing = await _storage.read(key: _kKeypairJson);

    if (existing != null && existing.isNotEmpty) {
      final m = jsonDecode(existing) as Map<String, dynamic>;
      final privBytes = base64Decode(m["privateKeyB64"] as String);
      final pubBytes = base64Decode(m["publicKeyB64"] as String);

      return SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    }

    // Generate new identity keypair (already extracted)
    final kp = await _crypto.generateIdentityKeyPair(); // SimpleKeyPairData
    final pubB64 = await _crypto.exportPublicKeyB64(kp);

    final payload = jsonEncode({
      "privateKeyB64": base64Encode(kp.bytes), // kp.bytes = private key raw32
      "publicKeyB64": pubB64, // raw32 public key
    });

    await _storage.write(key: _kKeypairJson, value: payload);
    return kp;
  }

  Future<String> myPublicKeyB64() async {
    final kp = await getOrCreateIdentityKeyPair();
    return _crypto.exportPublicKeyB64(kp);
  }

  /// DEV helper: import exact keypair json (useful for seeding/demo)
  Future<void> devImportIdentityKeyPairJson(String json) async {
    await _storage.write(key: _kKeypairJson, value: json);
  }

  // ---------------- Contacts ----------------

  Future<List<Map<String, dynamic>>> getContacts() async {
    final raw = await _storage.read(key: _kContacts);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list;
  }

  Future<void> saveContacts(List<Map<String, dynamic>> contacts) async {
    await _storage.write(key: _kContacts, value: jsonEncode(contacts));
  }

  Future<void> upsertContact({
    required int id,
    required String email,
    required String publicKeyB64,
    required String fingerprint,
    required bool verified,
  }) async {
    final contacts = await getContacts();
    final idx = contacts.indexWhere((c) => c["id"] == id);

    final entry = {
      "id": id,
      "email": email.trim().toLowerCase(),
      "public_key_b64": publicKeyB64,
      "fingerprint": fingerprint,
      "verified": verified,
      "added_at": DateTime.now().millisecondsSinceEpoch,
    };

    if (idx >= 0) {
      contacts[idx] = entry;
    } else {
      contacts.add(entry);
    }

    contacts.sort(
      (a, b) => (b["added_at"] as int).compareTo(a["added_at"] as int),
    );
    await saveContacts(contacts);
  }

  Future<void> deleteContact(int id) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c["id"] == id);
    await saveContacts(contacts);
  }

  // ---------------- Reset / Logout ----------------

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  /// Useful if you want to keep session but reset crypto + contacts
  Future<void> devResetCryptoAndContacts() async {
    await _storage.delete(key: _kKeypairJson);
    await _storage.delete(key: _kContacts);
  }
}
