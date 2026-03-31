import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../citizen/citizen_dashboard_screen.dart';
import '../models/app_user.dart';
import '../notifications/fcm_service.dart';
import '../profile/profile_setup_screen.dart';
import '../reporting/report_repository.dart';
import '../worker/worker_dashboard_screen.dart';
import 'auth_service.dart';
import 'screens/login_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  int _refreshCounter = 0;
  final FcmService _fcmService = FcmService();
  String? _tokenSyncedUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.authService.authChanges(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return LoginScreen(authService: widget.authService);
        }

        return FutureBuilder<AppUser>(
          key: ValueKey<int>(_refreshCounter),
          future: widget.authService.getCurrentAppUser(),
          builder: (BuildContext context, AsyncSnapshot<AppUser> userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final AppUser appUser = userSnapshot.data!;
            if (_tokenSyncedUid != appUser.uid) {
              _tokenSyncedUid = appUser.uid;
              unawaited(_fcmService.syncTokenForAppUser(appUser));
            }
            final ReportRepository repository = ReportRepository();
            final bool needsProfileSetup =
                appUser.role == UserRole.citizen &&
                ((appUser.name == null || appUser.name!.trim().isEmpty) ||
                    (appUser.avatarEmoji == null ||
                        appUser.avatarEmoji!.trim().isEmpty));

            if (needsProfileSetup) {
              return ProfileSetupScreen(
                onDone: () {
                  setState(() => _refreshCounter++);
                },
              );
            }

            switch (appUser.role) {
              case UserRole.worker:
                return WorkerDashboardScreen(
                  worker: appUser,
                  firestore: FirebaseFirestore.instance,
                );
              case UserRole.citizen:
                return CitizenDashboardScreen(
                  repository: repository,
                  onLogout: widget.authService.signOut,
                );
            }
          },
        );
      },
    );
  }
}
