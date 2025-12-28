import 'package:flutter/material.dart';
import '../api.dart';
import '../auth_store.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  // CHANGE THIS IF NEEDED:
  final Api api = Api("http://10.0.2.2:8000");
  final AuthStore auth = AuthStore();

  bool _loading = true;
  String? _error;
  List<dynamic> _users = [];

  int? _myId;
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await auth.token();
      final myId = await auth.userId();
      final myEmail = await auth.email();

      if (token == null || myId == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      final users = await api.listUsers(token);

      setState(() {
        _users = users;
        _myId = myId;
        _myEmail = myEmail;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _initials(String email) {
    final s = email.split('@').first;
    if (s.isEmpty) return "?";
    if (s.length == 1) return s[0].toUpperCase();
    return (s[0] + s[1]).toUpperCase();
  }

  Future<void> _logout() async {
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Users"),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
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
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Failed to load users",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                  ..._users.where((u) => (u["id"] as int?) != _myId).map((u) {
                    final id = u["id"] as int;
                    final email = u["email"] as String;
                    final hasKey = (u["hasKey"] as bool?) ?? false;

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
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.onPrimaryContainer,
                          child: Text(
                            _initials(email),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          hasKey
                              ? "Public key available"
                              : "No public key uploaded",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (!hasKey) {
                            _snack(
                              "This user has not uploaded a public key yet.",
                            );
                            return;
                          }
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
                    "Tip: For best security, add key verification (fingerprints/QR) as an extension.",
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
