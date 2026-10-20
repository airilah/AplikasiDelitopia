import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/app_language.dart';

/// Wrapper widget that handles back button navigation
/// Prevents app exit and navigates back to previous screen or fallback route
class BackButtonWrapper extends StatelessWidget {
  final Widget child;
  final String? backRoute;
  final VoidCallback? onBack;

  static DateTime? _lastBackPressTime;

  const BackButtonWrapper({
    super.key,
    required this.child,
    this.backRoute,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          handleBack(context, backRoute: backRoute, onBack: onBack);
        }
      },
      child: child);
  }

  static void handleBack(
    BuildContext context, {
    String? backRoute,
    VoidCallback? onBack,
  }) {
    const homeRoute = '/navigation?index=0';

    if (onBack != null) {
      onBack();
    } else if (context.canPop()) {
      context.pop();
    } else if (backRoute != null && !_isCurrentRoute(context, backRoute)) {
      context.go(backRoute);
    } else if (!_isHomeScreen(context)) {
      // Jika tidak bisa pop dan BUKAN di layar Home (misal di Voucher, Profil, Keranjang),
      // kembalikan ke layar Home tanpa memunculkan pesan keluar aplikasi.
      context.go(homeRoute);
    } else {
      // Hanya jika ALAMAT SAAT INI ADALAH HOME (Index 0), tampilkan konfirmasi keluar aplikasi.
      final now = DateTime.now();
      if (_lastBackPressTime == null ||
          now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
        _lastBackPressTime = now;
        String exitMsg = 'Tekan sekali lagi untuk keluar dari Delitopia';
        try {
          final lang = ProviderScope.containerOf(context, listen: false).read(appLanguageProvider);
          exitMsg = tr.get('press_again_to_exit', lang);
        } catch (_) {}
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exitMsg,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF323232),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        // Keluar dari aplikasi pada double tap
        SystemNavigator.pop();
      }
    }
  }

  static bool _isHomeScreen(BuildContext context) {
    try {
      final uri = GoRouterState.of(context).uri;
      final path = uri.path;
      final index = uri.queryParameters['index'];

      if (path == '/' || path == '/home') return true;
      if (path == '/navigation') {
        return index == null || index == '0';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool _isCurrentRoute(BuildContext context, String targetRoute) {
    try {
      final current = GoRouterState.of(context).uri.toString();
      return current == targetRoute;
    } catch (_) {
      return false;
    }
  }
}

class AppBackButton extends StatelessWidget {
  final String? backRoute;
  final VoidCallback? onBack;
  final Color? color;
  final String? tooltip;

  const AppBackButton({
    super.key,
    this.backRoute,
    this.onBack,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      icon: Icon(Icons.arrow_back, color: color),
      onPressed: () => BackButtonWrapper.handleBack(
        context,
        backRoute: backRoute,
        onBack: onBack,
      ));
  }
}
