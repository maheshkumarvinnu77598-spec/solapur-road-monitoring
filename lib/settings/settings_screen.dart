import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/help_support_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _notify = true;
  bool _saving = false;
  bool _loading = true;
  bool _loaded = false;
  bool _phoneVisible = true;

  String _locationStatus = 'Checking...';
  String _appVersion = '...';
  String _existingPhotoUrl = '';
  XFile? _pickedPhoto;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>(<Future<void>>[
      _loadInitialUserData(),
      _refreshLocationStatus(),
      _loadVersion(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _loadInitialUserData() async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String email = FirebaseAuth.instance.currentUser?.email ?? '';

    if (uid.isEmpty) {
      _loaded = true;
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    _nameCtrl.text = data['name'] as String? ?? '';
    _phoneCtrl.text = data['phone'] as String? ?? '';
    _emailCtrl.text = (data['email'] as String?)?.trim().isNotEmpty == true
        ? data['email'] as String
        : email;
    _notify = data['notify_enabled'] as bool? ?? true;
    _phoneVisible = data['phone_visible'] as bool? ?? true;
    _existingPhotoUrl = data['profile_picture'] as String? ?? '';
    _loaded = true;
  }

  Future<void> _refreshLocationStatus() async {
    final bool enabled = await Geolocator.isLocationServiceEnabled();
    final LocationPermission permission = await Geolocator.checkPermission();

    final String status;
    if (!enabled) {
      status = 'GPS disabled';
    } else {
      switch (permission) {
        case LocationPermission.always:
          status = 'Always allowed';
        case LocationPermission.whileInUse:
          status = 'Allowed while using app';
        case LocationPermission.denied:
          status = 'Permission denied';
        case LocationPermission.deniedForever:
          status = 'Denied forever';
        case LocationPermission.unableToDetermine:
          status = 'Not determined';
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _locationStatus = status);
  }

  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  Future<void> _pickProfilePhoto() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (image == null || !mounted) {
      return;
    }
    setState(() => _pickedPhoto = image);
  }

  Future<void> _save(String uid) async {
    final String name = _nameCtrl.text.trim();
    final String email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      _show('Name is required', isError: true);
      return;
    }
    if (email.isEmpty) {
      _show('Email is required', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      String photoUrl = _existingPhotoUrl;
      if (_pickedPhoto != null) {
        final String path =
            'profiles/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final SupabaseClient supabase = Supabase.instance.client;
        await supabase.storage
            .from('report-images')
            .upload(
              path,
              File(_pickedPhoto!.path),
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
                contentType: 'image/jpeg',
              ),
            );
        photoUrl = supabase.storage.from('report-images').getPublicUrl(path);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(<String, dynamic>{
            'name': name,
            'phone': _phoneCtrl.text.trim(),
            'email': email,
            'profile_picture': photoUrl,
            'notify_enabled': _notify,
            'phone_visible': _phoneVisible,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _existingPhotoUrl = photoUrl;
      _pickedPhoto = null;

      if (!mounted) {
        return;
      }
      _show('Settings saved');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _show('Could not save settings', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const Center(child: Text('Login required'));
    }
    if (_loading || !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(context, 'Account Settings', <Widget>[
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: _pickedPhoto != null
                    ? FileImage(File(_pickedPhoto!.path))
                    : (_existingPhotoUrl.isNotEmpty
                              ? NetworkImage(_existingPhotoUrl)
                              : null)
                          as ImageProvider<Object>?,
                child: _pickedPhoto == null && _existingPhotoUrl.isEmpty
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _pickProfilePhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Change Profile Image'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ]),
        _section(context, 'App Settings', <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable notifications'),
            value: _notify,
            onChanged: (bool value) => setState(() => _notify = value),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Theme mode'),
            subtitle: Text('Change theme from the profile page.'),
          ),
        ]),
        _section(context, 'Permissions', <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Location permission status'),
            subtitle: Text(_locationStatus),
            trailing: IconButton(
              onPressed: _refreshLocationStatus,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ]),
        _section(context, 'Help & Support', <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open Help Center'),
            subtitle: const Text(
              'FAQ, contact admin, support inbox, and app issue reporting',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HelpSupportScreen(),
                ),
              );
            },
          ),
        ]),
        _section(context, 'Privacy', <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show phone number in profile'),
            value: _phoneVisible,
            onChanged: (bool value) => setState(() => _phoneVisible = value),
          ),
        ]),
        _section(context, 'About', <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('App Version'),
            subtitle: Text(_appVersion),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Support System'),
            subtitle: const Text(
              'In-app help desk connected directly to the admin dashboard.',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : () => _save(uid),
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
