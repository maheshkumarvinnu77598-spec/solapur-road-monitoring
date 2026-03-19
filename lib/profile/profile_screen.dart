import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/report_model.dart';
import '../reporting/report_config.dart';
import '../reporting/report_repository.dart';
import '../services/theme_mode_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final ReportRepository repository = ReportRepository();
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
            final int citizenScore =
                (data['citizen_score'] as num?)?.toInt() ?? 0;
            final int approved =
                (data['reports_approved'] as num?)?.toInt() ?? 0;
            final int rejected =
                (data['reports_rejected'] as num?)?.toInt() ?? 0;

            return Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
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
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      appUser.phone ?? user.phoneNumber ?? user.email ?? '',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder(
                    stream: repository.myReports(user.uid),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<ReportModel>> reportSnapshot,
                        ) {
                          final List<ReportModel> reports =
                              reportSnapshot.data ?? const <ReportModel>[];
                          final int reportsSubmitted = reports.length;
                          final int reportsResolved = reports
                              .where(
                                (ReportModel report) =>
                                    report.status == 'Fixed',
                              )
                              .length;
                          final List<String> badges = badgesForCitizen(
                            citizenScore: citizenScore,
                            reportsSubmitted: reportsSubmitted,
                            reportsResolved: reportsResolved,
                          );

                          return Column(
                            children: <Widget>[
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.7,
                                children: <Widget>[
                                  _metricCard('Citizen Score', '$citizenScore'),
                                  _metricCard(
                                    'Reports Submitted',
                                    '$reportsSubmitted',
                                  ),
                                  _metricCard(
                                    'Reports Resolved',
                                    '$reportsResolved',
                                  ),
                                  _metricCard(
                                    'City Rank',
                                    citizenScore == 0
                                        ? '-'
                                        : '#${(100 - citizenScore).clamp(1, 99)}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _infoCard('Name', appUser.name ?? '-'),
                              _infoCard(
                                'Phone',
                                appUser.phone ?? user.phoneNumber ?? '-',
                              ),
                              _infoCard('Role', appUser.role.name),
                              _infoCard(
                                'Accuracy Score',
                                '${(data['accuracy_score'] as num?)?.toStringAsFixed(1) ?? '100'}%',
                              ),
                              _infoCard('Reports Approved', '$approved'),
                              _infoCard('Reports Rejected', '$rejected'),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Badges',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: badges.isEmpty
                                            ? const <Widget>[
                                                Chip(
                                                  label: Text(
                                                    'Start reporting to unlock badges',
                                                  ),
                                                ),
                                              ]
                                            : badges
                                                  .map(
                                                    (badge) => Chip(
                                                      label: Text(badge),
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
      child: ListTile(
        title: Text(label),
        subtitle: Text(value.isEmpty ? 'No data available' : value),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
