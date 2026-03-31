import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/support_repository.dart';

class ContactAdminScreen extends StatefulWidget {
  const ContactAdminScreen({super.key, this.initialSubject});

  final String? initialSubject;

  @override
  State<ContactAdminScreen> createState() => _ContactAdminScreenState();
}

class _ContactAdminScreenState extends State<ContactAdminScreen> {
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  final SupportRepository _repository = SupportRepository();
  XFile? _screenshot;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _subjectCtrl.text = widget.initialSubject ?? '';
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (image == null || !mounted) {
      return;
    }
    setState(() => _screenshot = image);
  }

  Future<void> _submit() async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return;
    }
    if (_subjectCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and message are required.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repository.submitRequest(
        userId: uid,
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        screenshot: _screenshot == null ? null : File(_screenshot!.path),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request submitted.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit support request.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickScreenshot,
            icon: const Icon(Icons.bug_report_outlined),
            label: Text(
              _screenshot == null ? 'Attach Screenshot' : 'Change Screenshot',
            ),
          ),
          if (_screenshot != null) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_screenshot!.path),
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}
