import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../auth_store.dart';
import 'dart:developer' as dev;
import '../config.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  // CHANGE per device:
  final Api api = Api(AppConfig.baseUrl);
  final AuthStore auth = AuthStore();

  bool _loading = true;
  List<Map<String, dynamic>> _contacts = [];
  String? _myEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fingerprintFromPubKeyB64(String publicKeyB64) {
    final bytes = base64Decode(publicKeyB64);
    final digest = sha256.convert(bytes).bytes;

    // hex with grouping: abcd ef01 ...
    final hex = digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final groups = <String>[];
    for (int i = 0; i < hex.length; i += 4) {
      groups.add(hex.substring(i, (i + 4).clamp(0, hex.length)));
    }
    return groups.join(' ');
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final token = await auth.token();
    final email = await auth.email();
    if (token == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    final contacts = await auth.getContacts();
    setState(() {
      _contacts = contacts;
      _myEmail = email;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _addConnectionByEmail() async {
    final ctrl = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add connection"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: "friend@example.com",
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text("Look up"),
          ),
        ],
      ),
    );

    dev.log("LOOKUP: dialog returned = $email");

    if (email == null || email.isEmpty) {
      dev.log("LOOKUP: cancelled or empty");
      return;
    }

    final token = await auth.token();
    dev.log("LOOKUP: token exists = ${token != null}");

    if (token == null) {
      _snack("Not authenticated");
      return;
    }

    try {
      dev.log("LOOKUP: calling backend for $email");
      final res = await api.getUserByEmail(token, email);
      dev.log("LOOKUP: backend response = $res");

      final id = res["id"] as int;
      final foundEmail = res["email"] as String;
      final pub = res["public_key_b64"] as String?;

      if (pub == null || pub.isEmpty) {
        _snack("User has no public key yet.");
        return;
      }

      final fp = _fingerprintFromPubKeyB64(pub);
      dev.log("LOOKUP: fingerprint = $fp");

      if (!mounted) return;

      dev.log("LOOKUP: navigating to /verify");
      final verified = await Navigator.of(context).pushNamed(
        '/verify',
        arguments: {
          "peerId": id,
          "peerEmail": foundEmail,
          "publicKeyB64": pub,
          "fingerprint": fp,
        },
      );

      dev.log("LOOKUP: verify returned = $verified");

      await auth.upsertContact(
        id: id,
        email: foundEmail,
        publicKeyB64: pub,
        fingerprint: fp,
        verified: verified == true,
      );

      dev.log("LOOKUP: contact saved");
      await _load();

      _snack("Connection added");
    } catch (e, st) {
      dev.log("LOOKUP ERROR", error: e, stackTrace: st);
      _snack("Lookup failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Connections"),
        actions: [
          IconButton(
            tooltip: "Add",
            onPressed: _loading ? null : _addConnectionByEmail,
            icon: const Icon(Icons.person_add_alt_1),
          ),
          IconButton(
            tooltip: "Logout",
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                children: [
                  if (_myEmail != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        "Signed in as $_myEmail",
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_contacts.isEmpty)
                    Card(
                      elevation: 0,
                      color: cs.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "No connections yet",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Add a friend by email to start an end-to-end encrypted chat.",
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _addConnectionByEmail,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text("Add connection"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ..._contacts.map((c) {
                    final id = c["id"] as int;
                    final email = c["email"] as String;
                    final verified = (c["verified"] as bool?) ?? false;

                    return Card(
                      elevation: 0,
                      color: cs.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        title: Text(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          verified ? "Verified key" : "Unverified key",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (verified)
                              Icon(Icons.verified_rounded, color: cs.primary),
                            IconButton(
                              tooltip: "Delete",
                              onPressed: () async {
                                await auth.deleteContact(id);
                                await _load();
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/chat',
                            arguments: {"peerId": id, "peerEmail": email},
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Text(
                    "Security note: verify keys to prevent server MITM.",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
