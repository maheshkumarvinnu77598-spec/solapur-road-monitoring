import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../ui_theme/app_theme.dart';
import '../auth_service.dart';
import 'admin_login_screen.dart';
import 'otp_screen.dart';
import 'signup_screen.dart';
import 'worker_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _loading = false;
  bool _sendingOtp = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _loading = true);

    try {
      await widget.authService.signInWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _show(e.message ?? 'Login failed', isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendOtp() async {
    final String phone = _phoneCtrl.text.trim();
    if (!_isE164(phone)) {
      _show('Use phone format like +919876543210', isError: true);
      return;
    }

    setState(() => _sendingOtp = true);
    try {
      await widget.authService.verifyPhoneNumber(
        phone: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await widget.authService.signInWithPhoneCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _show(_mapPhoneError(e), isError: true);
          if (mounted) {
            setState(() => _sendingOtp = false);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() => _sendingOtp = false);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OtpScreen(
                  authService: widget.authService,
                  verificationId: verificationId,
                  phone: phone,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _show('OTP auto retrieval timed out. Enter OTP manually.');
          if (mounted) {
            setState(() => _sendingOtp = false);
          }
        },
      );
    } catch (_) {
      _show('Could not start phone verification.', isError: true);
      if (mounted) {
        setState(() => _sendingOtp = false);
      }
    }
  }

  String _mapPhoneError(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        return 'Phone authentication is disabled in Firebase Console.';
      case 'invalid-phone-number':
        return 'Invalid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Phone verification failed.';
    }
  }

  bool _isE164(String phone) => RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.domain_rounded,
                            color: AppPalette.primary,
                            size: 48,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Solapur Road Monitoring',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (String? value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Email is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _hidePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (String? value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Password is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: _loading ? null : _signInEmail,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Login'),
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('OR'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number (+91...)',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: _sendingOtp ? null : _sendOtp,
                            child: _sendingOtp
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Send OTP'),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SignUpScreen(
                                        authService: widget.authService,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Create citizen account'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => WorkerLoginScreen(
                                        authService: widget.authService,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Worker Login'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AdminLoginScreen(
                                        authService: widget.authService,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Admin Login'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
