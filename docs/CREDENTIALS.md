# Delitopia Firebase & API Credentials

## 🔥 Firebase Project Information

**Project ID:** `delitopia-2ca9c`
**Project Number:** `284464943479`
**Storage Bucket:** `delitopia-2ca9c.appspot.com`
**Firebase Console:** https://console.firebase.google.com/project/delitopia-2ca9c

---

## 📱 Android Configuration

**Package Name:** `com.delitopia.softindo`
**App ID:** `1:284464943479:android:0de81359beba4e47f55172`
**API Key:** `AIzaSyC0topmPTfMRK3C8PKZTVQS57TAPeeMYDE`

**File Location:** `android/app/google-services.json` ✅ Already copied

### Google Sign-In OAuth Clients (Android)
Multiple certificate hashes configured for different signing keys:
- `284464943479-3lsvoug47dp589j4dhk1sauuk4pr5qot.apps.googleusercontent.com`
- `284464943479-6vugkd6m74i9hqidc0fmrhu6a1bpdeh0.apps.googleusercontent.com`
- `284464943479-embbrffq58v1bc9qfoknab65nqlplbjp.apps.googleusercontent.com`
- `284464943479-jkak0r5rd249ekmgqcgf94lf15eceb37.apps.googleusercontent.com`
- `284464943479-rh45f0ud1e31pv2d9kctooenve3pcico.apps.googleusercontent.com`

**Web OAuth Client:**
`284464943479-0al64mg2s50e6uisg3dapn1qfuf0639o.apps.googleusercontent.com`

---

## 🍎 iOS Configuration

**Bundle ID:** `com.delitopia.softindo`
**App ID:** `1:284464943479:ios:2b92721a6080043bf55172`
**API Key:** `AIzaSyA3ipht3aizvCKVM_EvUCfNG93ltcsBb98`

**File Location:** `ios/Runner/GoogleService-Info.plist` ✅ Already copied

### Google Sign-In OAuth Client (iOS)
**Client ID:** `284464943479-09p2p96n7h8qg6igvn65brvib0tgn2qk.apps.googleusercontent.com`
**Reversed Client ID:** `com.googleusercontent.apps.284464943479-09p2p96n7h8qg6igvn65brvib0tgn2qk`

**Android Client ID (for iOS):**
`284464943479-6vugkd6m74i9hqidc0fmrhu6a1bpdeh0.apps.googleusercontent.com`

---

## 🌐 Web Configuration

**App ID:** `1:284464943479:web:1802d9a74405087ef55172`
**API Key:** `AIzaSyD-bZ8AD4BYZTGhT--AQZjr2YGX2zXx9hY`
**Auth Domain:** `delitopia-2ca9c.firebaseapp.com`
**Measurement ID:** `G-HJ6WZC5XMS`

---

## 💻 macOS Configuration

Uses same iOS configuration:
**Bundle ID:** `com.delitopia.softindo`
**App ID:** `1:284464943479:ios:2b92721a6080043bf55172`
**API Key:** `AIzaSyA3ipht3aizvCKVM_EvUCfNG93ltcsBb98`

---

## 🔔 Firebase Cloud Messaging (FCM)

**Sender ID / GCM Sender ID:** `284464943479`

This is used for:
- Push notifications
- FCM token generation
- Background message handling

### FCM Integration Notes:
- Already configured in both `google-services.json` and `GoogleService-Info.plist`
- Server key available in Firebase Console → Project Settings → Cloud Messaging
- Legacy server key and V1 API both available

---

## 🌍 API Configuration

**Base URL:** `https://delitopia.softindopp.com/api/`

**File Location:** `app.env` ✅ Already created

### API Endpoints (from old project analysis):
- Authentication: `/auth/login`, `/auth/register`, `/auth/google-login`
- Menu: `/menu/categories`, `/menu/products`
- Orders: `/orders`, `/orders/:id`, `/orders/track/:id`
- Profile: `/profile`, `/profile/update`
- Locations: `/branches`, `/branches/:id`
- Vouchers: `/vouchers`, `/vouchers/validate`
- Notifications: `/fcm/update-token`
- And more...

---

## 📂 Files Already Copied to New Project

✅ `lib/firebase_options.dart` - Complete Firebase configuration for all platforms
✅ `android/app/google-services.json` - Android Firebase config
✅ `ios/Runner/GoogleService-Info.plist` - iOS Firebase config
✅ `app.env` - API base URL configuration

---

## 🔐 Security Notes

### ⚠️ IMPORTANT: Keep These Files Private!

1. **Never commit to public repositories:**
   - `google-services.json`
   - `GoogleService-Info.plist`
   - `app.env`
   - `firebase_options.dart` (if contains sensitive data)

2. **Add to .gitignore:**
   ```gitignore
   # Firebase
   **/google-services.json
   **/GoogleService-Info.plist
   firebase_options.dart
   app.env
   
   # Environment files
   *.env
   .env.*
   ```

3. **For team sharing:**
   - Use encrypted storage (1Password, LastPass, etc.)
   - Share via secure channels
   - Use environment variables in CI/CD

---

## 🚀 How to Use in New Project

### 1. Firebase Configuration (Already Done ✅)
All Firebase files are copied. No additional setup needed unless you want to reconfigure.

### 2. To Verify Setup:
```bash
cd /Users/softindopp/Downloads/delitopia_v2

# Check files exist
ls -la lib/firebase_options.dart
ls -la android/app/google-services.json
ls -la ios/Runner/GoogleService-Info.plist

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### 3. Initialize Firebase in main.dart:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp());
}
```

### 4. Use API URL from app.env:
```dart
// In your API constants file
const String baseUrl = String.fromEnvironment(
  'API_URI',
  defaultValue: 'https://delitopia.softindopp.com/api/',
);
```

---

## 🔧 If You Need to Reconfigure

### Option 1: Use Existing Credentials (Recommended)
Everything is already set up! Just use the files that were copied.

### Option 2: Reconfigure from Firebase Console
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Run configuration (will use existing Firebase project)
flutterfire configure --project=delitopia-2ca9c
```

This will:
- Connect to your existing Firebase project
- Regenerate configuration files
- Update package names if needed

---

## 📞 Firebase Console Access

To manage your Firebase project:
1. Go to https://console.firebase.google.com
2. Select project: **delitopia-2ca9c**
3. Available services:
   - Authentication (Email/Password, Google Sign-In enabled)
   - Cloud Firestore (Database)
   - Cloud Storage
   - Cloud Messaging (FCM)
   - Analytics (if enabled)

---

## 📊 Current Firebase Services Enabled

Based on configuration files:
✅ Firebase Authentication
✅ Cloud Firestore
✅ Cloud Messaging (FCM/Push Notifications)
✅ Cloud Storage
✅ Google Sign-In
✅ App Invite

---

## 🎯 Quick Reference

| Service | Android Key | iOS Key |
|---------|-------------|---------|
| API Key | AIzaSyC0topmPTfMRK3C8PKZTVQS57TAPeeMYDE | AIzaSyA3ipht3aizvCKVM_EvUCfNG93ltcsBb98 |
| App ID | 1:284464943479:android:0de81359beba4e47f55172 | 1:284464943479:ios:2b92721a6080043bf55172 |
| Package/Bundle | com.delitopia.softindo | com.delitopia.softindo |
| FCM Sender ID | 284464943479 | 284464943479 |

---

**Last Updated:** November 18, 2025
**Project:** Delitopia V2
