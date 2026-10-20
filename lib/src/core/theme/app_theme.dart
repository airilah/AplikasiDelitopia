import 'package:flutter/material.dart';

/// App Colors - Modern and vibrant color palette
class AppColors {
  // Primary Brand Colors
  static const primary = Color(0xFFDD2222);
  static const primaryDark = Color(0xFFB01C1C);
  static const primaryLight = Color(0xFFFF5252);

  // Secondary Colors
  static const secondary = Color(0xFFFF6B35);
  static const secondaryDark = Color(0xFFE85A2C);
  static const secondaryLight = Color(0xFFFF8C5A);

  // Accent Colors
  static const accent = Color(0xFFFFC107);
  static const accentDark = Color(0xFFFFA000);
  static const accentLight = Color(0xFFFFD54F);

  // Neutral Colors
  static const background = Color(0xFFFAFAFA);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const borderLight = Color(0xFFEEEEEE);

  // Text Colors
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textTertiary = Color(0xFFBDBDBD);
  static const textOnPrimary = Colors.white;

  // System Colors
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFF44336);
  static const warning = Color(0xFFFF9800);
  static const info = Color(0xFF2196F3);

  // Overlay & Shadow
  static const overlay = Color(0x33000000);
  static final shadow = Colors.black.withValues(alpha: 0.1);
  static final cardShadow = Colors.black.withValues(alpha: 0.08);

  // Gradients
  static const primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, primaryDark]);

  static const secondaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [secondary, secondaryDark]);

  static const accentGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accent, accentDark]);

  static const shimmerGradient = LinearGradient(
      begin: Alignment(-1.0, -0.5),
      end: Alignment(1.0, 0.5),
      colors: [
        Color(0xFFEBEBF4),
        Color(0xFFF4F4F4),
        Color(0xFFEBEBF4),
      ],
      stops: [
        0.0,
        0.5,
        1.0
      ]);
}

/// App Typography - Using Plus Jakarta Sans font
class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  // Headline styles
  static const h1 = TextStyle(
      fontFamily: fontFamily,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.5);

  static const h2 = TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.3);

  static const h3 = TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3);

  static const h4 = TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4);

  static const h5 = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4);

  static const h6 = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.5);

  // Body styles
  static const bodyLarge = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5);

  static const bodyMedium = TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5);

  static const bodySmall = TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.5);

  // Label styles
  static const labelLarge = TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: 0.1);

  static const labelMedium = TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: 0.5);

  static const labelSmall = TextStyle(
      fontFamily: fontFamily,
      fontSize: 9,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: 0.5);

  // Button styles
  static const buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.25,
    letterSpacing: 0.3,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.25,
    letterSpacing: 0.3,
  );

  static const buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.25,
    letterSpacing: 0.2,
  );

  // Caption styles
  static const caption = TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.3);

  static const overline = TextStyle(
      fontFamily: fontFamily,
      fontSize: 9,
      fontWeight: FontWeight.w500,
      height: 1.6,
      letterSpacing: 1.5);
}

/// App Spacing - Consistent spacing system
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Padding
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  // Horizontal Padding
  static const EdgeInsets paddingHorizontalSM =
      EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMD =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLG =
      EdgeInsets.symmetric(horizontal: lg);

  // Vertical Padding
  static const EdgeInsets paddingVerticalSM =
      EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMD =
      EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLG =
      EdgeInsets.symmetric(vertical: lg);
}

/// App Radius - Consistent border radius
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0;

  // Border Radius
  static const BorderRadius borderRadiusXS =
      BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderRadiusSM =
      BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderRadiusMD =
      BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderRadiusLG =
      BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderRadiusXL =
      BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderRadiusXXL =
      BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius borderRadiusFull =
      BorderRadius.all(Radius.circular(full));
}

/// App Shadows - Consistent elevation and shadow system
class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  // Aliases for backward compatibility
  static List<BoxShadow> get small => sm;
  static List<BoxShadow> get medium => md;
  static List<BoxShadow> get large => lg;
  static List<BoxShadow> get card => md;
}

/// App Theme - Main theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
        useMaterial3: true,
        fontFamily: AppTypography.fontFamily,
        brightness: Brightness.light,

        // Color Scheme
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.textOnPrimary,
          primaryContainer: AppColors.primaryLight,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.secondary,
          onSecondary: AppColors.textOnPrimary,
          secondaryContainer: AppColors.secondaryLight,
          onSecondaryContainer: AppColors.secondaryDark,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.surfaceVariant,
          onSurfaceVariant: AppColors.textSecondary,
          error: AppColors.error,
          onError: AppColors.textOnPrimary,
          outline: AppColors.border,
          outlineVariant: AppColors.borderLight,
          shadow: AppColors.cardShadow,
        ),

        // Scaffold Background Color
        scaffoldBackgroundColor: AppColors.background,

        // App Bar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: AppTypography.h4,
          iconTheme: IconThemeData(color: AppColors.textOnPrimary),
        ),

        // Dialog Theme
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF202124),
          ),
          contentTextStyle: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),

        // Card Theme
        cardTheme: CardThemeData(
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusLG,
          ),
          color: AppColors.surface,
          shadowColor: AppColors.cardShadow,
        ),

        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMD,
            ),
            textStyle: AppTypography.button,
          ),
        ),

        // Filled Button Theme
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMD,
            ),
            textStyle: AppTypography.button,
          ),
        ),

        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppTypography.button,
          ),
        ),

        // Outlined Button Theme
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMD,
            ),
            textStyle: AppTypography.button,
          ),
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusMD,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusMD,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusMD,
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusMD,
            borderSide: const BorderSide(color: AppColors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusMD,
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          labelStyle:
              AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          hintStyle:
              AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
          errorStyle: AppTypography.caption.copyWith(color: AppColors.error),
        ),

        // Bottom Navigation Bar Theme
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Chip Theme
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariant,
          selectedColor: AppColors.primary,
          labelStyle: AppTypography.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMD,
          ),
        ),

        // Divider Theme
        dividerTheme: const DividerThemeData(
          color: AppColors.surfaceVariant,
          thickness: 1,
          space: 1,
        ),

        // Icon Theme
        iconTheme: const IconThemeData(
          color: AppColors.textSecondary,
          size: 24,
        ),

        // Text Theme
        textTheme: TextTheme(
          displayLarge: AppTypography.h1.copyWith(color: AppColors.textPrimary),
          displayMedium:
              AppTypography.h2.copyWith(color: AppColors.textPrimary),
          displaySmall: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          headlineMedium:
              AppTypography.h4.copyWith(color: AppColors.textPrimary),
          headlineSmall:
              AppTypography.h5.copyWith(color: AppColors.textPrimary),
          titleLarge: AppTypography.h6.copyWith(color: AppColors.textPrimary),
          bodyLarge:
              AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
          bodyMedium:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          bodySmall:
              AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          labelLarge:
              AppTypography.labelLarge.copyWith(color: AppColors.textPrimary),
          labelMedium: AppTypography.labelMedium
              .copyWith(color: AppColors.textSecondary),
          labelSmall:
              AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
        ),

        // SnackBar Theme
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          contentTextStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ));
  }
}
