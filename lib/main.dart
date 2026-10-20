import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'src/core/routes/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/constants/app_constants.dart';
import 'src/core/services/storage_service.dart';
import 'src/core/widgets/admin_data_auto_refresh.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Tune Flutter Image Cache for instant display and higher in-memory retention
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 << 20; // 250 MB
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('⚠️  Firebase initialization skipped: $e');
    debugPrint('   Note: Firebase features will not work until configured');
    debugPrint('   Run: flutterfire configure');
  }

  // Initialize Hive for local storage
  await Hive.initFlutter();
  debugPrint('✅ Hive initialized successfully');

  // Open Hive boxes
  try {
    await Future.wait([
      Hive.openBox(AppConstants.boxCart),
      Hive.openBox(AppConstants.boxFavorites),
      Hive.openBox(AppConstants.boxAddress),
      Hive.openBox(AppConstants.boxOrderHistory),
    ]);
    debugPrint('✅ Hive boxes opened successfully');
  } catch (e) {
    debugPrint('⚠️  Error opening Hive boxes: $e');
  }

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs, const FlutterSecureStorage());
  await storageService.initialize();
  debugPrint('✅ SharedPreferences initialized successfully');

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

  // Set preferred orientations (portrait only for better UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Run the app
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const DelitopiaApp(),
    ));
}

class DelitopiaApp extends StatelessWidget {
  const DelitopiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // App Info
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,

      // Router Configuration
      routerConfig: AppRouter.router,

      // Localization (Add later if needed)
      // localizationsDelegates: const [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      //   GlobalCupertinoLocalizations.delegate,
      // ],
      // supportedLocales: const [
      //   Locale('en', 'US'),
      //   Locale('id', 'ID'),
      // ],

      // Builder for global overlays
      builder: (context, child) {
        return AdminDataAutoRefresh(
          child: MediaQuery(
            // Disable text scaling for consistent UI
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child ?? const SizedBox.shrink(),
          ));
      });
  }
}
