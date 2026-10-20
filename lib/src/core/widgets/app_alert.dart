import 'dart:async';
import 'package:flutter/material.dart';

/// Enum tipe alert sistem Delitopia
enum AppAlertType {
  success,
  error,
  warning,
  info,
}

/// Widget dan utilitas template Floating Alert / Toast Delitopia
/// Mengadopsi prinsip desain Apple HIG & modern fintech aesthetics:
/// - Soft ambient diffuse shadow (melayang halus tanpa bayangan hitam kasar)
/// - Squircle icon badge dengan pastel tint dan border mikro
/// - Typography bersih (Medium w500, bukan bold kaku)
/// - Context-aware action pill (Undo netral, Lihat dengan panah navigasi, Coba Lagi dengan refresh)
class AppAlert {
  const AppAlert._();

  /// Menampilkan floating alert/toast ke ScaffoldMessenger
  static void show(
    BuildContext context,
    String message, {
    AppAlertType type = AppAlertType.success,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    VoidCallback? onActionPressed,
    String? actionLabel,
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    // Resolusi warna & ikon berdasarkan tipe
    final AlertStyle style = _getStyle(type);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 500;
    final horizontalMargin = isTablet ? (screenWidth - 420) / 2 : 16.0;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final effectiveBottomMargin = bottomOffset != null
        ? (includeBottomPadding ? (bottomOffset + bottomPadding) : bottomOffset)
        : (bottomPadding > 0 ? bottomPadding + 8.0 : 16.0);

    // Resolusi label dan handler aksi
    final String? resolvedActionLabel = actionLabel ?? action?.label;
    final VoidCallback? resolvedActionHandler = onActionPressed ?? action?.onPressed;

    Timer? autoDismissTimer;
    autoDismissTimer = Timer(duration, () {
      if (context.mounted) {
        try {
          messenger.hideCurrentSnackBar();
        } catch (_) {}
      }
    });

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: duration,
        margin: EdgeInsets.only(
          left: horizontalMargin,
          right: horizontalMargin,
          bottom: effectiveBottomMargin,
        ),
        padding: EdgeInsets.zero,
        dismissDirection: DismissDirection.horizontal,
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0x140F172A), // 8% slate border
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A), // 7% ambient shadow
                blurRadius: 24,
                offset: Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Color(0x080F172A), // 3% key shadow
                blurRadius: 6,
                offset: Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Icon Badge (Squircle dengan pastel tint)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: style.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: style.borderColor,
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    style.icon,
                    color: style.accentColor,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Teks Pesan Utama
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 3. Tombol Aksi Kontekstual (Jika ada)
              if (resolvedActionLabel != null && resolvedActionLabel.isNotEmpty) ...[
                const SizedBox(width: 10),
                _buildActionPill(
                  label: resolvedActionLabel,
                  onPressed: () {
                    autoDismissTimer?.cancel();
                    messenger.hideCurrentSnackBar();
                    resolvedActionHandler?.call();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shortcut: Sukses
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    SnackBarAction? action,
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    show(
      context,
      message,
      type: AppAlertType.success,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      action: action,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  /// Shortcut: Error
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    SnackBarAction? action,
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    show(
      context,
      message,
      type: AppAlertType.error,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      action: action,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  /// Shortcut: Warning
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    SnackBarAction? action,
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    show(
      context,
      message,
      type: AppAlertType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      action: action,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  /// Shortcut: Info
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    SnackBarAction? action,
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    show(
      context,
      message,
      type: AppAlertType.info,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      action: action,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  /// Pembangunan tombol aksi secara cerdas berdasarkan label aksi
  static Widget _buildActionPill({
    required String label,
    required VoidCallback onPressed,
  }) {
    final lower = label.trim().toLowerCase();

    // 1. Kasus UNDO ("Urungkan", "Undo", "Batal", "Cancel")
    final isUndo = lower.contains('urung') ||
        lower.contains('undo') ||
        lower == 'batal' ||
        lower == 'cancel';

    // 2. Kasus VIEW / DETAIL ("Lihat", "View", "Detail")
    final isView = lower.contains('lihat') ||
        lower.contains('view') ||
        lower.contains('detail');

    // 3. Kasus RETRY ("Coba Lagi", "Retry", "Ulangi")
    final isRetry = lower.contains('coba') ||
        lower.contains('retry') ||
        lower.contains('ulang');

    final Color bgColor;
    final Color textColor;
    final Color borderColor;
    final IconData? iconData;

    if (isUndo) {
      // Netral slate soft pill yang tenang dan harmonis
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF334155);
      borderColor = const Color(0xFFE2E8F0);
      iconData = Icons.undo_rounded;
    } else if (isView) {
      // Delitopia brand red soft pill dengan forward arrow
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFFEE2E2);
      iconData = Icons.arrow_forward_rounded;
    } else if (isRetry) {
      // Warm crimson dengan refresh icon
      bgColor = const Color(0xFFFFF1F2);
      textColor = const Color(0xFFBE123C);
      borderColor = const Color(0xFFFFE4E6);
      iconData = Icons.refresh_rounded;
    } else {
      // Default clean neutral pill
      bgColor = const Color(0xFFF8FAFC);
      textColor = const Color(0xFF334155);
      borderColor = const Color(0xFFE2E8F0);
      iconData = null;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              Icon(iconData, size: 13, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pemetaan visual style per varian
  static AlertStyle _getStyle(AppAlertType type) {
    switch (type) {
      case AppAlertType.success:
        return const AlertStyle(
          accentColor: Color(0xFF059669), // Emerald-600
          backgroundColor: Color(0xFFECFDF5), // Emerald-50
          borderColor: Color(0xFFD1FAE5), // Emerald-100
          icon: Icons.check_rounded,
        );
      case AppAlertType.error:
        return const AlertStyle(
          accentColor: Color(0xFFE11D48), // Rose-600
          backgroundColor: Color(0xFFFFF1F2), // Rose-50
          borderColor: Color(0xFFFFE4E6), // Rose-100
          icon: Icons.error_outline_rounded,
        );
      case AppAlertType.warning:
        return const AlertStyle(
          accentColor: Color(0xFFD97706), // Amber-600
          backgroundColor: Color(0xFFFFFBEB), // Amber-50
          borderColor: Color(0xFFFEF3C7), // Amber-100
          icon: Icons.warning_amber_rounded,
        );
      case AppAlertType.info:
        return const AlertStyle(
          accentColor: Color(0xFF2563EB), // Blue-600
          backgroundColor: Color(0xFFEFF6FF), // Blue-50
          borderColor: Color(0xFFDBEAFE), // Blue-100
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class AlertStyle {
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;

  const AlertStyle({
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
  });
}
