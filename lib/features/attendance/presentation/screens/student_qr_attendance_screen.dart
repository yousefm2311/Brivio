import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentQrAttendanceScreen extends StatefulWidget {
  const StudentQrAttendanceScreen({super.key});

  @override
  State<StudentQrAttendanceScreen> createState() =>
      _StudentQrAttendanceScreenState();
}

class _StudentQrAttendanceScreenState extends State<StudentQrAttendanceScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualTokenController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasScanned = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualTokenController.dispose();
    super.dispose();
  }

  Future<void> _submitToken(String rawValue) async {
    final token = _extractToken(rawValue);
    if (token == null || token.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _message = null;
      _isSuccess = false;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'validate_attendance_qr',
        params: {
          'p_token': token,
          'p_device_id': 'flutter-client',
          'p_latitude': null,
          'p_longitude': null,
        },
      );
      final json = Map<String, dynamic>.from(response as Map);
      setState(() {
        _isSuccess = json['success'] == true;
        _message = _isSuccess
            ? 'Attendance marked successfully.'
            : 'Attendance was not accepted.';
        _isSubmitting = false;
      });
      await _scannerController.stop();
    } catch (e) {
      setState(() {
        _message = 'Attendance scan failed: $e';
        _isSubmitting = false;
        _hasScanned = false;
      });
    }
  }

  String? _extractToken(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['type'] == 'attendance_qr') {
        return decoded['token']?.toString();
      }
    } catch (_) {}
    return trimmed;
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_hasScanned || _isSubmitting) return;
    String? value;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.trim().isNotEmpty) {
        value = barcode.rawValue;
        break;
      }
    }
    if (value == null) return;
    _hasScanned = true;
    _submitToken(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Attendance QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _handleDetect,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan the QR shown by your teacher. The code changes every minute.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_isSubmitting)
            const Center(child: CircularProgressIndicator())
          else if (_message != null)
            Card(
              color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green.shade900 : Colors.red,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          TextField(
            controller: _manualTokenController,
            decoration: const InputDecoration(
              labelText: 'Manual token',
              prefixIcon: Icon(Icons.key),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => _submitToken(_manualTokenController.text),
            icon: const Icon(Icons.check_circle),
            label: const Text('Submit Token'),
          ),
        ],
      ),
    );
  }
}
