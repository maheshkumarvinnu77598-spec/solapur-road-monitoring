import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  static Future<void> lightTap() async {
    await _safe(HapticFeedback.selectionClick);
  }

  static Future<void> mediumAction() async {
    await _safe(HapticFeedback.mediumImpact);
  }

  static Future<void> success() async {
    await _safe(HapticFeedback.heavyImpact);
  }

  static Future<void> _safe(Future<void> Function() action) async {
    if (kIsWeb) {
      return;
    }
    try {
      // Platform haptics automatically respect user/device vibration settings.
      await action();
    } catch (_) {
      // Ignore unsupported-device haptic failures.
    }
  }
}
