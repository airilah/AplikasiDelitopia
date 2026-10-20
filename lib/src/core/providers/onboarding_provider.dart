import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/onboarding_service.dart';

/// Provider for onboarding service
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

/// Provider to check if onboarding is completed
final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(onboardingServiceProvider);
  return service.hasCompletedOnboarding();
});

/// Provider to check if a specific feature tour is completed
final hasCompletedFeatureTourProvider =
    FutureProvider.family<bool, String>((ref, featureKey) async {
  final service = ref.watch(onboardingServiceProvider);
  return service.hasCompletedFeatureTour(featureKey);
});

/// Provider to get completed feature tours
final completedFeatureToursProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(onboardingServiceProvider);
  return service.getCompletedFeatureTours();
});
