import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final X25519 _x25519 = X25519();
  final Cipher _aead = Chacha20.poly1305Aead();
  final Hmac _hmac = Hmac.sha256();

  static const String _hkdfSaltStr = "mini-signal-salt";
  static String hkdfInfoForChat(String chatId) => "chat:$chatId";

  final Random _rng = Random.secure();

  // ---------- Identity keys ----------

  Future<SimpleKeyPairData> generateIdentityKeyPair() async {
    final kp = await _x25519.newKeyPair();
    return await kp.extract();
  }

  Future<String> exportPublicKeyB64(SimpleKeyPairData myKeyPair) async {
    return base64Encode(myKeyPair.publicKey.bytes); // raw32
  }

  SimplePublicKey importPublicKeyB64(String b64) {
    final raw = base64Decode(b64);
    return SimplePublicKey(raw, type: KeyPairType.x25519);
  }

  // ---------- HKDF-SHA256 (manual) ----------

  Future<List<int>> _hmacSha256(List<int> key, List<int> data) async {
    final mac = await _hmac.calculateMac(data, secretKey: SecretKey(key));
    return mac.bytes;
  }

  Future<List<int>> _hkdfExtract({
    required List<int> salt,
    required List<int> ikm,
  }) async {
    // PRK = HMAC(salt, IKM)
    return _hmacSha256(salt, ikm);
  }

  Future<List<int>> _hkdfExpand({
    required List<int> prk,
    required List<int> info,
    required int length,
  }) async {
    // HKDF-Expand:
    // T(0) = empty
    // T(1) = HMAC(PRK, T(0) || info || 0x01)
    // ...
    final out = <int>[];
    var t = <int>[];
    var counter = 1;

    while (out.length < length) {
      final input = <int>[...t, ...info, counter];
      t = await _hmacSha256(prk, input);
      out.addAll(t);
      counter++;
      if (counter > 255) {
        throw StateError("HKDF counter overflow");
      }
    }
    return out.sublist(0, length);
  }

  Future<SecretKey> deriveSessionKey({
    required SimpleKeyPairData myKeyPair,
    required SimplePublicKey peerPublicKey,
    required String chatId,
  }) async {
    // 1) ECDH shared secret
    final shared = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: peerPublicKey,
    );
    final ikm = await shared.extractBytes();

    // 2) HKDF-Extract + HKDF-Expand
    final salt = utf8.encode(_hkdfSaltStr);
    final info = utf8.encode(hkdfInfoForChat(chatId));

    final prk = await _hkdfExtract(salt: salt, ikm: ikm);
    final okm = await _hkdfExpand(prk: prk, info: info, length: 32);

    return SecretKey(okm);
  }

  // ---------- AEAD ----------

  List<int> _randomNonce12() {
    return List<int>.generate(12, (_) => _rng.nextInt(256));
  }

  Future<Map<String, String>> encryptMessage({
    required SecretKey sessionKey,
    required String plaintext,
    required String aad,
  }) async {
    final nonce = _randomNonce12();

    final secretBox = await _aead.encrypt(
      utf8.encode(plaintext),
      secretKey: sessionKey,
      nonce: nonce,
      aad: utf8.encode(aad),
    );

    // ciphertext + 16-byte tag
    final ct = secretBox.cipherText;
    final tag = secretBox.mac.bytes;
    final ctAndTag = <int>[...ct, ...tag];

    return {
      "nonce_b64": base64Encode(nonce),
      "ciphertext_b64": base64Encode(ctAndTag),
    };
  }

  Future<String> decryptMessage({
    required SecretKey sessionKey,
    required String nonceB64,
    required String ciphertextB64,
    required String aad,
  }) async {
    final nonce = base64Decode(nonceB64);
    final ctAndTag = base64Decode(ciphertextB64);

    if (ctAndTag.length < 16) {
      throw StateError("Ciphertext too short");
    }

    final ct = ctAndTag.sublist(0, ctAndTag.length - 16);
    final tag = ctAndTag.sublist(ctAndTag.length - 16);

    final box = SecretBox(ct, nonce: nonce, mac: Mac(tag));

    final clear = await _aead.decrypt(
      box,
      secretKey: sessionKey,
      aad: utf8.encode(aad),
    );

    return utf8.decode(clear);
  }
}
