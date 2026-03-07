import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/emoji_avatar_picker.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedEmoji = '🙂';
  bool _phoneVisible = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _show('Display name is required.', isError: true);
      return;
    }

    setState(() => _saving = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(<String, dynamic>{
          'uid': user.uid,
          'name': name,
          'phone': user.phoneNumber ?? '',
          'phone_visible': _phoneVisible,
          'avatar_emoji': _selectedEmoji,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    widget.onDone();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  EmojiAvatarPicker(
                    selected: _selectedEmoji,
                    onSelect: (String v) => setState(() => _selectedEmoji = v),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _phoneVisible,
                    onChanged: (bool v) => setState(() => _phoneVisible = v),
                    title: const Text('Show phone number publicly'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save & Continue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
