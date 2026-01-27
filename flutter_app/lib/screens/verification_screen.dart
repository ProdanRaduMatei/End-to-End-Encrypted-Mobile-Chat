import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VerificationScreen extends StatefulWidget {
  final String safetyNumber;
  final String peerUsername;
  final bool isCurrentlyVerified;
  final Function(bool) onVerificationChanged;

  const VerificationScreen({
    Key? key,
    required this.safetyNumber,
    required this.peerUsername,
    required this.isCurrentlyVerified,
    required this.onVerificationChanged,
  }) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late bool _isVerified;

  @override
  void initState() {
    super.initState();
    _isVerified = widget.isCurrentlyVerified;
  }

  void _toggleVerification() {
    setState(() {
      _isVerified = !_isVerified;
    });
    widget.onVerificationChanged(_isVerified);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isVerified 
            ? 'Chat marked as verified ✓'
            : 'Chat marked as unverified',
        ),
        backgroundColor: _isVerified ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.safetyNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safety number copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format the safety number for display
    final formattedNumber = widget.safetyNumber;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Security'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Icon(
              _isVerified ? Icons.verified_user : Icons.security,
              size: 64,
              color: _isVerified ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Verify with ${widget.peerUsername}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              _isVerified 
                ? 'This conversation is verified'
                : 'This conversation is not verified',
              style: TextStyle(
                fontSize: 16,
                color: _isVerified ? Colors.green : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Information card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Compare this Safety Number',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Compare these numbers with your contact through a trusted channel (in person, phone call, etc.)',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Safety Number Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SelectableText(
                        formattedNumber,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Copy button
                    TextButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy, size: 20),
                      label: const Text('Copy to Clipboard'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // QR Code Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan this QR code with your contact to verify',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: QrImageView(
                        data: widget.safetyNumber.replaceAll(' ', '').replaceAll('\n', ''),
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Scan QR button (future enhancement)
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement QR scanning
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR scanning coming soon!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Verification toggle button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleVerification,
                icon: Icon(_isVerified ? Icons.close : Icons.check),
                label: Text(
                  _isVerified ? 'Mark as Unverified' : 'Mark as Verified',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isVerified ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Warning text
            if (!_isVerified)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Only mark as verified after comparing the safety number through a trusted channel',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 32),
            
            // How it works section
            ExpansionTile(
              title: const Text(
                'How does verification work?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '1. Each user has a unique public key\n\n'
                    '2. The Safety Number is a fingerprint of both public keys\n\n'
                    '3. If the numbers match, you\'re talking to the right person\n\n'
                    '4. If someone tries to intercept, the numbers won\'t match\n\n'
                    '5. Verify through a trusted channel (in person, video call, etc.)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}