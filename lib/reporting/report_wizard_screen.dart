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
<<<<<<< HEAD

import '../models/offline_report.dart';
import '../services/fraud_detection_service.dart';
import '../services/haptic_service.dart';
import '../services/analytics_service.dart';
import '../services/offline/offline_queue_service.dart';
import '../ui_theme/app_theme.dart';
import 'ai_placeholder_service.dart';
import 'report_config.dart';
import 'report_confirmation_screen.dart';
=======
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/ai_result.dart';
import '../models/offline_report.dart';
import '../models/report_model.dart';
import '../services/ai_detection_service.dart';
import '../services/analytics_service.dart';
import '../services/fraud_detection_service.dart';
import '../services/haptic_service.dart';
import '../services/offline/offline_queue_service.dart';
import '../ui_theme/ai_result_card.dart';
import '../ui_theme/app_theme.dart';
import 'report_config.dart';
import 'report_detail_screen.dart';
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
  final AiPlaceholderService _aiService = AiPlaceholderService();
=======
  final AiDetectionService _aiService = AiDetectionService();
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  final FraudDetectionService _fraudDetectionService = FraudDetectionService();
  final OfflineQueueService _offlineQueueService = OfflineQueueService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  int _step = 0;
  IssueCategory? _selected;
  XFile? _image;
  Position? _position;
  bool _loading = false;
<<<<<<< HEAD
=======
  bool _processingImage = false;
  File? _preparedImageFile;
  String? _imageHash;
  AiResult? _aiResult;
  String? _aiMessage;

  @override
  void initState() {
    super.initState();
    _resetWizard(notify: false);
    unawaited(_recoverLostImage());
  }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

<<<<<<< HEAD
  Future<void> _captureImage() async {
    if (_loading) {
=======
  void _resetWizard({bool notify = true}) {
    void apply() {
      _step = 0;
      _selected = null;
      _image = null;
      _position = null;
      _loading = false;
      _processingImage = false;
      _preparedImageFile = null;
      _imageHash = null;
      _aiResult = null;
      _aiMessage = null;
      _descriptionCtrl.clear();
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<File> _cameraRecoveryMarkerFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pending_camera_capture.marker');
  }

  Future<void> _setCaptureRecoveryPending(bool pending) async {
    try {
      final File marker = await _cameraRecoveryMarkerFile();
      if (pending) {
        if (!await marker.exists()) {
          await marker.create(recursive: true);
        }
      } else if (await marker.exists()) {
        await marker.delete();
      }
    } catch (_) {
      // Ignore marker persistence failures; capture flow must continue.
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final File marker = await _cameraRecoveryMarkerFile();
      if (!await marker.exists()) {
        return;
      }

      final LostDataResponse response = await _picker.retrieveLostData();
      final List<XFile>? files = response.files;
      if (files == null || files.isEmpty) {
        await _setCaptureRecoveryPending(false);
        return;
      }

      final XFile recovered = files.first;
      if (recovered.path.isEmpty) {
        return;
      }

      final File imageFile = File(recovered.path);
      if (!await imageFile.exists()) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _image = recovered;
        _preparedImageFile = null;
        _imageHash = null;
        _aiResult = null;
        _aiMessage = null;
        if (_step < 2) {
          _step = _selected == null ? 1 : 2;
        }
      });

      if (_selected != null) {
        unawaited(_prepareCapturedImage(recovered));
      }
      await _setCaptureRecoveryPending(false);
    } catch (_) {
      await _setCaptureRecoveryPending(false);
      if (!mounted) {
        return;
      }
      _show(
        'Recovered image could not be processed. Please capture again.',
        isError: true,
      );
    }
  }

  Future<void> _captureImage() async {
    if (_loading || _processingImage) {
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      return;
    }

    try {
<<<<<<< HEAD
=======
      final PermissionStatus cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (!mounted) {
          return;
        }
        _show(
          'Camera permission is required to capture an image.',
          isError: true,
        );
        return;
      }

      await _setCaptureRecoveryPending(true);
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      final XFile? photo = widget.captureImageOverride != null
          ? await widget.captureImageOverride!()
          : await _picker.pickImage(
              source: ImageSource.camera,
<<<<<<< HEAD
              imageQuality: 75,
            );
      if (photo == null || !mounted) {
=======
              imageQuality: 80,
              maxWidth: 1280,
              maxHeight: 1280,
            );
      await _setCaptureRecoveryPending(false);
      if (photo == null) {
        return;
      }
      if (photo.path.isEmpty) {
        if (!mounted) {
          return;
        }
        _show('Captured image is invalid. Please try again.', isError: true);
        return;
      }

      final File imageFile = File(photo.path);
      if (!await imageFile.exists()) {
        if (!mounted) {
          return;
        }
        _show(
          'Captured image could not be loaded. Please try again.',
          isError: true,
        );
        return;
      }

      if (!mounted) {
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        return;
      }

      setState(() {
        _image = photo;
<<<<<<< HEAD
        _step = 2;
      });
    } catch (_) {
=======
        _preparedImageFile = null;
        _imageHash = null;
        _aiResult = null;
        _aiMessage = null;
        _step = 2;
      });
      unawaited(_prepareCapturedImage(photo));
    } catch (_) {
      await _setCaptureRecoveryPending(false);
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      if (!mounted) {
        return;
      }
      _show('Could not capture image. Please try again.', isError: true);
    }
  }

<<<<<<< HEAD
  Future<void> _autoDetectGps() async {
    if (_loading) {
=======
  Future<void> _prepareCapturedImage(XFile photo) async {
    final IssueCategory? selected = _selected;
    if (selected == null) {
      return;
    }

    if (mounted) {
      setState(() => _processingImage = true);
    }

    try {
      final File originalFile = File(photo.path);
      if (!await originalFile.exists()) {
        throw const FileSystemException('Captured image file not found');
      }
      final File preparedImage = await _compressImage(originalFile);
      final String imageHash = await _sha256ForFile(preparedImage);

      final ReportRepository? repository = widget.repository;
      if (repository != null) {
        final bool duplicateHash = await repository.hasRecentImageHash(
          imageHash,
        );
        if (duplicateHash) {
          if (!mounted) {
            return;
          }
          setState(() {
            _preparedImageFile = preparedImage;
            _imageHash = null;
            _aiResult = null;
            _aiMessage = null;
          });
          _show(
            'This image appears reused from an existing report. Please capture a fresh photo.',
            isError: true,
          );
          return;
        }
      }

      final fraud = await _fraudDetectionService.validateImage(preparedImage);
      if (!mounted) {
        return;
      }
      if (!fraud.passed) {
        setState(() {
          _preparedImageFile = preparedImage;
          _imageHash = imageHash;
          _aiResult = null;
          _aiMessage = null;
        });
        _show(fraud.reason, isError: true);
        return;
      }

      final AiResult result = await _aiService.analyzeRoadImage(
        imageFile: preparedImage,
        fallbackCategory: selected.name,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _preparedImageFile = preparedImage;
        _imageHash = imageHash;
        _aiResult = result;
        _aiMessage = result.isFallback
            ? 'AI unavailable — manual selection enabled'
            : result.confidence < 0.6
            ? 'Confidence is below 60%. You can override the category manually.'
            : null;
        _step = 2;
      });
      _applyAiSuggestion(result);
      if (result.isFallback) {
        _show('AI unavailable — manual selection enabled', isError: true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _show(
        'Image processing failed. The original image was kept, so you can continue or recapture.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _processingImage = false);
      }
    }
  }

  void _applyAiSuggestion(AiResult result) {
    if (!mounted || result.isFallback) {
      return;
    }
    if (result.detectedLabel?.toLowerCase() != 'pothole' ||
        result.confidence < 0.6) {
      return;
    }

    final IssueCategory potholeCategory = issueCategories.firstWhere(
      (IssueCategory item) => item.name == 'Pothole',
      orElse: () => issueCategories.first,
    );
    setState(() => _selected = potholeCategory);
  }

  String _displayDetectedLabel(AiResult result) {
    final String label = result.detectedLabel ?? result.category;
    if (label.isEmpty) {
      return result.category;
    }
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  Future<void> _autoDetectGps() async {
    if (_loading || _processingImage) {
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD

      debugPrint(
        'GPS Coordinates -> Latitude: ${position.latitude}, Longitude: ${position.longitude}',
      );
=======
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
=======
    if (_processingImage) {
      _show('Image processing is still running. Please wait.', isError: true);
      return;
    }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

    setState(() => _loading = true);

    try {
<<<<<<< HEAD
      final File imageFile = await _compressImage(File(image.path));
      final String imageHash = await _sha256ForFile(imageFile);

      final bool duplicateHash = await repository.hasRecentImageHash(imageHash);
      if (duplicateHash) {
        _show(
          'This image appears reused from an existing report. Please capture a fresh photo.',
          isError: true,
        );
        return;
=======
      final File originalImageFile = File(image.path);
      if (!await originalImageFile.exists()) {
        throw const FileSystemException(
          'Selected image file could not be found',
        );
      }

      File imageFile = _preparedImageFile ?? originalImageFile;
      if (!await imageFile.exists()) {
        imageFile = await _compressImage(originalImageFile);
      }
      if (!await imageFile.exists()) {
        imageFile = originalImageFile;
      }

      final String imageHash = _imageHash ?? await _sha256ForFile(imageFile);

      if (_imageHash == null) {
        final bool duplicateHash = await repository.hasRecentImageHash(
          imageHash,
        );
        if (duplicateHash) {
          _show(
            'This image appears reused from an existing report. Please capture a fresh photo.',
            isError: true,
          );
          return;
        }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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

<<<<<<< HEAD
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
=======
      final AiResult aiResult =
          _aiResult ??
          await _aiService.analyzeRoadImage(
            imageFile: imageFile,
            fallbackCategory: selected.name,
          );
      if (aiResult.isFallback) {
        _aiMessage ??= 'AI unavailable — manual selection enabled';
      }
      final bool shouldUseAiCategory =
          !aiResult.isFallback &&
          aiResult.detectedLabel?.toLowerCase() == 'pothole' &&
          aiResult.confidence >= 0.6;
      final String analyzedCategory = shouldUseAiCategory
          ? aiResult.category
          : selected.name;

      final ReportModel? exactNearby = await repository.findNearbyDuplicate(
        category: analyzedCategory,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: 40,
      );
      if (exactNearby != null) {
        await repository.supportExistingReport(
          exactNearby.id,
          citizenId: user.uid,
        );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        if (!mounted) {
          return;
        }
        await HapticService.mediumAction();
<<<<<<< HEAD
        _show('Existing report found within 20m. Support count increased.');
=======
        _show('Existing report found within 40m. Support count increased.');
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
          await repository.supportExistingReport(duplicate.report.id);
=======
          await repository.supportExistingReport(
            duplicate.report.id,
            citizenId: user.uid,
          );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
=======
        final File persistedImage = await _persistOfflineImage(imageFile);
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        await _offlineQueueService.enqueue(
          OfflineReport(
            localReportId: 'local-${DateTime.now().millisecondsSinceEpoch}',
            reporterId: user.uid,
            category: analyzedCategory,
            description: _descriptionCtrl.text.trim(),
<<<<<<< HEAD
            imagePath: imageFile.path,
=======
            imagePath: persistedImage.path,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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

<<<<<<< HEAD
=======
      final String priority = priorityForCategory(analyzedCategory);
      final ReportModel report =
          await repository.getReportById(reportId) ??
          ReportModel(
            id: reportId,
            category: analyzedCategory,
            description: _descriptionCtrl.text.trim(),
            imageUrl: imageUrl,
            latitude: position.latitude,
            longitude: position.longitude,
            priority: priority,
            status: 'Reported',
            reporterId: user.uid,
            reportCount: 1,
            timestamp: DateTime.now(),
            aiSeverity: aiResult.severity,
            aiConfidence: aiResult.confidence,
            aiBoxes: aiResult.boxes,
          );

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      if (!mounted) {
        return;
      }

<<<<<<< HEAD
      final String priority = priorityForCategory(analyzedCategory);
=======
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      unawaited(
        _analytics.logReportSubmitted(
          category: analyzedCategory,
          priority: priority,
          queuedOffline: false,
        ),
      );
<<<<<<< HEAD
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
=======
      _show('Report submitted successfully ✅');
      await HapticService.success();
      if (!mounted) {
        return;
      }
      _resetWizard();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ReportDetailScreen(report: report, repository: repository),
        ),
      );
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSubmitFailure(error);
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<File> _compressImage(File input) async {
    try {
<<<<<<< HEAD
=======
      if (!input.existsSync()) {
        return input;
      }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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

<<<<<<< HEAD
=======
  void _showSubmitFailure(Object error) {
    final bool retryable =
        error is FirebaseException ||
        error is SocketException ||
        error is TimeoutException;
    final String errorText = error.toString().toLowerCase();
    final bool uploadFailed =
        errorText.contains('upload') || errorText.contains('storage');

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            uploadFailed
                ? 'Upload failed, try again'
                : retryable
                ? 'Submission failed. Check your network and retry.'
                : 'Failed to submit report.',
          ),
          backgroundColor: Colors.red,
          action: retryable
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => unawaited(_submit()),
                )
              : null,
        ),
      );
  }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  Future<String> _sha256ForFile(File file) async {
    return compute<String, String>(_hashFileSync, file.path);
  }

<<<<<<< HEAD
=======
  Future<File> _persistOfflineImage(File imageFile) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory offlineDir = Directory('${dir.path}/offline_reports');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }

    final String extension = imageFile.path.contains('.')
        ? imageFile.path.split('.').last
        : 'jpg';
    final File persisted = File(
      '${offlineDir.path}/offline_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    return imageFile.copy(persisted.path);
  }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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

<<<<<<< HEAD
  void _resetWizardState() {
    _step = 0;
    _selected = null;
    _image = null;
    _position = null;
    _descriptionCtrl.clear();
  }

  void _onStepContinue() {
    if (_loading) {
=======
  void _onStepContinue() {
    if (_loading || _processingImage) {
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
        _submit();
=======
        unawaited(_submit());
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        return;
    }
  }

<<<<<<< HEAD
=======
  Widget _buildImagePreview() {
    final File? previewFile = _preparedImageFile;
    final XFile? image = _image;
    if (previewFile == null && image == null) {
      return const Text('No image captured yet.');
    }
    if (previewFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(previewFile, height: 180, fit: BoxFit.cover),
      );
    }
    if (image == null || image.path.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 40),
            SizedBox(height: 8),
            Text('Image captured'),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(File(image.path), height: 180, fit: BoxFit.cover),
    );
  }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Infrastructure Issue')),
<<<<<<< HEAD
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
=======
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stepper(
                currentStep: _step,
                onStepContinue: _onStepContinue,
                onStepCancel: () {
                  if (_step > 0 && !_loading && !_processingImage) {
                    setState(() => _step -= 1);
                  }
                },
                onStepTapped: (int value) {
                  if (!_loading && !_processingImage) {
                    setState(() => _step = value);
                  }
                },
                controlsBuilder:
                    (BuildContext context, ControlsDetails details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: (_loading || _processingImage)
                                  ? null
                                  : details.onStepContinue,
                              child: Text(_step == 3 ? 'Submit' : 'Next'),
                            ),
                            TextButton(
                              onPressed: (_loading || _processingImage)
                                  ? null
                                  : details.onStepCancel,
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                            if (_loading || _processingImage) {
                              return;
                            }
                            setState(() {
                              _selected = item;
                              _aiResult = null;
                              _aiMessage = null;
                            });
                            final XFile? image = _image;
                            if (image != null) {
                              unawaited(_prepareCapturedImage(image));
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppPalette.accent
                                  : Theme.of(context).colorScheme.surface,
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
                        _buildImagePreview(),
                        if (_image != null) ...[
                          const SizedBox(height: 10),
                          if (_processingImage)
                            const AiLoadingCard()
                          else if (_aiResult != null)
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Analysis',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Detected: ${_displayDetectedLabel(_aiResult!)}',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Confidence: ${(_aiResult!.confidence * 100).toStringAsFixed(0)}%',
                                    ),
                                    if (_aiMessage != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _aiMessage!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          else if (_aiMessage != null)
                            AiErrorCard(message: _aiMessage!),
                        ],
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: (_loading || _processingImage)
                              ? null
                              : _captureImage,
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
                          onPressed: (_loading || _processingImage)
                              ? null
                              : _autoDetectGps,
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
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            'Submitting report...',
                            style: Theme.of(context).textTheme.titleMedium,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
                          ),
                        ],
                      ),
                    ),
<<<<<<< HEAD
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
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _descriptionCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Add Description',
                      hintText: 'Briefly describe the issue...',
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Analyzing image and submitting...'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
=======
                  ),
                ),
              ),
            ),
        ],
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      ),
    );
  }
}

String _hashFileSync(String path) {
  final File file = File(path);
<<<<<<< HEAD
=======
  if (!file.existsSync()) {
    return sha256.convert(const <int>[]).toString();
  }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  final List<int> bytes = file.readAsBytesSync();
  return sha256.convert(bytes).toString();
}
