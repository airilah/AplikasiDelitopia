/// Onboarding step model
class OnboardingStep {
  final String title;
  final String description;
  final String? image;
  final String? lottieAnimation;
  final OnboardingAction? action;

  const OnboardingStep({
    required this.title,
    required this.description,
    this.image,
    this.lottieAnimation,
    this.action,
  });
}

/// Action to perform after onboarding step
class OnboardingAction {
  final String label;
  final String route;

  const OnboardingAction({
    required this.label,
    required this.route,
  });
}

/// Feature tour step for in-app guides
class FeatureTourStep {
  final String featureKey;
  final String title;
  final String description;
  final List<TourSpotlight> spotlights;
  final int order;

  const FeatureTourStep({
    required this.featureKey,
    required this.title,
    required this.description,
    required this.spotlights,
    required this.order,
  });
}

/// Spotlight highlight for a specific UI element
class TourSpotlight {
  final String targetKey;
  final String title;
  final String description;
  final SpotlightShape shape;
  final int order;

  const TourSpotlight({
    required this.targetKey,
    required this.title,
    required this.description,
    this.shape = SpotlightShape.circle,
    required this.order,
  });
}

enum SpotlightShape {
  circle,
  rectangle,
  roundedRectangle,
}
