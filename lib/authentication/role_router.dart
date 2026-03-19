import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../citizen/citizen_dashboard_screen.dart';
import '../models/app_user.dart';
import '../onboarding/permissions_explainer_screen.dart';
import '../profile/profile_setup_screen.dart';
import '../reporting/report_repository.dart';
import '../worker/worker_dashboard_screen.dart';
import 'auth_service.dart';
import 'screens/login_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key, this.authService});

  final AuthService? authService;

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late final AuthService _authService;
  late final Stream<dynamic> _authChangesStream;
  StreamSubscription<dynamic>? _authSubscription;
  Future<AppUser>? _appUserFuture;
  Future<AppUser?>? _workerSessionFuture;
  String? _currentUid;
  String? _tokenSyncedUid;
  Future<bool>? _permissionsFuture;

  static String _permissionsKeyForUser(String uid) =>
      'permissions_explained_$uid';

  Future<bool> _shouldShowPermissions(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_permissionsKeyForUser(uid)) ?? false);
  }

  Future<void> _markPermissionsSeen(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsKeyForUser(uid), true);
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionsFuture = Future<bool>.value(false);
    });
  }

  Future<AppUser?> _loadWorkerSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String workerId = (prefs.getString('worker_session_worker_id') ?? '')
        .trim()
        .toUpperCase();
    if (workerId.isEmpty) {
      return null;
    }
    try {
      return await _authService.workerLoginWithId(workerId);
    } catch (_) {
      await prefs.remove('worker_session');
      await prefs.remove('worker_session_worker_id');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _authChangesStream = _authService.authChanges();
    _workerSessionFuture = _loadWorkerSession();
    _authSubscription = _authChangesStream.listen((dynamic user) {
      final String? nextUid = user?.uid as String?;
      if (!mounted) {
        return;
      }
      if (nextUid == null) {
        setState(() {
          _currentUid = null;
          _appUserFuture = null;
          _permissionsFuture = null;
          _tokenSyncedUid = null;
        });
        return;
      }
      if (_currentUid == nextUid && _appUserFuture != null) {
        return;
      }
      setState(() {
        _currentUid = nextUid;
        _appUserFuture = _authService.getCurrentAppUser();
        _permissionsFuture = _shouldShowPermissions(nextUid);
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authChangesStream,
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return FutureBuilder<AppUser?>(
            future: _workerSessionFuture,
            builder:
                (BuildContext context, AsyncSnapshot<AppUser?> workerSnapshot) {
                  if (!workerSnapshot.hasData) {
                    return LoginScreen(authService: _authService);
                  }
                  return WorkerDashboardScreen(
                    worker: workerSnapshot.data!,
                    firestore: FirebaseFirestore.instance,
                  );
                },
          );
        }

        return FutureBuilder<AppUser>(
          future: _appUserFuture,
          builder: (BuildContext context, AsyncSnapshot<AppUser> userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final AppUser appUser = userSnapshot.data!;
            if (_tokenSyncedUid != appUser.uid) {
              _tokenSyncedUid = appUser.uid;
              _permissionsFuture = _shouldShowPermissions(appUser.uid);
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
                  setState(() {
                    _appUserFuture = _authService.getCurrentAppUser();
                  });
                },
              );
            }

            return FutureBuilder<bool>(
              future: _permissionsFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<bool> permissionsSnapshot,
                  ) {
                    if (!permissionsSnapshot.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (permissionsSnapshot.data ?? false) {
                      return PermissionsExplainerScreen(
                        isWorker: appUser.role == UserRole.worker,
                        onContinue: () => _markPermissionsSeen(appUser.uid),
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
                          onLogout: _authService.signOut,
                        );
                    }
                  },
            );
          },
        );
      },
    );
  }
}
