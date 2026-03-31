import 'package:flutter/material.dart';

import 'contact_admin_screen.dart';
import 'support_requests_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: ExpansionTile(
              title: const Text('FAQ'),
              children: const <Widget>[
                ListTile(
                  title: Text('How do I report an issue?'),
                  subtitle: Text(
                    'Open Create New Report, capture an image, add details, and submit.',
                  ),
                ),
                ListTile(
                  title: Text('How does offline reporting work?'),
                  subtitle: Text(
                    'Your report is saved locally and synced automatically when the network returns.',
                  ),
                ),
                ListTile(
                  title: Text('How do I verify a repair?'),
                  subtitle: Text(
                    'Open the report details page after repair proof is uploaded and confirm whether the issue is fixed.',
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Contact Admin'),
              subtitle: const Text(
                'Submit a support request to the admin team',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ContactAdminScreen(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: const Text('My Support Requests'),
              subtitle: const Text('Track request status and admin replies'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportRequestsScreen(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report App Issue'),
              subtitle: const Text(
                'Send a bug report with an optional screenshot',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ContactAdminScreen(initialSubject: 'App Issue'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
