# Delitopia Documentation

Complete documentation for the Delitopia food ordering application.

## 📚 Documentation Index

### Getting Started
- [**GETTING_STARTED.md**](GETTING_STARTED.md) - Initial setup and installation guide

### API Documentation
- [**API_DOCUMENTATION_COMPLETE.md**](API_DOCUMENTATION_COMPLETE.md) - Complete API reference
- [**API_QUICK_REFERENCE.md**](API_QUICK_REFERENCE.md) - Quick API reference guide
- [**USER_APP_API_DOCUMENTATION.md**](USER_APP_API_DOCUMENTATION.md) - User app specific API docs

### Feature Documentation
- [**VOUCHER_SYSTEM_COMPLETE_DOCUMENTATION.md**](VOUCHER_SYSTEM_COMPLETE_DOCUMENTATION.md) - Complete voucher system guide
- [**VOUCHER_IMPLEMENTATION_GUIDE.md**](VOUCHER_IMPLEMENTATION_GUIDE.md) - Voucher implementation details
- [**CART_ORDER_PAYMENT_COMPLETE_DOCUMENTATION.md**](CART_ORDER_PAYMENT_COMPLETE_DOCUMENTATION.md) - Cart, order & payment system
- [**USER_APP_POS_INTEGRATION_GUIDE.md**](USER_APP_POS_INTEGRATION_GUIDE.md) - POS integration guide
- [**GRAB_DELIVERY_INTEGRATION.md**](GRAB_DELIVERY_INTEGRATION.md) - Grab delivery integration
- [**LOCATION_FEATURE.md**](LOCATION_FEATURE.md) - Location services documentation
- [**ONBOARDING_SYSTEM_GUIDE.md**](ONBOARDING_SYSTEM_GUIDE.md) - User onboarding system

### Technical Guides
- [**BACKEND_IMPLEMENTATION.md**](BACKEND_IMPLEMENTATION.md) - Backend integration guide
- [**ANIMATIONS_GUIDE.md**](ANIMATIONS_GUIDE.md) - Animation implementation guide
- [**DYNAMIC_UI_SCHEMA.md**](DYNAMIC_UI_SCHEMA.md) - Dynamic UI schema documentation
- [**TROUBLESHOOTING.md**](TROUBLESHOOTING.md) - Common issues and solutions

### Production & Deployment
- [**PRODUCTION_TODO_LIST.md**](PRODUCTION_TODO_LIST.md) - Pre-production checklist
- [**PRODUCTION_READINESS.md**](PRODUCTION_READINESS.md) - Production deployment guide
- [**CREDENTIALS.md**](CREDENTIALS.md) - API credentials and configuration

### Status & Implementation
- [**IMPLEMENTATION_STATUS.md**](IMPLEMENTATION_STATUS.md) - Current implementation status
- [**VOUCHER_IMPLEMENTATION_STATUS.md**](VOUCHER_IMPLEMENTATION_STATUS.md) - Voucher system status

## 🎨 Design Philosophy

This is a complete rebuild of the Delitopia app with:
- **Modern Material 3 Design**: Using Poppins font, vibrant colors, and smooth animations
- **Clean Architecture**: Organized feature-based structure with clear separation of concerns
- **Beautiful UI/UX**: Enhanced visual design with gradients, shadows, and smooth transitions
- **Responsive**: Works seamlessly on both Android and iOS

## ✨ Features

### Authentication
- Email/Password Login & Registration
- Google Sign-In integration
- Forgot Password flow with OTP verification
- Profile management
- Beautiful onboarding experience

### Home & Explore
- Dynamic banner carousel with smooth indicators
- Category browsing with icons
- Featured products grid
- Search functionality
- Branch/location selection with Google Maps

### Food Menu & Ordering
- Browse menu by category
- Detailed product views with image gallery
- Add to cart with quantity selection
- Cart management
- Multiple delivery options (pickup/delivery)
- Real-time order tracking with status updates

### Profile & Account
- View and edit profile
- Order history with detailed views
- Points/rewards system
- Address management
- Payment method management

### Additional Features
- Push notifications (FCM)
- QR code scanner for promotions
- Voucher/promo code redemption
- Multiple payment methods (Cash, QRIS, E-wallet, Credit Card)
- Real-time location tracking for delivery

## 📁 Project Structure

```
lib/
├── main.dart                           # App entry point
└── src/
    ├── core/
    │   ├── theme/
    │   │   └── app_theme.dart          # Complete theme system
    │   ├── constants/
    │   │   ├── app_constants.dart      # App-wide constants
    │   │   └── api_constants.dart      # API endpoints
    │   ├── utils/
    │   │   ├── validators.dart         # Form validators
    │   │   ├── formatters.dart         # String/number formatters
    │   │   └── helpers.dart            # Utility functions
    │   ├── routes/
    │   │   └── app_router.dart         # GoRouter configuration
    │   └── widgets/
    │       ├── buttons/                # Reusable button widgets
    │       ├── cards/                  # Card components
    │       ├── inputs/                 # Input field widgets
    │       └── loaders/                # Loading indicators
    ├── features/
    │   ├── auth/                       # Authentication feature
    │   │   ├── models/
    │   │   ├── views/
    │   │   │   ├── login_view.dart
    │   │   │   ├── register_view.dart
    │   │   │   └── forgot_password_view.dart
    │   │   ├── controllers/
    │   │   └── services/
    │   ├── home/                       # Home screen
    │   ├── menu/                       # Menu browsing
    │   ├── cart/                       # Shopping cart
    │   ├── order/                      # Order management
    │   ├── profile/                    # User profile
    │   ├── explore/                    # Explore/search
    │   ├── notifications/              # Notifications
    │   ├── voucher/                    # Vouchers/promos
    │   └── qr_scanner/                 # QR scanning
    └── shared/
        ├── models/                     # Shared data models
        ├── widgets/                    # Shared UI components
        └── services/                   # Shared services
```

## 🎯 Key Improvements Over Original

1. **Modern UI**: Material 3 design with Poppins font, vibrant gradients
2. **Better Performance**: Optimized with proper state management (Riverpod)
3. **Enhanced Animations**: Smooth transitions using flutter_animate
4. **Improved Architecture**: Clean, feature-based structure
5. **Better Error Handling**: Comprehensive error states and loading indicators
6. **Type Safety**: Using freezed for immutable models
7. **Better Testing**: Structure supports easy unit and widget testing
8. **Accessibility**: WCAG compliant with proper semantic labels

## 🚀 Getting Started

### Prerequisites
- Flutter SDK >= 3.5.0
- Dart >= 3.5.0
- Android Studio / Xcode
- Firebase project setup

### Installation

```bash
cd /Users/softindopp/Downloads/delitopia_v2

# Get dependencies
flutter pub get

# Run build_runner for code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Firebase Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Add Android and iOS apps to your project
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place them in the appropriate directories
5. Run `flutter pub run` to configure Firebase

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

## 🎨 Design System

### Colors
- **Primary**: #DD2222 (Red)
- **Secondary**: #FF6B35 (Orange)
- **Accent**: #FFC107 (Amber)

### Typography
- **Font Family**: Poppins
- **Headings**: Bold (600-700)
- **Body**: Regular (400)
- **Labels**: Medium (500)

### Spacing
- **xs**: 4px
- **sm**: 8px
- **md**: 16px
- **lg**: 24px
- **xl**: 32px

### Border Radius
- **sm**: 8px
- **md**: 12px
- **lg**: 16px
- **xl**: 24px

## 📦 Key Dependencies

- `flutter_riverpod`: State management
- `go_router`: Navigation
- `firebase_core`, `firebase_auth`, `cloud_firestore`: Firebase services
- `flutter_animate`: Animations
- `cached_network_image`: Image caching
- `dio`: HTTP client
- `hive`: Local storage
- `google_maps_flutter`: Maps integration

## 🔄 Development Workflow

### Adding a New Feature

1. Create feature folder in `lib/src/features/`
2. Add models, views, controllers, services
3. Register routes in `app_router.dart`
4. Add necessary providers
5. Test the feature

### Building for Production

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 📝 API Integration

The app expects a REST API with the following endpoints:

- `POST /auth/login` - User login
- `POST /auth/register` - User registration
- `GET /menu/categories` - Get categories
- `GET /menu/products` - Get products
- `POST /orders` - Create order
- `GET /orders/:id` - Get order details
- And more...

Refer to `lib/src/core/constants/api_constants.dart` for the complete list.

## 🤝 Contributing

This is a proprietary project. For contributions or questions, contact the development team.

## 📄 License

Copyright © 2025 Delitopia. All rights reserved.

## 🎓 Learning Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Material 3 Guidelines](https://m3.material.io/)
- [Riverpod Documentation](https://riverpod.dev/)

---

Built with ❤️ using Flutter
