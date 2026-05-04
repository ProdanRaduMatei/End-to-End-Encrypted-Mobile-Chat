import 'package:flutter/material.dart';
import '../api.dart';
import '../auth_store.dart';
import '../config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthMode { login, register }

class _LoginScreenState extends State<LoginScreen> {
  // CHANGE THIS IF NEEDED:
  // Android emulator: http://10.0.2.2:8000
  // iOS simulator: http://localhost:8000
  // Physical device: http://<your-laptop-ip>:8000
  final Api api = Api(AppConfig.baseUrl);
  final AuthStore auth = AuthStore();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      _snack("Enter a valid email.");
      return;
    }
    if (pass.length < 6) {
      _snack("Password must be at least 6 characters.");
      return;
    }

    setState(() => _loading = true);

    try {
      final res = _mode == _AuthMode.login
          ? await api.login(email, pass)
          : await api.register(email, pass);

      final token = res["access_token"] as String;
      final userId = res["user_id"] as int;
      final userEmail = res["email"] as String;

      await auth.saveSession(token: token, userId: userId, email: userEmail);

      // Ensure identity keypair exists and upload public key.
      final pubKeyB64 = await auth.myPublicKeyB64();
      await api.uploadKey(token, pubKeyB64);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/connections');
    } catch (e) {
      _snack("Auth failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Icon(Icons.lock_outline, size: 44, color: cs.primary),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onLongPress: _openDevMenu,
                    child: Text(
                      "Mini-Signal",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "End-to-end encrypted chat",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Mode switch
                  SegmentedButton<_AuthMode>(
                    segments: const [
                      ButtonSegment(
                        value: _AuthMode.login,
                        label: Text("Login"),
                      ),
                      ButtonSegment(
                        value: _AuthMode.register,
                        label: Text("Register"),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() => _mode = v.first),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: "Password",
                              prefixIcon: Icon(Icons.password_outlined),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _mode == _AuthMode.login
                                          ? "Sign in"
                                          : "Create account",
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () async {
                                    // DEV: auto-register/login a disposable account
                                    final devEmail = "dev@mini-signal.local";
                                    final devPass = "devpass123";

                                    setState(() => _loading = true);
                                    try {
                                      // Try login first
                                      Map<String, dynamic> res;
                                      try {
                                        res = await api.login(
                                          devEmail,
                                          devPass,
                                        );
                                      } catch (_) {
                                        // If login fails, register then login
                                        await api.register(devEmail, devPass);
                                        res = await api.login(
                                          devEmail,
                                          devPass,
                                        );
                                      }

                                      final token =
                                          res["access_token"] as String;
                                      final userId = res["user_id"] as int;
                                      final userEmail = res["email"] as String;

                                      await auth.saveSession(
                                        token: token,
                                        userId: userId,
                                        email: userEmail,
                                      );

                                      final pubKeyB64 = await auth
                                          .myPublicKeyB64();
                                      await api.uploadKey(token, pubKeyB64);

                                      if (!mounted) return;
                                      Navigator.of(
                                        context,
                                      ).pushReplacementNamed('/users');
                                    } catch (e) {
                                      _snack(
                                        "Dev login failed: ${e.toString()}",
                                      );
                                    } finally {
                                      if (mounted)
                                        setState(() => _loading = false);
                                    }
                                  },
                            child: const Text("Dev: skip login"),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),
                  Text(
                    "Crypto on-device • Server stores ciphertext only",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _devEnsureSessionAndGoUsers() async {
    // DEV: auto-register/login a disposable account so /users has a valid JWT
    final devEmail = "dev@mini-signal.local";
    final devPass = "devpass123";

    setState(() => _loading = true);
    try {
      Map<String, dynamic> res;
      try {
        res = await api.login(devEmail, devPass);
      } catch (_) {
        await api.register(devEmail, devPass);
        res = await api.login(devEmail, devPass);
      }

      final token = res["access_token"] as String;
      final userId = res["user_id"] as int;
      final userEmail = res["email"] as String;

      await auth.saveSession(token: token, userId: userId, email: userEmail);

      // ensure identity key exists + upload public key
      final pubKeyB64 = await auth.myPublicKeyB64();
      await api.uploadKey(token, pubKeyB64);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/users');
    } catch (e) {
      _snack("Dev shortcut failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDevMenu() async {
    if (_loading) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Developer Menu",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, "users"),
                  child: const Text("Go to Users (auto-login)"),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, "chat"),
                  child: const Text(
                    "Go to Chat (auto-login + open sample chat)",
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Tip: This menu is opened by long-pressing the app title.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == "users") {
      await _devEnsureSessionAndGoUsers();
    } else if (action == "chat") {
      // Ensure session first, then navigate to chat after users loads
      await _devEnsureSessionAndGoUsers();
      // Chat requires arguments; best to open Users first and pick a user.
      // If you really want instant chat, implement a "dev quick chat" from Users.
      _snack("Pick a user from the Users list to open Chat.");
    }
  }
}
