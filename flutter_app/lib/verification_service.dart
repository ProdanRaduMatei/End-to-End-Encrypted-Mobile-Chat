import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VerificationService {
  final _storage = const FlutterSecureStorage();
  final _sha256 = Sha256();

  // Storage key for verification status: "verified_{chatId}" -> "true"/"false"
  static String _verifiedKey(String chatId) => "verified_$chatId";

  /// Generate a Safety Number (fingerprint) for a conversation
  /// This is deterministic and will be the same for both users
  /// 
  /// Algorithm (Signal-style):
  /// 1. Concatenate: version || publicKey1 || username1 || publicKey2 || username2
  /// 2. Hash with SHA-256
  /// 3. Convert to 60-digit decimal number (12 groups of 5)
  Future<String> generateSafetyNumber({
    required List<int> myPublicKeyBytes,
    required String myUsername,
    required List<int> theirPublicKeyBytes,
    required String theirUsername,
  }) async {
    // Version byte
    final version = [0x00];

    // Sort the keys/usernames to ensure both users get the same result
    // Use lexicographic ordering
    final List<int> data;
    if (_compareByteArrays(myPublicKeyBytes, theirPublicKeyBytes) < 0) {
      // My key comes first
      data = [
        ...version,
        ...myPublicKeyBytes,
        ...utf8.encode(myUsername),
        ...theirPublicKeyBytes,
        ...utf8.encode(theirUsername),
      ];
    } else {
      // Their key comes first
      data = [
        ...version,
        ...theirPublicKeyBytes,
        ...utf8.encode(theirUsername),
        ...myPublicKeyBytes,
        ...utf8.encode(myUsername),
      ];
    }

    // Hash the concatenated data
    final hash = await _sha256.hash(data);
    final hashBytes = hash.bytes;

    // Convert first 30 bytes of hash to a 60-digit number
    // We'll take bytes in groups and format as decimal
    final safetyNumber = _hashToDecimalString(hashBytes);

    return safetyNumber;
  }

  /// Convert hash bytes to a formatted 60-digit decimal string
  /// Format: XXXXX XXXXX XXXXX XXXXX XXXXX XXXXX (6 groups of 5)
  ///         XXXXX XXXXX XXXXX XXXXX XXXXX XXXXX
  String _hashToDecimalString(List<int> hashBytes) {
    // Take first 30 bytes, convert to decimal representation
    final buffer = StringBuffer();
    
    // Process in chunks of 5 bytes -> ~12 decimal digits each
    // We'll create 12 groups of 5 digits
    for (int i = 0; i < 30; i += 5) {
      if (i + 5 <= hashBytes.length) {
        // Take 5 bytes, convert to a number, then to 5-digit string
        final chunk = hashBytes.sublist(i, i + 5);
        final num = _bytesToNumber(chunk);
        // Modulo to get 5 digits (0-99999)
        final fiveDigits = (num % 100000).toString().padLeft(5, '0');
        buffer.write(fiveDigits);
        
        if (i < 25) {
          buffer.write(' '); // Add space between groups
        }
      }
    }

    return buffer.toString();
  }

  /// Convert byte array to a big number
  int _bytesToNumber(List<int> bytes) {
    int result = 0;
    for (var byte in bytes) {
      result = (result << 8) | byte;
    }
    return result;
  }

  /// Compare two byte arrays lexicographically
  int _compareByteArrays(List<int> a, List<int> b) {
    final minLen = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < minLen; i++) {
      if (a[i] != b[i]) {
        return a[i] - b[i];
      }
    }
    return a.length - b.length;
  }

  /// Format the safety number for display (6 groups per line, 2 lines)
  String formatSafetyNumber(String safetyNumber) {
    // Remove all spaces first
    final clean = safetyNumber.replaceAll(' ', '');
    
    if (clean.length != 60) {
      return safetyNumber; // Return as-is if not expected format
    }

    // Create 12 groups of 5 digits
    final groups = <String>[];
    for (int i = 0; i < 60; i += 5) {
      groups.add(clean.substring(i, i + 5));
    }

    // Format as two lines of 6 groups each
    final line1 = groups.sublist(0, 6).join(' ');
    final line2 = groups.sublist(6, 12).join(' ');

    return '$line1\n$line2';
  }

  /// Mark a chat as verified
  Future<void> markAsVerified(String chatId) async {
    await _storage.write(key: _verifiedKey(chatId), value: 'true');
  }

  /// Mark a chat as unverified
  Future<void> markAsUnverified(String chatId) async {
    await _storage.write(key: _verifiedKey(chatId), value: 'false');
  }

  /// Check if a chat is verified
  Future<bool> isVerified(String chatId) async {
    final value = await _storage.read(key: _verifiedKey(chatId));
    return value == 'true';
  }

  /// Generate QR code data (the safety number as a string)
  String generateQRData(String safetyNumber) {
    // Remove spaces for QR code
    return safetyNumber.replaceAll(' ', '').replaceAll('\n', '');
  }

  /// Compare scanned QR code with expected safety number
  bool verifySafetyNumberFromQR(String scannedData, String expectedSafetyNumber) {
    final cleanScanned = scannedData.replaceAll(' ', '').replaceAll('\n', '');
    final cleanExpected = expectedSafetyNumber.replaceAll(' ', '').replaceAll('\n', '');
    return cleanScanned == cleanExpected;
  }
}