import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountLoginQrDialog extends StatefulWidget {
  final String profileId;
  final String displayName;
  final String email;

  const AccountLoginQrDialog({
    super.key,
    required this.profileId,
    required this.displayName,
    required this.email,
  });

  @override
  State<AccountLoginQrDialog> createState() => _AccountLoginQrDialogState();
}

class _AccountLoginQrDialogState extends State<AccountLoginQrDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _payload;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  Future<void> _generateQr() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'create_account_login_qr',
        params: {'p_profile_id': widget.profileId},
      );

      final json = Map<String, dynamic>.from(response as Map);
      final payloadData = Map<String, dynamic>.from(json['payload'] as Map);
      final payload = jsonEncode(payloadData);
      final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');

      if (!mounted) return;
      setState(() {
        _payload = payload;
        _expiresAt = expiresAt;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Login QR - ${widget.displayName}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.email, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_isLoading)
              const SizedBox(
                width: 220,
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            else if (_payload != null)
              QrImageView(
                data: _payload!,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            const SizedBox(height: 12),
            const Text(
              'This QR contains a temporary token only. It never contains the real password.',
              textAlign: TextAlign.center,
            ),
            if (_expiresAt != null) ...[
              const SizedBox(height: 8),
              Text('Expires: ${_expiresAt!.toLocal()}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isLoading ? null : _generateQr,
          icon: const Icon(Icons.refresh),
          label: const Text('Regenerate'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
