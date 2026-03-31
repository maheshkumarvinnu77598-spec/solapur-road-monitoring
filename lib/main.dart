import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'authentication/auth_service.dart';
import 'authentication/role_router.dart';
import 'notifications/fcm_service.dart';
import 'reporting/report_repository.dart';
import 'services/monitoring_service.dart';
import 'services/offline/offline_sync_service.dart';
import 'services/theme_mode_service.dart';
import 'ui_theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MonitoringService.instance.initialize();
  await FcmService().initialize();
  unawaited(OfflineSyncService.instance.start(repository: ReportRepository()));
  runApp(const RoadMonitoringApp());
}

class RoadMonitoringApp extends StatelessWidget {
  const RoadMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeModeService.instance.themeMode,
      builder: (BuildContext context, ThemeMode mode, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Solapur Road Monitoring',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: RoleRouter(authService: authService),
        );
      },
    );
  }
}
