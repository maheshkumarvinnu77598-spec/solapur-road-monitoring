import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'authentication/role_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RoadMonitoringApp());
}

class RoadMonitoringApp extends StatelessWidget {
  const RoadMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Solapur Road Monitoring',
      theme: ThemeData(
        primaryColor: const Color(0xFF77B6EA),
        scaffoldBackgroundColor: const Color(0xFFE8EEF2),
      ),
      home: const RoleRouter(),
    );
  }
}
