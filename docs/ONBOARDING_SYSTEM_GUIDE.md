# User Onboarding System - Implementation Guide

## 📚 Overview

The onboarding system provides a comprehensive user introduction experience with:
- **Initial onboarding slides** - Step-by-step app introduction
- **Feature tours** - Contextual guides for specific features
- **Skippable at any time** - Users can skip and return later
- **Persistent state** - Remembers which tours have been completed

---

## 🎯 Components

### 1. Models
- `OnboardingStep` - Represents a single onboarding slide
- `FeatureTourStep` - Represents a feature tour
- `TourSpotlight` - Individual spotlight highlight

### 2. Services
- `OnboardingService` - Manages onboarding state and persistence

### 3. Widgets
- `OnboardingScreen` - Full-screen onboarding slides
- `FeatureSpotlight` - Overlay to highlight UI elements
- `FeatureTourWrapper` - Wrapper to auto-show tours
- `FeatureTourButton` - Manual tour trigger
- `ResetOnboardingTile` - Settings option to reset

### 4. Providers
- `onboardingServiceProvider` - Service instance
- `hasCompletedOnboardingProvider` - Check if onboarding done
- `hasCompletedFeatureTourProvider` - Check specific feature tour

---

## 🚀 Quick Start Integration

### Step 1: Update App Router

Add onboarding route to `app_router.dart`:

```dart
import 'package:go_router/go_router.dart';
import '../widgets/onboarding_screen.dart';
import '../providers/onboarding_provider.dart';

class AppRouter {
  static const String onboarding = '/onboarding';
  
  static final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      // Check if user completed onboarding
      final container = ProviderContainer();
      final hasCompleted = await container.read(
        hasCompletedOnboardingProvider.future
      );
      
      // If not completed and not already on onboarding page
      if (!hasCompleted && state.location != onboarding) {
        return onboarding;
      }
      
      return null; // No redirect
    },
    routes: [
      GoRoute(
        path: onboarding,
        builder: (context, state) => OnboardingScreen(
          onComplete: () {
            context.go('/navigation');
          },
        ),
      ),
      // ... other routes
    ],
  );
}
```

### Step 2: Add Feature Tour to Pages

Wrap any page with `FeatureTourWrapper`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/feature_tour_wrapper.dart';

class VouchersView extends ConsumerWidget {
  const VouchersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureTourWrapper(
      featureKey: 'vouchers', // Unique key for this feature
      enabled: true, // Set to false to disable tour
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vouchers'),
          actions: [
            // Optional: Add manual tour trigger
            FeatureTourButton(featureKey: 'vouchers'),
          ],
        ),
        body: _buildContent(context, ref),
      ),
    );
  }
}
```

### Step 3: Add Spotlight Targets (Optional)

Wrap UI elements you want to highlight:

```dart
import '../../core/widgets/feature_spotlight.dart';

Widget build(BuildContext context) {
  return Column(
    children: [
      SpotlightTarget(
        targetKey: 'vouchers_points_card',
        child: _buildPointsCard(),
      ),
      SpotlightTarget(
        targetKey: 'vouchers_free_section',
        child: _buildFreeVouchersSection(),
      ),
    ],
  );
}
```

### Step 4: Add Reset Option to Settings

Add to your settings page:

```dart
import '../../core/widgets/feature_tour_wrapper.dart';

class SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // ... other settings
        const ResetOnboardingTile(),
      ],
    );
  }
}
```

---

## 📝 Customization

### Add New Onboarding Steps

Edit `onboarding_service.dart`:

```dart
List<OnboardingStep> getOnboardingSteps() {
  return [
    const OnboardingStep(
      title: 'Your Custom Title',
      description: 'Your custom description',
      image: 'assets/images/custom.png', // Optional
    ),
    // Add more steps...
  ];
}
```

### Add New Feature Tours

Edit `onboarding_service.dart`:

```dart
List<TourSpotlight> getFeatureTourSpotlights(String featureKey) {
  switch (featureKey) {
    case 'your_feature':
      return [
        const TourSpotlight(
          targetKey: 'element_1',
          title: 'Feature Element',
          description: 'This is what it does',
          order: 1,
        ),
        // Add more spotlights...
      ];
    default:
      return [];
  }
}
```

---

## 🎨 Styling

### Customize Onboarding Theme

Edit `onboarding_screen.dart`:

```dart
// Change primary color
backgroundColor: const Color(0xFFYOURCOLOR),

// Change button style
ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFFYOURCOLOR),
  // ... other styles
)
```

### Customize Spotlight Overlay

Edit `feature_spotlight.dart`:

```dart
// Change overlay opacity
color: Colors.black.withOpacity(0.7), // Adjust value

// Change spotlight glow color
BoxShadow(
  color: const Color(0xFFYOURCOLOR).withOpacity(0.5),
  // ...
)
```

---

## 🔧 API Reference

### OnboardingService Methods

```dart
// Check if onboarding completed
Future<bool> hasCompletedOnboarding()

// Mark onboarding as completed
Future<void> completeOnboarding()

// Skip onboarding
Future<void> skipOnboarding()

// Check if feature tour completed
Future<bool> hasCompletedFeatureTour(String featureKey)

// Mark feature tour as completed
Future<void> completeFeatureTour(String featureKey)

// Reset all progress
Future<void> resetOnboarding()

// Get completed tours
Future<List<String>> getCompletedFeatureTours()
```

---

## 📱 Usage Examples

### Example 1: Simple Onboarding

```dart
// In main.dart or app entry point
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(hasCompletedOnboardingProvider);
    
    return onboardingAsync.when(
      data: (completed) {
        if (!completed) {
          return OnboardingScreen(
            onComplete: () {
              ref.invalidate(hasCompletedOnboardingProvider);
              // Navigate to main app
            },
          );
        }
        return MainApp();
      },
      loading: () => const SplashScreen(),
      error: (_, __) => MainApp(),
    );
  }
}
```

### Example 2: Feature Tour with Manual Trigger

```dart
class HomePage extends ConsumerWidget {
  void _showTour(BuildContext context, WidgetRef ref) async {
    final service = ref.read(onboardingServiceProvider);
    // Reset tour to show again
    await service.completeFeatureTour('home');
    
    if (context.mounted) {
      // Will trigger tour on next build
      ref.invalidate(hasCompletedFeatureTourProvider('home'));
    }
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () => _showTour(context, ref),
          ),
        ],
      ),
      body: FeatureTourWrapper(
        featureKey: 'home',
        child: HomeContent(),
      ),
    );
  }
}
```

### Example 3: Conditional Tour

```dart
// Only show tour for new users
class VouchersView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSkipped = ref.watch(onboardingServiceProvider)
        .hasSkippedOnboarding();
    
    return FeatureTourWrapper(
      featureKey: 'vouchers',
      enabled: !hasSkipped, // Don't show if user skipped onboarding
      child: VouchersContent(),
    );
  }
}
```

---

## ✨ Features

### Current Features
✅ Full-screen onboarding slides
✅ Skip functionality
✅ Feature-specific tours
✅ Persistent state
✅ Manual tour reset
✅ Multiple spotlight styles
✅ Animated transitions
✅ Dark overlay with blur

### Available Feature Tours
- `home` - Home page tour (points, vouchers, brands, popular items)
- `vouchers` - Voucher system tour (tabs, claiming, activation)
- `menu` - Menu browsing tour (search, categories, cart)
- `cart` - Shopping cart tour (items, voucher application, checkout)
- `profile` - Profile tour (points summary, orders, addresses)

---

## 🎯 Best Practices

1. **Keep it Short** - Limit to 3-5 onboarding steps
2. **Make it Skippable** - Always allow users to skip
3. **Context Matters** - Show tours when feature is first accessed
4. **One at a Time** - Don't overwhelm with multiple tours
5. **Test Thoroughly** - Ensure tours don't interfere with functionality

---

## 🐛 Troubleshooting

### Tour not showing
- Check `hasCompletedFeatureTour()` returns false
- Verify `enabled: true` in FeatureTourWrapper
- Ensure feature key matches in service

### Tour shows every time
- Check if `completeFeatureTour()` is being called
- Verify SharedPreferences is working
- Use debug: `print(await service.getCompletedFeatureTours())`

### Overlay blocks interaction
- Ensure `onNext` callback is working
- Check if spotlight widget is properly configured
- Verify navigation after tour completion

---

## 📦 Dependencies

Required packages (already in pubspec.yaml):
- `shared_preferences` - For persistent storage
- `flutter_riverpod` - For state management
- `go_router` - For navigation

---

## 🚀 Next Steps

1. ✅ Add custom images for onboarding slides
2. ✅ Implement Lottie animations (optional)
3. ✅ Add analytics tracking for tour completion
4. ✅ Create admin panel to customize tours
5. ✅ Add A/B testing for onboarding variants

---

**That's it! Your app now has a complete onboarding system! 🎉**
