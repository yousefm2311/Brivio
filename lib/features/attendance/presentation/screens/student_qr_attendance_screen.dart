import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';

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
      final deviceId = await _resolveDeviceId();
      final position = await _tryResolvePosition();
      final response = await Supabase.instance.client.rpc(
        'validate_attendance_qr',
        params: {
          'p_token': token,
          'p_device_id': deviceId,
          'p_latitude': position?.latitude,
          'p_longitude': position?.longitude,
        },
      );
      final json = Map<String, dynamic>.from(response as Map);
      setState(() {
        _isSuccess = json['success'] == true;
        _message = _isSuccess
            ? context.tr('Attendance marked successfully.')
            : context.tr('Attendance was not accepted.');
        _isSubmitting = false;
      });
      await _scannerController.stop();
    } catch (e) {
      setState(() {
        _message = '${context.tr('Attendance scan failed')}: $e';
        _isSubmitting = false;
        _hasScanned = false;
      });
    }
  }

  Future<String> _resolveDeviceId() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return 'android-${info.id}';
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return 'ios-${info.identifierForVendor ?? 'unknown'}';
      }
    } catch (_) {}
    return 'unknown-device';
  }

  Future<Position?> _tryResolvePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
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
      appBar: AppBar(title: Text(context.tr('Scan Attendance QR'))),
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
            context.tr(
              'Scan the QR shown by your teacher. The code changes every minute.',
            ),
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
            decoration: InputDecoration(
              labelText: context.tr('Manual token'),
              prefixIcon: const Icon(Icons.key),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => _submitToken(_manualTokenController.text),
            icon: const Icon(Icons.check_circle),
            label: Text(context.tr('Submit Token')),
          ),
        ],
      ),
    );
  }
}
