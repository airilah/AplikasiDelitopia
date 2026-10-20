import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_language.dart';
import 'feature_tour_wrapper.dart' show getSpotlightKey;

/// Tour overlay with spotlight highlighting
class TourOverlay extends ConsumerStatefulWidget {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onPrevious;
  final ModalRoute? creatorRoute;

  const TourOverlay({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
    this.onPrevious,
    this.creatorRoute,
  });

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    widget.creatorRoute?.secondaryAnimation?.addListener(_onRouteChanged);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getTargetRect();
      _controller.forward();
    });
  }

  void _onRouteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.creatorRoute != oldWidget.creatorRoute) {
      oldWidget.creatorRoute?.secondaryAnimation?.removeListener(_onRouteChanged);
      widget.creatorRoute?.secondaryAnimation?.addListener(_onRouteChanged);
    }
  }

  void _getTargetRect() {
    // Try multiple times to get the target
    _tryGetRect(0);
  }

  void _tryGetRect(int attempt) {
    if (attempt > 10) {
      debugPrint('❌ Failed to find target after 10 attempts');
      setState(() {
        _targetRect = null;
      });
      return;
    }

    final RenderBox? renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox != null && renderBox.hasSize) {
      try {
        final position = renderBox.localToGlobal(Offset.zero);
        setState(() {
          _targetRect = position & renderBox.size;
        });
        debugPrint('✅ Spotlight target found: $_targetRect');
      } catch (e) {
        debugPrint('⚠️ Error getting position: $e');
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _tryGetRect(attempt + 1);
        });
      }
    } else {
      debugPrint('⚠️ Spotlight target not ready (attempt ${attempt + 1}/10)');
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _tryGetRect(attempt + 1);
      });
    }
  }

  @override
  void dispose() {
    widget.creatorRoute?.secondaryAnimation?.removeListener(_onRouteChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.creatorRoute != null) {
      final isCurrent = widget.creatorRoute!.isCurrent;
      final secondaryAnimationValue = widget.creatorRoute!.secondaryAnimation?.value ?? 0;
      if (!isCurrent || secondaryAnimationValue > 0) {
        return const SizedBox.shrink();
      }
    }

    final size = MediaQuery.of(context).size;
    
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {}, // Prevent background interactions
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              // Dark overlay with hole for target
              FadeTransition(
                opacity: _fadeAnimation,
                child: CustomPaint(
                  size: size,
                  painter: _SpotlightPainter(
                    targetRect: _targetRect,
                  ),
                ),
              ),

              // Static spotlight border (no pulse)
              if (_targetRect != null)
                Positioned(
                  left: _targetRect!.left - 12,
                  top: _targetRect!.top - 12,
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: _targetRect!.width + 24,
                        height: _targetRect!.height + 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFDD2222).withValues(alpha: 0.9),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDD2222).withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Description card (positioned dynamically to not block target)
              Builder(
                builder: (context) {
                  final screenHeight = size.height;
                  final bool isTargetInBottomHalf = _targetRect != null &&
                      _targetRect!.center.dy > (screenHeight * 0.5);

                  return Positioned(
                    left: 0,
                    right: 0,
                    top: isTargetInBottomHalf
                        ? MediaQuery.of(context).padding.top + 16
                        : null,
                    bottom: !isTargetInBottomHalf ? 0 : null,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildTourCard(),
                      ),
                    ));
                },
              ),
            ],
          ),
        ),
      ));
  }

  Widget _buildTourCard() {
    final lang = ref.watch(appLanguageProvider);
    final stepText = tr
        .get('step_of', lang)
        .replaceAll('{current}', widget.currentStep.toString())
        .replaceAll('{total}', widget.totalSteps.toString());

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stepText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDD2222),
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onSkip,
                child: Text(
                  tr.get('skip', lang),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Navigation buttons
          Row(
            children: [
              if (widget.onPrevious != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onPrevious,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFDD2222)),
                    ),
                    child: Text(
                      tr.get('back', lang),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFFDD2222),
                      ),
                    ),
                  ),
                ),
              if (widget.onPrevious != null) const SizedBox(width: 12),
              Expanded(
                flex: widget.onPrevious != null ? 1 : 2,
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    widget.currentStep == widget.totalSteps
                        ? tr.get('done', lang)
                        : tr.get('continue', lang),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ));
  }
}

/// Custom painter to draw dark overlay with transparent hole
class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  _SpotlightPainter({
    this.targetRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    var path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect != null) {
      // Add rounded rectangle hole for target
      final holePath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              targetRect!.left - 8,
              targetRect!.top - 8,
              targetRect!.right + 8,
              targetRect!.bottom + 8,
            ),
            const Radius.circular(16),
          ));

      path = Path.combine(PathOperation.difference, path, holePath);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

/// Helper widget to wrap a target element with a key for spotlight
class SpotlightTarget extends StatelessWidget {
  final String targetKey;
  final Widget child;

  const SpotlightTarget({
    super.key,
    required this.targetKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Get or create the global key for this target
    final globalKey = getSpotlightKey(targetKey);
    
    return Container(
      key: globalKey,
      child: child);
  }
}
