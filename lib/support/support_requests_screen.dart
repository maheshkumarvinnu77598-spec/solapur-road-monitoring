import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_request.dart';
import '../repositories/support_repository.dart';

class SupportRequestsScreen extends StatelessWidget {
  const SupportRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('Login required.')));
    }

    final SupportRepository repository = SupportRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('My Support Requests')),
      body: StreamBuilder<List<SupportRequestModel>>(
        stream: repository.streamForUser(uid),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<SupportRequestModel>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Unable to load support requests right now.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<SupportRequestModel> requests = snapshot.data!;
              if (requests.isEmpty) {
                return const Center(child: Text('No support requests yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: requests.length,
                itemBuilder: (BuildContext context, int index) {
                  final SupportRequestModel request = requests[index];
                  return Card(
                    child: ListTile(
                      title: Text(request.subject),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SizedBox(height: 4),
                          Text(request.message),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${request.status} • ${DateFormat('dd MMM, hh:mm a').format(request.createdAt)}',
                          ),
                          if ((request.adminReply ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Admin Reply: ${request.adminReply}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
      ),
    );
  }
}
