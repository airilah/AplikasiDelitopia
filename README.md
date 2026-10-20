# Delitopia - Food Ordering App

A modern, feature-rich food ordering application built with Flutter.

## 🚀 Features

- **User Authentication** - Email/Password and Google Sign-In
- **Menu Browsing** - Browse restaurants and food items
- **Cart & Checkout** - Add items, customize orders, and checkout
- **Payment Integration** - QRIS payment gateway support
- **Order Tracking** - Real-time order status updates
- **Voucher System** - Redeem vouchers and claim rewards
- **POS Integration** - Member QR codes and voucher claim codes
- **Loyalty Points** - Earn and use points for rewards
- **Location Services** - Find nearby restaurants
- **Push Notifications** - Order updates and promotions
- **Order History** - View past orders and reorder

## 📱 Tech Stack

- **Framework**: Flutter 3.5+
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Backend**: REST API with Dio
- **Authentication**: Firebase Auth
- **Storage**: Hive (local), Firebase Storage
- **Maps**: Google Maps
- **Payments**: QRIS, Cash

## 🛠️ Getting Started

### Prerequisites

- Flutter SDK 3.5.0 or higher
- Dart SDK 3.5.0 or higher
- Android Studio / Xcode for mobile development
- Firebase account

### Installation

1. Clone the repository:
```bash
git clone https://github.com/MICHAEL-SOFTINDO/delitopia_app.git
cd delitopia_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Add `google-services.json` for Android
   - Add `GoogleService-Info.plist` for iOS

4. Run the app with the production backend:
```bash
flutter run --dart-define=ENV=production --dart-define=API_BASE_URL=https://aplikasi.mannagroup.id/api --dart-define=SOCKET_URL=wss://aplikasi.mannagroup.id
```

If you use VS Code, select the launch profile `Delitopia App - Production API`.

## 📖 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) folder:

- [Getting Started Guide](docs/GETTING_STARTED.md)
- [API Documentation](docs/API_DOCUMENTATION_COMPLETE.md)
- [Feature Guides](docs/README.md)
- [Production Checklist](docs/PRODUCTION_TODO_LIST.md)

## 🏗️ Project Structure

```
lib/
├── main.dart
└── src/
    ├── core/           # Core functionality (routes, theme, widgets)
    ├── features/       # Feature modules (auth, cart, order, etc.)
    └── shared/         # Shared models, services, and widgets
```

## 🔑 Environment Variables

Production API configuration is already set in `app.env`:

```
API_BASE_URL=https://aplikasi.mannagroup.id/api
SOCKET_URL=wss://aplikasi.mannagroup.id
ENV=production
```

The app also has the same production API URL as the default in `lib/src/core/constants/api_constants.dart`, so `flutter run` will use the deployed backend unless another `--dart-define=API_BASE_URL=...` is provided.

## 📦 Build

### Android
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ipa --release
```

## 🤝 Contributing

This is a proprietary project owned by Michael Agustinus for PT. Jakor Mas Sejahtera. 
Unauthorized copying, distribution, or use is strictly prohibited.

## 📄 License

**Proprietary License** - Copyright © 2025 Michael Agustinus for PT. Jakor Mas Sejahtera. All rights reserved.

This software is proprietary and confidential. Unauthorized copying, modification, 
distribution, or use of this software, via any medium, is strictly prohibited without 
explicit written permission from Michael Agustinus and PT. Jakor Mas Sejahtera.

See [LICENSE](LICENSE) file for full terms.

**Owner & Developer:** Michael Agustinus  
**Company:** PT. Jakor Mas Sejahtera

## ⚠️ Legal Notice

This project and all its contents are protected by copyright law. Any unauthorized use, 
reproduction, or distribution may result in severe civil and criminal penalties, and will 
be prosecuted to the maximum extent possible under the law.

## 📞 Support

For support, email: softindoputraperkasa@gmail.com

---

**Version:** 2.0.0+2  
**Package:** com.delitopia.softindo
