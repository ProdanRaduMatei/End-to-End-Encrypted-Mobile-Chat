import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  final String baseUrl;
  Api(this.baseUrl);

  Future<Map<String, dynamic>> register(String email, String password) async {
    final r = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> uploadKey(String token, String publicKeyB64) async {
    final r = await http.post(
      Uri.parse("$baseUrl/keys"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"public_key_b64": publicKeyB64}),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<Map<String, dynamic>> getKey(String token, int userId) async {
    final r = await http.get(
      Uri.parse("$baseUrl/keys/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listUsers(String token) async {
    final r = await http.get(
      Uri.parse("$baseUrl/users"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<void> sendMessage({
    required String token,
    required int toUserId,
    required String chatId,
    required String nonceB64,
    required String ciphertextB64,
    required int timestamp,
  }) async {
    final r = await http.post(
      Uri.parse("$baseUrl/messages/send"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "to_user_id": toUserId,
        "chat_id": chatId,
        "nonce_b64": nonceB64,
        "ciphertext_b64": ciphertextB64,
        "timestamp": timestamp,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<List<dynamic>> inbox(String token) async {
    final r = await http.get(
      Uri.parse("$baseUrl/messages/inbox"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    return (decoded["messages"] as List<dynamic>);
  }
}
