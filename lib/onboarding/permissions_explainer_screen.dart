import 'package:flutter/material.dart';

import '../ui_theme/app_theme.dart';

class PermissionsExplainerScreen extends StatelessWidget {
  const PermissionsExplainerScreen({
    super.key,
    required this.onContinue,
    required this.isWorker,
  });

  final Future<void> Function() onContinue;
  final bool isWorker;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 12),
              Text(
                'Permissions',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Solapur Road Monitoring only asks for access when you use a feature that needs it.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _PermissionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                message:
                    'Used to capture issue photos, repair proof, and worker attendance selfies.',
              ),
              _PermissionCard(
                icon: Icons.location_on_outlined,
                title: 'Location',
                message:
                    'Used to pin issue coordinates, navigate field teams, and verify on-site attendance.',
              ),
              _PermissionCard(
                icon: Icons.photo_library_outlined,
                title: 'Photos',
                message:
                    'Used only when you attach an optional support screenshot from your gallery.',
              ),
              const Spacer(),
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.security_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isWorker
                              ? 'You can continue now. Camera and location permission prompts will appear only when starting field actions.'
                              : 'You can continue now. Camera and location permission prompts will appear only when creating a report.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppPalette.primary.withValues(alpha: 0.18),
          foregroundColor: scheme.primary,
          child: Icon(icon),
        ),
        title: Text(title, style: textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(message, style: textTheme.bodyMedium),
        ),
      ),
    );
  }
}
