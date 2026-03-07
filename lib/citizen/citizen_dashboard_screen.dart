import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../notifications/screens/notifications_inbox_screen.dart';
import '../repositories/notification_repository.dart';
import '../map/live_map_screen.dart';
import '../profile/profile_screen.dart';
import '../reporting/my_reports_screen.dart';
import '../reporting/report_repository.dart';
import '../reporting/report_wizard_screen.dart';
import '../services/haptic_service.dart';
import '../settings/settings_screen.dart';
import 'citizen_home_screen.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final ReportRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  int _index = 0;
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  static const List<String> _titles = <String>[
    'Home',
    'City Issue Map',
    'My Reports',
    'Profile',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      CitizenHomeScreen(
        repository: widget.repository,
        onCreateReport: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReportWizardScreen(repository: widget.repository),
            ),
          );
        },
      ),
      LiveMapScreen(repository: widget.repository),
      MyReportsScreen(repository: widget.repository),
      const ProfileScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          StreamBuilder<int>(
            stream: _notificationRepository.unreadCount(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              final int unread = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    onPressed: () {
                      HapticService.lightTap();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NotificationsInboxScreen(
                            notificationRepository: _notificationRepository,
                            reportRepository: widget.repository,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 10,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey<int>(_index), child: pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          HapticService.lightTap();
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            label: 'My Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
