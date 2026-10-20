import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_language.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/feature_spotlight.dart';

// Global map to store keys for spotlight targets
final Map<String, GlobalKey> _spotlightKeys = {};

GlobalKey getSpotlightKey(String key) {
  if (!_spotlightKeys.containsKey(key)) {
    _spotlightKeys[key] = GlobalKey();
    debugPrint('🔑 Created new GlobalKey for: $key');
  } else {
    debugPrint('♻️ Reusing existing GlobalKey for: $key');
  }
  return _spotlightKeys[key]!;
}

/// Wrapper widget to show feature tour on first visit
class FeatureTourWrapper extends ConsumerStatefulWidget {
  final String featureKey;
  final Widget child;
  final bool enabled;
  final ScrollController? scrollController;

  const FeatureTourWrapper({
    super.key,
    required this.featureKey,
    required this.child,
    this.enabled = true,
    this.scrollController,
  });

  @override
  ConsumerState<FeatureTourWrapper> createState() => _FeatureTourWrapperState();
}

class _FeatureTourWrapperState extends ConsumerState<FeatureTourWrapper> {
  static String? _activeFeatureKey;

  int _currentStep = 0;
  OverlayEntry? _overlayEntry;
  ScrollController? _scrollController;
  bool _isCheckingTour = false;
  bool _isShowingTour = false;
  bool _isUpdatingOverlay = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController;
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowTour();
      });
    }
  }

  @override
  void didUpdateWidget(FeatureTourWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _removeOverlay();
      if (_activeFeatureKey == widget.featureKey) {
        _activeFeatureKey = null;
      }
      _isCheckingTour = false;
      _isShowingTour = false;
      _isUpdatingOverlay = false;
      return;
    }

    if (widget.enabled && !oldWidget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowTour();
      });
    }
  }

  /// Manually start the tour (called by FeatureTourButton)
  void startTour() {
    _showOverlay();
  }

  @override
  void dispose() {
    _removeOverlay();
    if (_activeFeatureKey == widget.featureKey) {
      _activeFeatureKey = null;
    }
    _isCheckingTour = false;
    _isShowingTour = false;
    _isUpdatingOverlay = false;
    super.dispose();
  }

  Future<void> _checkAndShowTour() async {
    if (_isCheckingTour ||
        _isShowingTour ||
        _isUpdatingOverlay ||
        _overlayEntry != null ||
        _activeFeatureKey != null) {
      return;
    }

    _isCheckingTour = true;

    final service = ref.read(onboardingServiceProvider);
    final hasCompleted = await service.hasCompletedFeatureTour(widget.featureKey);
    
    debugPrint('🎯 Feature Tour [${widget.featureKey}]: hasCompleted = $hasCompleted');
    
    if (!hasCompleted && mounted) {
      // Small delay to ensure widgets are rendered
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted &&
          !_isShowingTour &&
          !_isUpdatingOverlay &&
          _overlayEntry == null &&
          _activeFeatureKey == null) {
        _showOverlay();
      }
    } else {
      debugPrint('⏭️ Tour ${widget.featureKey} skipped (completed or unmounted)');
    }
    _isCheckingTour = false;
  }

  void _showOverlay() {
    if (_isShowingTour ||
        _isUpdatingOverlay ||
        _overlayEntry != null ||
        _activeFeatureKey != null) {
      return;
    }

    final service = ref.read(onboardingServiceProvider);
    final lang = ref.read(appLanguageProvider);
    final spotlights = service.getFeatureTourSpotlights(widget.featureKey, lang);
    
    debugPrint('📍 Tour ${widget.featureKey}: ${spotlights.length} spotlight steps');
    
    if (spotlights.isEmpty) {
      debugPrint('⚠️ No spotlight steps found for ${widget.featureKey}');
      return;
    }

    _activeFeatureKey = widget.featureKey;
    _isShowingTour = true;

    setState(() {
      _currentStep = 0;
    });

    _updateOverlay();
  }

  Future<void> _scrollToTarget(
    GlobalKey targetKey, {
    required String targetKeyName,
  }) async {
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox != null && _scrollController != null && _scrollController!.hasClients) {
      final position = renderBox.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;
      final isVoucherSection = targetKeyName.startsWith('vouchers_') &&
          targetKeyName.endsWith('_section');
      final targetScreenOffset = isVoucherSection
          ? MediaQuery.of(context).padding.top + 96
          : (screenHeight / 2) - (renderBox.size.height / 2);
      
      // Voucher sections should land below the app bar; other tours stay centered.
      final targetScrollPosition =
          _scrollController!.offset + position.dy - targetScreenOffset;
      
      await _scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, _scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut);
      
      // Wait for scroll to complete
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  Future<void> _updateOverlay() async {
    if (_isUpdatingOverlay) return;

    _isUpdatingOverlay = true;
    _removeOverlay();

    final service = ref.read(onboardingServiceProvider);
    final lang = ref.read(appLanguageProvider);
    final spotlights = service.getFeatureTourSpotlights(widget.featureKey, lang);

    if (_currentStep >= spotlights.length) {
      _isUpdatingOverlay = false;
      return;
    }

    final currentSpotlight = spotlights[_currentStep];
    final targetKey = getSpotlightKey(currentSpotlight.targetKey);

    debugPrint('🎯 Showing spotlight for: ${currentSpotlight.targetKey}');
    debugPrint('🔍 GlobalKey has context: ${targetKey.currentContext != null}');

    // Scroll to target if available
    if (targetKey.currentContext != null) {
      await _scrollToTarget(
        targetKey,
        targetKeyName: currentSpotlight.targetKey,
      );
    }

    if (!mounted || _activeFeatureKey != widget.featureKey) {
      _isUpdatingOverlay = false;
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => TourOverlay(
        targetKey: targetKey,
        title: currentSpotlight.title,
        description: currentSpotlight.description,
        currentStep: _currentStep + 1,
        totalSteps: spotlights.length,
        onNext: _nextStep,
        onSkip: _skipTour,
        onPrevious: _currentStep > 0 ? _previousStep : null,
        creatorRoute: ModalRoute.of(this.context),
      ));

    Overlay.of(context).insert(_overlayEntry!);
    _isUpdatingOverlay = false;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _updateOverlay();
    }
  }

  void _nextStep() {
    final service = ref.read(onboardingServiceProvider);
    final lang = ref.read(appLanguageProvider);
    final spotlights = service.getFeatureTourSpotlights(widget.featureKey, lang);
    
    if (_currentStep < spotlights.length - 1) {
      setState(() {
        _currentStep++;
      });
      _updateOverlay();
    } else {
      _completeTour();
    }
  }

  void _skipTour() {
    _completeTour();
  }

  Future<void> _completeTour() async {
    final service = ref.read(onboardingServiceProvider);
    await service.completeFeatureTour(widget.featureKey);
    
    _removeOverlay();
    if (_activeFeatureKey == widget.featureKey) {
      _activeFeatureKey = null;
    }
    _isCheckingTour = false;
    _isShowingTour = false;
    _isUpdatingOverlay = false;
    setState(() {
      _overlayEntry = null;
    });// Invalidate the provider to trigger rebuild in listening widgets
    ref.invalidate(hasCompletedFeatureTourProvider(widget.featureKey));
    
    // Force parent widget to rebuild
    if (mounted) {
      // Trigger a rebuild of the entire tree to update demo data visibility
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Button to manually trigger feature tour
class FeatureTourButton extends ConsumerWidget {
  final String featureKey;

  const FeatureTourButton({
    super.key,
    required this.featureKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: tr.get('show_feature_guide', ref.watch(appLanguageProvider)),
      onPressed: () async {
        final service = ref.read(onboardingServiceProvider);
        // Reset the feature tour
        await service.resetFeatureTour(featureKey);
        
        if (!context.mounted) return;
        // Find the FeatureTourWrapper and start the tour
        final tourState = context.findAncestorStateOfType<_FeatureTourWrapperState>();
        if (tourState != null) {
          tourState.startTour();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr.get('reload_to_view_guide', ref.read(appLanguageProvider)),
              ),
              duration: const Duration(seconds: 2),
            ));
        }
      });
  }
}

/// Settings option to reset onboarding
class ResetOnboardingTile extends ConsumerWidget {
  const ResetOnboardingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.restart_alt_rounded,
          color: Color(0xFFDD2222),
          size: 20,
        ),
      ),
      title: Text(
        tr.get('reset_tour', lang),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF242424),
        ),
      ),
      subtitle: Text(
        tr.get('reset_tour_sub', lang),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr.get('reset_tour_dialog_title', lang)),
            content: Text(tr.get('reset_tour_dialog_message', lang)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr.get('cancel', lang)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                  foregroundColor: Colors.white,
                ),
                child: Text(tr.get('reset', lang)),
              ),
            ],
          ));

        if (confirmed == true) {
          final service = ref.read(onboardingServiceProvider);
          await service.resetOnboarding();
          
          ref.invalidate(hasCompletedOnboardingProvider);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr.get('reset_tour_success', lang)),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ));
          }
        }
      });
  }
}
