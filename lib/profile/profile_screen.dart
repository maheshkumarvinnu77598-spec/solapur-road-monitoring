import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/theme_mode_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Login required.'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data() ?? <String, dynamic>{};
            final appUser = AppUser.fromMap(user.uid, data);

            return Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      child: Text(
                        appUser.avatarEmoji ?? '🙂',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      appUser.name ?? 'Citizen',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      appUser.phone ?? user.phoneNumber ?? user.email ?? '',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _infoCard('Name', appUser.name ?? '-'),
                  _infoCard('Phone', appUser.phone ?? user.phoneNumber ?? '-'),
                  _infoCard('Role', appUser.role.name),
                  _infoCard(
                    'Accuracy Score',
                    '${(data['accuracy_score'] as num?)?.toStringAsFixed(1) ?? '100'}%',
                  ),
                  _infoCard(
                    'Reports Approved',
                    '${(data['reports_approved'] as num?)?.toInt() ?? 0}',
                  ),
                  _infoCard(
                    'Reports Rejected',
                    '${(data['reports_rejected'] as num?)?.toInt() ?? 0}',
                  ),
                  if ((appUser.zone ?? '').isNotEmpty)
                    _infoCard('Zone', appUser.zone!),
                  Card(
                    child: ListTile(
                      title: const Text('Theme'),
                      subtitle: ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeModeService.instance.themeMode,
                        builder:
                            (
                              BuildContext context,
                              ThemeMode mode,
                              Widget? child,
                            ) {
                              return SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text('System'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text('Light'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text('Dark'),
                                  ),
                                ],
                                selected: <ThemeMode>{mode},
                                onSelectionChanged: (Set<ThemeMode> selection) {
                                  ThemeModeService.instance.setMode(
                                    selection.first,
                                  );
                                },
                              );
                            },
                      ),
                    ),
                  ),
                ],
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditProfileScreen(
                        initialName: appUser.name ?? '',
                        initialEmoji: appUser.avatarEmoji ?? '🙂',
                      ),
                    ),
                  );
                },
                label: const Text('Edit Profile'),
                icon: const Icon(Icons.edit_outlined),
              ),
            );
          },
    );
  }

  Widget _infoCard(String label, String value) {
    return Card(
      child: ListTile(title: Text(label), subtitle: Text(value)),
    );
  }
}
