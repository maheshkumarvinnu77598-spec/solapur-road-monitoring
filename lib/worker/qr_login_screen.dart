import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'worker_dashboard_screen.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handlingScan = false;

  String extractId(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return (decoded['worker_id'] as String? ?? '').trim();
      }
    } catch (_) {}

    if (trimmed.contains(':')) {
      return trimmed.split(':').last.trim();
    }
    return trimmed;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_handlingScan) {
      return;
    }
    final String scannedValue = capture.barcodes.first.rawValue ?? '';
    // ignore: avoid_print
    print('SCANNED QR RAW: $scannedValue');
    if (scannedValue.trim().isEmpty) {
      return;
    }

    setState(() => _handlingScan = true);
    try {
      final String workerId = extractId(scannedValue).trim().toUpperCase();
      if (workerId.isEmpty) {
        throw const FormatException('Invalid QR');
      }

      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('workers')
          .doc(workerId)
          .get();

      if (!doc.exists) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Invalid Worker ID'),
              backgroundColor: Colors.red,
            ),
          );
        setState(() => _handlingScan = false);
        return;
      }

      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      final AppUser worker = AppUser(
        uid: doc.id,
        email: data['email'] as String?,
        role: UserRole.worker,
        name: data['name'] as String? ?? workerId,
        phone: data['phone'] as String?,
        zone: data['zone'] as String?,
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'worker_session',
        jsonEncode(<String, String>{
          'worker_id': worker.uid,
          'worker_name': worker.name ?? '',
        }),
      );
      await prefs.setString('worker_session_worker_id', worker.uid);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Login successful')));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WorkerDashboardScreen(
            worker: worker,
            firestore: FirebaseFirestore.instance,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code. Please scan a valid worker QR.'),
            backgroundColor: Colors.red,
          ),
        );
      setState(() => _handlingScan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Worker Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Scan Worker QR',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the admin-generated QR code to log in instantly.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_handlingScan)
                const Center(
                  child: Column(
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Validating QR and logging in...'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
