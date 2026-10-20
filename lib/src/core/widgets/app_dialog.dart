import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_language.dart';

/// Jenis tipe dialog untuk tema warna dan ikon standar
enum AppDialogType {
  danger, // Tindakan destruktif / hapus / keluar
  warning, // Peringatan / konfirmasi perubahan
  success, // Aksi sukses / berhasil
  info, // Informasi / login guard
}

/// Template Dialog Utama Delitopia
/// Desain modern, konsisten, dan rapi sesuai UI standard aplikasi.
class AppDialog extends ConsumerWidget {
  final AppDialogType type;
  final IconData? icon;
  final String title;
  final String? message;
  final Widget? customContent;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final bool showIcon;
  final bool isDismissible;
  final bool isNeutralCancel;

  const AppDialog({
    super.key,
    this.type = AppDialogType.danger,
    this.icon,
    this.showIcon = false,
    required this.title,
    this.message,
    this.customContent,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.isDismissible = true,
    this.isNeutralCancel = false,
  });

  /// Helper untuk menampilkan Dialog Konfirmasi (2 Tombol: Batal & Konfirmasi)
  static Future<bool> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    AppDialogType type = AppDialogType.danger,
    IconData? icon,
    bool showIcon = false,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
    bool isDismissible = true,
    bool isNeutralCancel = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => AppDialog(
        type: type,
        icon: icon,
        showIcon: showIcon,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        isDismissible: isDismissible,
        isNeutralCancel: isNeutralCancel,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  /// Helper untuk menampilkan Alert Informasi (1 Tombol: Mengerti / Tutup)
  static Future<void> showAlert({
    required BuildContext context,
    required String title,
    required String message,
    AppDialogType type = AppDialogType.info,
    IconData? icon,
    bool showIcon = false,
    String? buttonText,
    Color? buttonColor,
    bool isDismissible = true,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => AppDialog(
        type: type,
        icon: icon,
        showIcon: showIcon,
        title: title,
        message: message,
        confirmText: buttonText,
        confirmColor: buttonColor,
        isDismissible: isDismissible,
        onConfirm: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  /// Helper untuk menampilkan Dialog dengan Konten Kustom (misal: Radio pilihan, form alasan pembatalan)
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required String title,
    String? message,
    required Widget content,
    AppDialogType type = AppDialogType.info,
    IconData? icon,
    bool showIcon = false,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => AppDialog(
        type: type,
        icon: icon,
        showIcon: showIcon,
        title: title,
        message: message,
        customContent: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDismissible: isDismissible,
        onConfirm: onConfirm,
        onCancel: onCancel ?? () => Navigator.of(ctx).pop(),
      ),
    );
  }

  // --- Theme Resolver ---
  Color _resolveBadgeColor() {
    switch (type) {
      case AppDialogType.danger:
        return const Color(0xFFFFF0F0);
      case AppDialogType.warning:
        return const Color(0xFFFFFBEB);
      case AppDialogType.success:
        return const Color(0xFFECFDF5);
      case AppDialogType.info:
        return const Color(0xFFEFF6FF);
    }
  }

  Color _resolveIconColor() {
    switch (type) {
      case AppDialogType.danger:
        return const Color(0xFFDD2222);
      case AppDialogType.warning:
        return const Color(0xFFF59E0B);
      case AppDialogType.success:
        return const Color(0xFF10B981);
      case AppDialogType.info:
        return const Color(0xFF2563EB);
    }
  }

  IconData _resolveDefaultIcon() {
    switch (type) {
      case AppDialogType.danger:
        return Icons.delete_outline_rounded;
      case AppDialogType.warning:
        return Icons.warning_amber_rounded;
      case AppDialogType.success:
        return Icons.check_circle_outline_rounded;
      case AppDialogType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isId = lang == AppLanguage.indonesia;

    String? effectiveConfirm = confirmText;
    if (effectiveConfirm == 'Kosongkan Keranjang' ||
        effectiveConfirm == 'Ya, Kosongkan' ||
        effectiveConfirm == 'Clear Cart' ||
        effectiveConfirm == 'Yes, Clear') {
      effectiveConfirm = isId ? 'Kosongkan' : 'Clear';
    } else if (effectiveConfirm == null && cancelText != null) {
      effectiveConfirm = isId ? 'Lanjutkan' : 'Continue';
    } else if (effectiveConfirm == null && cancelText == null) {
      effectiveConfirm = isId ? 'Mengerti' : 'Got It';
    } else if (!isId) {
      if (effectiveConfirm == 'Lanjutkan') effectiveConfirm = 'Continue';
      if (effectiveConfirm == 'Mengerti') effectiveConfirm = 'Got It';
    }

    String? effectiveCancel = cancelText;
    if (!isId && effectiveCancel == 'Batal') {
      effectiveCancel = 'Cancel';
    }

    final badgeColor = _resolveBadgeColor();
    final iconColor = _resolveIconColor();
    final displayIcon = icon ?? _resolveDefaultIcon();
    final effectiveConfirmColor = confirmColor ??
        (type == AppDialogType.danger ? const Color(0xFFDD2222) : _resolveIconColor());

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Badge Lingkaran (Hanya jika showIcon == true)
            if (showIcon) ...[
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    displayIcon,
                    color: iconColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Judul Dialog
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF202124),
              ),
            ),

            // Deskripsi / Pesan
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF374151), // Teks normal & tegas, tidak redup
                ),
              ),
            ],

            // Konten Kustom (opsional)
            if (customContent != null) ...[
              const SizedBox(height: 16),
              customContent!,
            ],

            const SizedBox(height: 24),

            // Bagian Tombol Aksi
            if (effectiveCancel != null && effectiveConfirm != null) ...[
              // 2 Tombol Berdampingan (Batal & Konfirmasi)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel ?? () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isNeutralCancel
                            ? Colors.grey.shade700
                            : const Color(0xFFDD2222),
                        side: BorderSide(
                          color: isNeutralCancel
                              ? Colors.grey.shade300
                              : const Color(0xFFDD2222),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        effectiveCancel,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectiveConfirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        effectiveConfirm,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (effectiveConfirm != null) ...[
              // 1 Tombol Tunggal (Misal: Alert / Informasi)
              ElevatedButton(
                onPressed: onConfirm ?? () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectiveConfirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  effectiveConfirm,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
