import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/report_model.dart';
import '../reporting/report_repository.dart';
import '../utils/priority_utils.dart';
import '../utils/resilient_ui.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.workerId,
    required this.firestore,
  });

  final String reportId;
  final String workerId;
  final FirebaseFirestore firestore;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late final ReportRepository _repository;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = ReportRepository(firestore: widget.firestore);
  }

  Future<void> _openMaps(double lat, double lng) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
    }
  }

  Future<void> _startRepair(String reportId) async {
    setState(() => _isLoading = true);
    try {
      await _repository.updateStatus(
        reportId,
        'In Progress',
        actorId: widget.workerId,
        actorRole: 'worker',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Repair started')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to start repair')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadRepairProof(String reportId) async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (image == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _repository.uploadRepairImage(
        reportId: reportId,
        imageFile: File(image.path),
        workerId: widget.workerId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Repair proof uploaded. Awaiting verification.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload repair proof')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markFixed(String reportId) async {
    setState(() => _isLoading = true);
    try {
      await _repository.completeRepair(
        reportId: reportId,
        workerId: widget.workerId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked as fixed')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to mark as fixed')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.firestore
            .collection('reports')
            .doc(widget.reportId)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(child: Text('Could not load report.'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final ReportModel report = ReportModel.fromDoc(snapshot.data!);
              final Color priorityColor = colorForPriority(report.priority);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DemoNetworkImage(
                        imageUrl: report.imageUrl,
                        height: 220,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              report.category,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                Chip(label: Text('ID: ${report.id}')),
                                Chip(label: Text('Status: ${report.status}')),
                                Chip(
                                  backgroundColor: priorityColor,
                                  label: Text(
                                    report.priority.toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          ThemeData.estimateBrightnessForColor(
                                                priorityColor,
                                              ) ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Description',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              report.description,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Location',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DemoMapPreview(
                        latitude: report.latitude,
                        longitude: report.longitude,
                        height: 220,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  FilledButton.icon(
                                    onPressed: () => _openMaps(
                                      report.latitude,
                                      report.longitude,
                                    ),
                                    icon: const Icon(Icons.navigation_outlined),
                                    label: const Text('Navigate to Location'),
                                  ),
                                  if (report.status == 'Assigned')
                                    FilledButton.tonalIcon(
                                      onPressed: () => _startRepair(report.id),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Start Repair'),
                                    ),
                                  if (report.status ==
                                      'In Progress') ...<Widget>[
                                    FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _uploadRepairProof(report.id),
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('Upload Proof'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _markFixed(report.id),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('Mark Fixed'),
                                    ),
                                  ],
                                  if (report.status == 'Under Review')
                                    FilledButton.tonalIcon(
                                      onPressed: () => _markFixed(report.id),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('Mark Fixed'),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    if ((report.repairImage ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: Text(
                                'Repair Proof',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            DemoNetworkImage(
                              imageUrl: report.repairImage!,
                              height: 220,
                              borderRadius: BorderRadius.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
      ),
    );
  }
}
