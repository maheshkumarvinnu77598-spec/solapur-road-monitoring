<<<<<<< HEAD
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../worker/worker_dashboard_screen.dart';
import '../auth_service.dart';

class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key, required this.authService});

  final AuthService authService;
=======
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication/auth_service.dart';
import '../../models/app_user.dart';
import '../../worker/qr_login_screen.dart';

class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key});
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final TextEditingController _workerIdCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
<<<<<<< HEAD
  bool _loading = false;

  @override
=======
  final AuthService _authService = AuthService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  void dispose() {
    _workerIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

<<<<<<< HEAD
=======
  Future<void> _restoreSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('worker_session');
      if (raw == null || raw.isEmpty) {
        return;
      }
      final Map<String, dynamic> payload =
          jsonDecode(raw) as Map<String, dynamic>;
      final String workerId = payload['worker_id'] as String? ?? '';
      if (workerId.isEmpty) {
        return;
      }
      final AppUser? worker = await _authService.workerLoginWithId(workerId);
      if (!mounted || worker == null) {
        return;
      }
      _openDashboard(worker);
    } catch (_) {}
  }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  Future<void> _login() async {
    final String workerId = _workerIdCtrl.text.trim();
    final String password = _passwordCtrl.text.trim();

    if (workerId.isEmpty || password.isEmpty) {
      _show('Worker ID and password required', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
<<<<<<< HEAD
      final AppUser? worker = await widget.authService.workerLogin(
        workerId: workerId,
        password: password,
      );

      if (worker == null) {
        _show('Invalid worker credentials', isError: true);
        return;
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WorkerDashboardScreen(
            worker: worker,
            firestore: FirebaseFirestore.instance,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _show(e.message ?? 'Worker login failed', isError: true);
=======
      final AppUser? worker = await _authService.workerLogin(
        workerId: workerId,
        password: password,
      );
      if (!mounted || worker == null) {
        return;
      }
      await _persistWorkerSession(worker);
      _openDashboard(worker);
    } catch (_) {
      _show('Worker login failed', isError: true);
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

<<<<<<< HEAD
=======
  Future<void> _persistWorkerSession(AppUser worker) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'worker_session',
      jsonEncode(<String, String>{
        'worker_id': worker.uid,
        'worker_name': worker.name ?? '',
      }),
    );
    await prefs.setString('worker_session_worker_id', worker.uid);
  }

  void _openDashboard(AppUser worker) {
    Navigator.pushReplacementNamed(context, '/worker');
  }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  void _show(String msg, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _workerIdCtrl,
                      decoration: const InputDecoration(labelText: 'Worker ID'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login as Worker'),
                    ),
<<<<<<< HEAD
=======
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const QrLoginScreen(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      label: const Text('Login with QR Code'),
                    ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
