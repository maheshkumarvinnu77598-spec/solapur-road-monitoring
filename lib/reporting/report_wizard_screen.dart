import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/offline_report.dart';
import '../services/fraud_detection_service.dart';
import '../services/haptic_service.dart';
import '../services/analytics_service.dart';
import '../services/offline/offline_queue_service.dart';
import '../ui_theme/app_theme.dart';
import 'ai_placeholder_service.dart';
import 'report_config.dart';
import 'report_confirmation_screen.dart';
import 'report_repository.dart';

class ReportWizardScreen extends StatefulWidget {
  const ReportWizardScreen({
    super.key,
    this.repository,
    this.captureImageOverride,
  });

  final ReportRepository? repository;
  final Future<XFile?> Function()? captureImageOverride;

  @override
  State<ReportWizardScreen> createState() => _ReportWizardScreenState();
}

class _ReportWizardScreenState extends State<ReportWizardScreen> {
  final TextEditingController _descriptionCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AiPlaceholderService _aiService = AiPlaceholderService();
  final FraudDetectionService _fraudDetectionService = FraudDetectionService();
  final OfflineQueueService _offlineQueueService = OfflineQueueService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  int _step = 0;
  IssueCategory? _selected;
  XFile? _image;
  Position? _position;
  bool _loading = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_loading) {
      return;
    }

    try {
      final XFile? photo = widget.captureImageOverride != null
          ? await widget.captureImageOverride!()
          : await _picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 75,
            );
      if (photo == null || !mounted) {
        return;
      }

      setState(() {
        _image = photo;
        _step = 2;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _show('Could not capture image. Please try again.', isError: true);
    }
  }

  Future<void> _autoDetectGps() async {
    if (_loading) {
      return;
    }

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _show('Please enable GPS services to continue.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _show('Location permission denied.', isError: true);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
        if (_step < 3) {
          _step = 3;
        }
      });

      debugPrint(
        'GPS Coordinates -> Latitude: ${position.latitude}, Longitude: ${position.longitude}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _show('Unable to fetch location. Please try again.', isError: true);
    }
  }

  Future<void> _submit() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final ReportRepository? repository = widget.repository;
    final IssueCategory? selected = _selected;
    final XFile? image = _image;
    final Position? position = _position;

    if (user == null) {
      _show('Please login again.', isError: true);
      return;
    }
    if (repository == null) {
      _show('Reporting service unavailable.', isError: true);
      return;
    }
    if (selected == null || image == null || position == null) {
      _show('Please complete all steps before submit.', isError: true);
      return;
    }
    if (_descriptionCtrl.text.trim().length < 10) {
      _show('Description must be at least 10 characters.', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final File imageFile = await _compressImage(File(image.path));
      final String imageHash = await _sha256ForFile(imageFile);

      final bool duplicateHash = await repository.hasRecentImageHash(imageHash);
      if (duplicateHash) {
        _show(
          'This image appears reused from an existing report. Please capture a fresh photo.',
          isError: true,
        );
        return;
      }

      final fraud = await _fraudDetectionService.validateImage(imageFile);
      if (!fraud.passed) {
        _show(fraud.reason, isError: true);
        return;
      }

      final bool withinRateLimit = await repository.canSubmitReport(
        reporterId: user.uid,
      );
      if (!withinRateLimit) {
        _show('Rate limit reached: max 5 reports per hour.', isError: true);
        return;
      }

      final aiResult = await _aiService.analyzeRoadImage(
        imageFile: imageFile,
        userSelectedCategory: selected.name,
      );
      final String analyzedCategory = aiResult.category;

      final exactNearby = await repository.findNearbyDuplicate(
        category: analyzedCategory,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: 20,
      );
      if (exactNearby != null) {
        await repository.supportExistingReport(exactNearby.id);
        if (!mounted) {
          return;
        }
        await HapticService.mediumAction();
        _show('Existing report found within 20m. Support count increased.');
        return;
      }

      final duplicate = await repository.findHighConfidenceDuplicate(
        category: analyzedCategory,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (duplicate != null) {
        final bool supportExisting = await _askSupportExisting(
          confidence: duplicate.confidence,
        );
        if (supportExisting) {
          await repository.supportExistingReport(duplicate.report.id);
          if (!mounted) {
            return;
          }
          await HapticService.mediumAction();
          _show('Supported existing nearby report.');
          return;
        }
      }

      final List<ConnectivityResult> connectivity = await Connectivity()
          .checkConnectivity();
      final bool online = connectivity.any((ConnectivityResult result) {
        return result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet;
      });

      if (!online) {
        await _offlineQueueService.enqueue(
          OfflineReport(
            localReportId: 'local-${DateTime.now().millisecondsSinceEpoch}',
            reporterId: user.uid,
            category: analyzedCategory,
            description: _descriptionCtrl.text.trim(),
            imagePath: imageFile.path,
            latitude: position.latitude,
            longitude: position.longitude,
            createdAt: DateTime.now(),
            syncedFlag: false,
          ),
        );
        if (!mounted) {
          return;
        }
        await HapticService.mediumAction();
        unawaited(
          _analytics.logReportSubmitted(
            category: analyzedCategory,
            priority: priorityForCategory(analyzedCategory),
            queuedOffline: true,
          ),
        );
        _show('No network. Report queued and will sync automatically.');
        return;
      }

      final String imageUrl = await repository.uploadReportImage(
        imageFile,
        user.uid,
      );

      final String reportId = await repository.createReport(
        category: analyzedCategory,
        description: _descriptionCtrl.text.trim(),
        imageUrl: imageUrl,
        latitude: position.latitude,
        longitude: position.longitude,
        reporterId: user.uid,
        imageHash: imageHash,
        imageCapturedAt: await imageFile.lastModified(),
        aiSeverity: aiResult.severity,
        aiConfidence: aiResult.confidence,
        aiBoxes: aiResult.boxes
            .map((box) => box.toMap())
            .toList(growable: false),
      );

      if (!mounted) {
        return;
      }

      final String priority = priorityForCategory(analyzedCategory);
      unawaited(
        _analytics.logReportSubmitted(
          category: analyzedCategory,
          priority: priority,
          queuedOffline: false,
        ),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportConfirmationScreen(
            reportId: reportId,
            category: analyzedCategory,
            status: 'Reported',
            priority: priority,
            latitude: position.latitude,
            longitude: position.longitude,
            onViewReport: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      await HapticService.success();
      setState(_resetWizardState);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _show('Failed to submit report.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<File> _compressImage(File input) async {
    try {
      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        input.path,
        '${input.parent.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg',
        quality: 75,
        minWidth: 1280,
        minHeight: 720,
        keepExif: true,
      );

      if (compressed == null) {
        return input;
      }

      return File(compressed.path);
    } catch (_) {
      return input;
    }
  }

  Future<String> _sha256ForFile(File file) async {
    return compute<String, String>(_hashFileSync, file.path);
  }

  Future<bool> _askSupportExisting({required double confidence}) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Duplicate Issue Found'),
          content: Text(
            'A similar issue was found nearby (${(confidence * 100).toStringAsFixed(0)}% match). Support existing report?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Create New'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Support Existing'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _show(String msg, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  void _resetWizardState() {
    _step = 0;
    _selected = null;
    _image = null;
    _position = null;
    _descriptionCtrl.clear();
  }

  void _onStepContinue() {
    if (_loading) {
      return;
    }
    switch (_step) {
      case 0:
        if (_selected == null) {
          _show('Please select an issue category.', isError: true);
          return;
        }
        setState(() => _step = 1);
        return;
      case 1:
        if (_image == null) {
          _show('Please capture an image to continue.', isError: true);
          return;
        }
        setState(() => _step = 2);
        return;
      case 2:
        if (_position == null) {
          _show('Please detect GPS location to continue.', isError: true);
          return;
        }
        setState(() => _step = 3);
        return;
      case 3:
        _submit();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Infrastructure Issue')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Stepper(
          currentStep: _step,
          onStepContinue: _onStepContinue,
          onStepCancel: () {
            if (_step > 0 && !_loading) {
              setState(() => _step -= 1);
            }
          },
          onStepTapped: (int value) {
            if (!_loading) {
              setState(() => _step = value);
            }
          },
          controlsBuilder: (BuildContext context, ControlsDetails details) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: _loading ? null : details.onStepContinue,
                    child: Text(_step == 3 ? 'Submit' : 'Next'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _loading ? null : details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Select Category'),
              isActive: _step >= 0,
              content: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: issueCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final IssueCategory item = issueCategories[index];
                  final bool selected = _selected?.name == item.name;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (_loading) {
                        return;
                      }
                      setState(() => _selected = item);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected ? AppPalette.accent : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppPalette.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, color: AppPalette.primary),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Step(
              title: const Text('Capture Image'),
              isActive: _step >= 1,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_image == null)
                    const Text('No image captured yet.')
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_image!.path),
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _captureImage,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Capture Image'),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Auto Detect GPS'),
              isActive: _step >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _position == null
                        ? 'Location not captured yet.'
                        : 'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lng: ${_position!.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _autoDetectGps,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Detect GPS'),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Description & Submit'),
              isActive: _step >= 3,
              content: TextField(
                controller: _descriptionCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Add Description',
                  hintText: 'Briefly describe the issue...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _hashFileSync(String path) {
  final File file = File(path);
  final List<int> bytes = file.readAsBytesSync();
  return sha256.convert(bytes).toString();
}
