import 'package:flutter/material.dart';

import '../reporting/report_repository.dart';

class CityAnalyticsScreen extends StatelessWidget {
  const CityAnalyticsScreen({super.key, required this.repository});

  final ReportRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('City Analytics')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: repository.cityAnalytics(),
        builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load analytics right now.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<String, dynamic> data = snapshot.data!;
          final List<dynamic> topCategories =
              data['top_categories'] as List<dynamic>? ?? const <dynamic>[];
          final List<dynamic> wardPerformance =
              data['ward_performance'] as List<dynamic>? ?? const <dynamic>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: <Widget>[
                  _metricCard(
                    context,
                    'Total Reports',
                    '${data['total_reports'] ?? 0}',
                  ),
                  _metricCard(
                    context,
                    'Resolved Reports',
                    '${data['resolved_reports'] ?? 0}',
                  ),
                  _metricCard(
                    context,
                    'Avg Repair Time',
                    '${data['average_repair_hours'] ?? 0} hrs',
                  ),
                  _metricCard(
                    context,
                    'Top Wards',
                    '${wardPerformance.length}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Top Issue Categories',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...topCategories.take(5).map((entry) {
                final dynamic category = entry;
                return Card(
                  child: ListTile(
                    title: Text('${category.key}'),
                    trailing: Text('${category.value}'),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Ward Performance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...wardPerformance.take(5).map((entry) {
                final dynamic ward = entry;
                return Card(
                  child: ListTile(
                    title: Text('${ward.key}'),
                    subtitle: const Text('Open issue density'),
                    trailing: Text('${ward.value}'),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Citizen Leaderboard',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: repository.citizenLeaderboard(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                    ) {
                      final List<Map<String, dynamic>> entries =
                          snapshot.data ?? const <Map<String, dynamic>>[];
                      if (entries.isEmpty) {
                        return const Card(
                          child: ListTile(
                            title: Text('No leaderboard data yet.'),
                          ),
                        );
                      }
                      return Column(
                        children: List<Widget>.generate(entries.length, (
                          index,
                        ) {
                          final entry = entries[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('#${index + 1}'),
                              ),
                              title: Text(
                                entry['name'] as String? ?? 'Citizen',
                              ),
                              subtitle: Text(
                                'Badges: ${(entry['reports_approved'] as num?)?.toInt() ?? 0} approved',
                              ),
                              trailing: Text(
                                '${(entry['citizen_score'] as num?)?.toInt() ?? 0}',
                              ),
                            ),
                          );
                        }),
                      );
                    },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricCard(BuildContext context, String label, String value) {
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
