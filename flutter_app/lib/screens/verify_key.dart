import 'package:flutter/material.dart';

class VerifyKeyScreen extends StatelessWidget {
  const VerifyKeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final args = ModalRoute.of(context)!.settings.arguments as Map;

    final peerEmail = args["peerEmail"] as String;
    final fingerprint = args["fingerprint"] as String;

    return Scaffold(
      appBar: AppBar(title: const Text("Verify key")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Verify $peerEmail",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Compare this fingerprint with your contact (in person or via a trusted channel). "
                    "If it matches, mark as verified to reduce MITM risk.",
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: SelectableText(
                      fingerprint,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Not now"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text("Mark verified"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
