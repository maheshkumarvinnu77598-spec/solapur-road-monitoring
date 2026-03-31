import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/dashboard_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, DashboardService? service})
      : _service = service;

  final DashboardService? _service;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _primary = Color(0xFF77B6EA);
  static const Color _background = Color(0xFFE8EEF2);
  static const Color _text = Color(0xFF37393A);
  static const Duration _refreshInterval = Duration(seconds: 5);

  late final DashboardService _service;
  late final bool _ownsService;
  Timer? _refreshTimer;
  DashboardStats? _stats;
  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ownsService = widget._service == null;
    _service = widget._service ?? DashboardService();
    _loadStats();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _loadStats(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStats({bool isRefresh = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _errorMessage = null;
    });

    try {
      final DashboardStats stats = await _service.fetchStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DashboardStats stats = _stats ?? DashboardStats.empty();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _background,
        foregroundColor: _text,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : () => _loadStats(isRefresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && _stats == null
                  ? _DashboardMessageState(
                      title: 'Unable to load analytics',
                      message: _errorMessage!,
                      actionLabel: 'Retry',
                      onPressed: _loadStats,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadStats,
                      color: _primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          const _HeaderSection(),
                          const SizedBox(height: 16),
                          _SummaryGrid(stats: stats),
                          const SizedBox(height: 20),
                          _SectionCard(
                            title: 'Issue Categories',
                            subtitle: 'Distribution of incoming civic issues',
                            child: _CategoryChart(stats: stats),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Issues Over Time',
                            subtitle: 'Daily report trend across the latest timeline',
                            child: _TimelineChart(stats: stats),
                          ),
                          if (_errorMessage != null && _stats != null) ...[
                            const SizedBox(height: 16),
                            _InlineNotice(message: _errorMessage!),
                          ],
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF77B6EA), Color(0xFF5F9FD6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A37393A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'City Operations Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Monitor report volumes, response status, and category trends in real time.',
            style: TextStyle(
              color: Color(0xFFF5FAFD),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final List<_SummaryItem> items = <_SummaryItem>[
      _SummaryItem(
        label: 'Total Reports',
        value: stats.totalReports,
        icon: Icons.assessment_rounded,
        color: const Color(0xFF4F8FC0),
      ),
      _SummaryItem(
        label: 'Pending',
        value: stats.pending,
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFE39B2E),
      ),
      _SummaryItem(
        label: 'In Progress',
        value: stats.inProgress,
        icon: Icons.sync_rounded,
        color: const Color(0xFF5A88D8),
      ),
      _SummaryItem(
        label: 'Completed',
        value: stats.completed,
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF3DA66B),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.45,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (BuildContext context, int index) {
        final _SummaryItem item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1437393A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const Spacer(),
              Text(
                '${item.value}',
                style: const TextStyle(
                  color: Color(0xFF37393A),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFF6B7073),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1437393A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF37393A),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6B7073),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.stats});

  final DashboardStats stats;

  static const Map<String, IconData> _icons = <String, IconData>{
    'pothole': Icons.warning_amber_rounded,
    'crack': Icons.timeline_rounded,
    'garbage': Icons.delete_outline_rounded,
    'water_logging': Icons.water_drop_outlined,
  };

  static const Map<String, Color> _colors = <String, Color>{
    'pothole': Color(0xFF77B6EA),
    'crack': Color(0xFF5F9FD6),
    'garbage': Color(0xFFF4A259),
    'water_logging': Color(0xFF55C1A7),
  };

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> entries = stats.categories.entries.toList(growable: false);
    final int total = entries.fold(0, (int sum, MapEntry<String, int> item) => sum + item.value);

    if (total == 0) {
      return const _ChartEmptyState(message: 'No category data available yet.');
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 48,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: true),
              sections: entries.map((MapEntry<String, int> entry) {
                final double percentage = (entry.value / total) * 100;
                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  color: _colors[entry.key] ?? const Color(0xFF77B6EA),
                  radius: 60,
                  title: '${percentage.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(growable: false),
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries.map((MapEntry<String, int> entry) {
            final String label = entry.key.replaceAll('_', ' ');
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icons[entry.key] ?? Icons.label_outline_rounded,
                    size: 18,
                    color: _colors[entry.key] ?? const Color(0xFF77B6EA),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_capitalize(label)} (${entry.value})',
                    style: const TextStyle(
                      color: Color(0xFF37393A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.timeline.isEmpty) {
      return const _ChartEmptyState(message: 'No timeline data available yet.');
    }

    final List<DashboardTimelinePoint> timeline = stats.timeline;
    final double maxY = timeline.fold<double>(
      0,
      (double maxValue, DashboardTimelinePoint point) => math.max(maxValue, point.count.toDouble()),
    );

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (timeline.length - 1).toDouble(),
          minY: 0,
          maxY: maxY == 0 ? 4 : maxY + 4,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY <= 10 ? 2 : null,
            getDrawingHorizontalLine: (double value) {
              return const FlLine(
                color: Color(0xFFE2E8EE),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: maxY <= 10 ? 2 : null,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xFF7A8186),
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: timeline.length > 6 ? 2 : 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= timeline.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat('MMMd').format(timeline[index].date),
                      style: const TextStyle(
                        color: Color(0xFF7A8186),
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 12,
              getTooltipColor: (_) => const Color(0xFF37393A),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot spot) {
                  final DashboardTimelinePoint point = timeline[spot.x.toInt()];
                  return LineTooltipItem(
                    '${DateFormat('dd MMM yyyy').format(point.date)}\n${point.count} reports',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(growable: false);
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: const Color(0xFF77B6EA),
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: <Color>[
                    const Color(0xFF77B6EA).withOpacity(0.26),
                    const Color(0xFF77B6EA).withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: List<FlSpot>.generate(
                timeline.length,
                (int index) => FlSpot(index.toDouble(), timeline[index].count.toDouble()),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _DashboardMessageState extends StatelessWidget {
  const _DashboardMessageState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1437393A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: Color(0xFF77B6EA),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF37393A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7073),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF77B6EA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onPressed,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF6B7073),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D8A8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB27A14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A5A13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

String _capitalize(String input) {
  if (input.isEmpty) {
    return input;
  }
  return input
      .split(' ')
      .map((String part) {
        if (part.isEmpty) {
          return part;
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}
