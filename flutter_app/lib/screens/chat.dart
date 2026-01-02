import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../api.dart';
import '../auth_store.dart';
import '../crypto_service.dart';
import '../config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  final bool isMine;
  final String text;
  final int timestamp;
  final int? fromId;

  _ChatMessage({
    required this.isMine,
    required this.text,
    required this.timestamp,
    this.fromId,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final Api api = Api(AppConfig.baseUrl);
  final AuthStore auth = AuthStore();
  final CryptoService crypto = CryptoService();

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _sending = false;
  String? _error;

  int? _myId;

  int? _peerId;
  String? _peerEmail;

  String? _chatId; // canonical "minId_maxId"
  dynamic _sessionKey; // SecretKey from cryptography (kept dynamic)

  final List<_ChatMessage> _messages = [];

  bool _didInit = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    // Safe: route args available here
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _canonicalChatId(int a, int b) {
    final lo = min(a, b);
    final hi = max(a, b);
    return "${lo}_$hi";
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is! Map) {
        throw Exception("Missing chat arguments.");
      }
      if (args["peerId"] == null || args["peerEmail"] == null) {
        throw Exception("Missing chat arguments (peerId/peerEmail).");
      }

      _peerId = args["peerId"] as int;
      _peerEmail = args["peerEmail"] as String;

      final token = await auth.token();
      final myId = await auth.userId();

      if (token == null || myId == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      _myId = myId;
      _chatId = _canonicalChatId(myId, _peerId!);

      // Ensure my identity keypair exists
      final myKeyPair = await auth.getOrCreateIdentityKeyPair();

      // ✅ Load peer public key from locally stored contact first, fallback to server
      String? peerPubB64;
      final contacts = await auth.getContacts();
      final stored = contacts.where((c) => c["id"] == _peerId).toList();
      if (stored.isNotEmpty) {
        peerPubB64 = stored.first["public_key_b64"] as String?;
      }

      if (peerPubB64 == null || peerPubB64.isEmpty) {
        final peerKeyRes = await api.getKey(token, _peerId!);
        peerPubB64 = peerKeyRes["public_key_b64"] as String?;
      }

      if (peerPubB64 == null || peerPubB64.isEmpty) {
        throw Exception("Peer has no public key uploaded.");
      }

      final peerPub = crypto.importPublicKeyB64(peerPubB64);

      // Derive session key from X25519 + HKDF(chatId)
      _sessionKey = await crypto.deriveSessionKey(
        myKeyPair: myKeyPair,
        peerPublicKey: peerPub,
        chatId: _chatId!,
      );

      setState(() => _loading = false);

      await _refreshInbox();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshInbox() async {
    final token = await auth.token();
    if (token == null || _myId == null || _chatId == null) return;

    try {
      final raw = await api.inbox(token);

      final filtered = raw.where((m) {
        final chatId = m["chat_id"] as String;
        return chatId == _chatId;
      }).toList();

      final incoming = <_ChatMessage>[];
      for (final m in filtered) {
        final senderId = m["sender_id"] as int;
        final nonceB64 = m["nonce_b64"] as String;
        final ctB64 = m["ciphertext_b64"] as String;
        final ts = m["timestamp"] as int;

        // Must match sender AAD
        final aad = "${_chatId!}|from:$senderId|to:${_myId!}";

        try {
          final text = await crypto.decryptMessage(
            sessionKey: _sessionKey,
            nonceB64: nonceB64,
            ciphertextB64: ctB64,
            aad: aad,
          );
          incoming.add(
            _ChatMessage(
              isMine: false,
              text: text,
              timestamp: ts,
              fromId: senderId,
            ),
          );
        } catch (_) {
          incoming.add(
            _ChatMessage(
              isMine: false,
              text: "⚠️ Message failed authentication / decryption",
              timestamp: ts,
              fromId: senderId,
            ),
          );
        }
      }

      // Backend inbox returns only received messages; keep local sent messages
      final mine = _messages.where((x) => x.isMine).toList();
      final merged = [...mine, ...incoming]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
      });

      _scrollToBottom();
    } catch (e) {
      _snack("Refresh failed: ${e.toString()}");
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    if (_sessionKey == null ||
        _myId == null ||
        _peerId == null ||
        _chatId == null) {
      _snack("Chat not ready yet.");
      return;
    }

    final token = await auth.token();
    if (token == null) return;

    setState(() => _sending = true);

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // AAD binds chat metadata
      final aad = "${_chatId!}|from:${_myId!}|to:${_peerId!}";

      final enc = await crypto.encryptMessage(
        sessionKey: _sessionKey,
        plaintext: text,
        aad: aad,
      );

      await api.sendMessage(
        token: token,
        toUserId: _peerId!,
        chatId: _chatId!,
        nonceB64: enc["nonce_b64"]!,
        ciphertextB64: enc["ciphertext_b64"]!,
        timestamp: ts,
      );

      setState(() {
        _messages.add(_ChatMessage(isMine: true, text: text, timestamp: ts));
      });

      _msgCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      _snack("Send failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_peerEmail ?? "Chat"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loading ? null : _refreshInbox,
            icon: const Icon(Icons.refresh),
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
                        "Could not open chat",
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
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _sessionKey = null;
                            _loading = true;
                            _messages.clear();
                          });
                          _init();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "E2EE enabled • Server stores ciphertext only",
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final align = m.isMine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start;
                        final bubbleColor = m.isMine
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest;
                        final textColor = m.isMine
                            ? cs.onPrimaryContainer
                            : cs.onSurface;

                        final time = DateFormat.Hm().format(
                          DateTime.fromMillisecondsSinceEpoch(m.timestamp),
                        );

                        return Column(
                          crossAxisAlignment: align,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 520),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.text,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      color: textColor.withAlpha(166),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sending ? null : _send(),
                            decoration: InputDecoration(
                              hintText: "Message",
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 46,
                          width: 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _sending ? null : _send,
                            child: _sending
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
