import 'package:flutter/material.dart';

import '../widgets/app_alert.dart';

/// Error handling utilities
class ErrorHandler {
  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error, [BuildContext? context]) {
    final isIndo = context != null
        ? Localizations.maybeLocaleOf(context)?.languageCode != 'en'
        : true;

    if (error == null) {
      return isIndo
          ? 'Terjadi kesalahan. Silakan coba lagi.'
          : 'An error occurred. Please try again.';
    }

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return isIndo
          ? 'Tidak ada koneksi internet. Periksa koneksi Anda dan coba lagi.'
          : 'No internet connection. Check your connection and try again.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return isIndo
          ? 'Permintaan timeout. Silakan coba lagi.'
          : 'Request timeout. Please try again.';
    }

    // Auth errors
    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return isIndo
          ? 'Sesi Anda telah berakhir. Silakan login kembali.'
          : 'Your session has expired. Please log in again.';
    }

    if (errorString.contains('forbidden') || errorString.contains('403')) {
      return isIndo
          ? 'Anda tidak memiliki akses untuk melakukan ini.'
          : 'You do not have access to perform this action.';
    }

    // Not found errors
    if (errorString.contains('not found') || errorString.contains('404')) {
      return isIndo ? 'Data tidak ditemukan.' : 'Data not found.';
    }

    // Server errors
    if (errorString.contains('500') || errorString.contains('server error')) {
      return isIndo
          ? 'Server sedang mengalami masalah. Silakan coba lagi nanti.'
          : 'Server is having problems. Please try again later.';
    }

    // Validation errors
    if (errorString.contains('validation')) {
      return isIndo
          ? 'Data yang Anda masukkan tidak valid.'
          : 'The data you entered is invalid.';
    }

    // Default error
    return isIndo
        ? 'Terjadi kesalahan. Silakan coba lagi.'
        : 'An error occurred. Please try again.';
  }

  /// Show error snackbar
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = getUserFriendlyMessage(error, context);
    AppAlert.showError(
      context,
      message,
      duration: duration,
    );
  }

  /// Show success snackbar
  static void showSuccessSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    AppAlert.showSuccess(
      context,
      message,
      duration: duration,
    );
  }

  /// Show info snackbar
  static void showInfoSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    AppAlert.showInfo(
      context,
      message,
      duration: duration,
    );
  }
}

/// Error boundary widget
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget Function(Object error)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ));
  }
}

/// Error state widget
class ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isIndo = Localizations.maybeLocaleOf(context)?.languageCode != 'en';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              message ?? (isIndo ? 'Terjadi kesalahan' : 'Something went wrong'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(isIndo ? 'Coba Lagi' : 'Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ));
  }
}
