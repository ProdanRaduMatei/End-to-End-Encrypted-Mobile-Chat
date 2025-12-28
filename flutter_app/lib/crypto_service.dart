import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final X25519 _x25519 = X25519();
  final Cipher _aead = Chacha20.poly1305Aead();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<SimpleKeyPair> generateIdentityKeyPair() async {
    return _x25519.newKeyPair();
  }

  Future<String> exportPublicKeyB64(SimpleKeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey();
    return base64Encode(Uint8List.fromList(pub.bytes));
  }

  SimplePublicKey importPublicKeyB64(String b64) {
    final bytes = base64Decode(b64);
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  Future<SecretKey> deriveSessionKey({
    required SimpleKeyPair myKeyPair,
    required SimplePublicKey peerPublicKey,
    required String chatId,
  }) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: peerPublicKey,
    );

    final salt = utf8.encode("mini-signal-salt");
    final info = utf8.encode("chat:$chatId");

    // cryptography package uses `nonce` for HKDF salt
    return _hkdf.deriveKey(secretKey: shared, nonce: salt, info: info);
  }

  Future<Map<String, String>> encryptMessage({
    required SecretKey sessionKey,
    required String plaintext,
    required String aad,
  }) async {
    final nonce = _aead.newNonce();
    final secretBox = await _aead.encrypt(
      utf8.encode(plaintext),
      secretKey: sessionKey,
      nonce: nonce,
      aad: utf8.encode(aad),
    );

    // Store cipherText || mac (16 bytes)
    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return {
      "nonce_b64": base64Encode(nonce),
      "ciphertext_b64": base64Encode(combined),
    };
  }

  Future<String> decryptMessage({
    required SecretKey sessionKey,
    required String nonceB64,
    required String ciphertextB64,
    required String aad,
  }) async {
    final nonce = base64Decode(nonceB64);
    final combined = base64Decode(ciphertextB64);

    if (combined.length < 17) {
      throw StateError("Ciphertext too short");
    }

    final macBytes = combined.sublist(combined.length - 16);
    final ct = combined.sublist(0, combined.length - 16);

    final secretBox = SecretBox(ct, nonce: nonce, mac: Mac(macBytes));

    final clear = await _aead.decrypt(
      secretBox,
      secretKey: sessionKey,
      aad: utf8.encode(aad),
    );

    return utf8.decode(clear);
  }
}
