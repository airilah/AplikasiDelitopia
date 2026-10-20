import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_language.dart';
import '../models/onboarding_model.dart';
import '../services/onboarding_service.dart';

/// Onboarding screen with step-by-step introduction
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.onSkip,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final lang = ref.read(appLanguageProvider);
    final steps = _onboardingService.getOnboardingSteps(lang);

    if (_currentPage < steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    }
  }

  void _skipOnboarding() async {
    await _onboardingService.skipOnboarding();
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      widget.onComplete();
    }
  }

  void _completeOnboarding() async {
    await _onboardingService.completeOnboarding();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final steps = _onboardingService.getOnboardingSteps(lang);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, size: 16),
                          const SizedBox(width: 4),
                          Text(tr.get('back', lang)),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 80),
                  if (_currentPage < steps.length - 1)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        tr.get('skip', lang),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 80),
                ],
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(steps[index]);
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  steps.length,
                  (index) => _buildPageIndicator(index),
                ),
              ),
            ),

            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == steps.length - 1
                        ? steps[_currentPage].action?.label ??
                            tr.get('start', lang)
                        : tr.get('next', lang),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image or animation placeholder
          Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Icon(
                _getIconForStep(step),
                size: 120,
                color: const Color(0xFFDD2222).withValues(alpha: 0.3),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            step.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ));
  }

  Widget _buildPageIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? const Color(0xFFDD2222)
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ));
  }

  IconData _getIconForStep(OnboardingStep step) {
    if (step.title.contains('Welcome')) return Icons.waving_hand;
    if (step.title.contains('Menu')) return Icons.restaurant_menu;
    if (step.title.contains('Points')) return Icons.stars;
    if (step.title.contains('Vouchers')) return Icons.card_giftcard;
    if (step.title.contains('Order')) return Icons.shopping_bag;
    return Icons.info;
  }
}
