// Beautiful AI result display card with animations.
// Shows pothole detection results with confidence, color coding, and icons.

import 'package:flutter/material.dart';
import '../services/flask_pothole_service.dart';
import '../ui_theme/app_theme.dart';

/// Animated card displaying pothole detection result
class AiPotholeResultCard extends StatefulWidget {
  final PotholeDetectionResult result;
  final VoidCallback? onDismiss;
  final Duration animationDuration;

  const AiPotholeResultCard({
    super.key,
    required this.result,
    this.onDismiss,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<AiPotholeResultCard> createState() => _AiPotholeResultCardState();
}

class _AiPotholeResultCardState extends State<AiPotholeResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Fade in from 0 to 1
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Scale in from 0.8 to 1.0
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Slide from bottom
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(scale: _scaleAnimation, child: _buildCard()),
      ),
    );
  }

  Widget _buildCard() {
    final bool isPothole = widget.result.isPothole;
    final Color cardColor = isPothole
        ? Color(0xFFEF5350) // Red for pothole
        : Color(0xFF66BB6A); // Green for normal
    final Color backgroundColor = cardColor.withValues(alpha: 0.1);
    final String icon = isPothole ? '⚠️' : '✅';
    final String prediction = widget.result.predictionText;
    final int confidence = widget.result.confidencePercent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and title
            Row(
              children: [
                // Icon
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_controller.value * 0.2),
                      child: Text(icon, style: const TextStyle(fontSize: 32)),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Title and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Analysis',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cardColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prediction,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: cardColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Confidence section with progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Confidence',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppPalette.text.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      '$confidence%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cardColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Animated progress bar
                _buildConfidenceProgressBar(confidence, cardColor),
              ],
            ),

            const SizedBox(height: 12),

            // Info text
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isPothole ? Icons.warning_amber : Icons.check_circle,
                    size: 18,
                    color: cardColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPothole
                          ? 'Pothole detected. Category auto-set to High priority.'
                          : 'Normal road surface. Please select category manually.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: cardColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceProgressBar(int confidence, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        minHeight: 6,
        value: confidence / 100.0,
        backgroundColor: color.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Loading indicator while AI is analyzing
class AiLoadingCard extends StatefulWidget {
  const AiLoadingCard({super.key});

  @override
  State<AiLoadingCard> createState() => _AiLoadingCardState();
}

class _AiLoadingCardState extends State<AiLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.5,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.primary, width: 1.5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppPalette.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Analyzing image…',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI is detecting potholes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state when AI analysis fails
class AiErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AiErrorCard({
    super.key,
    this.message = 'AI analysis failed. You can continue manually.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Analysis'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
