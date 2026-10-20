import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_language.dart';
import '../services/app_update_service.dart';

/// Modal dialog pembaruan aplikasi Delitopia (Desain 2: Simple & Profesional)
class AppUpdateDialog extends ConsumerWidget {
  final AppUpdateCheckResult updateResult;
  final VoidCallback? onDismiss;

  const AppUpdateDialog({
    super.key,
    required this.updateResult,
    this.onDismiss,
  });

  /// Static helper untuk menampilkan dialog pembaruan
  static Future<void> show(
    BuildContext context, {
    required AppUpdateCheckResult updateResult,
    VoidCallback? onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateResult.isForceUpdate,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => AppUpdateDialog(
        updateResult: updateResult,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isForce = updateResult.isForceUpdate;
    final lang = ref.watch(appLanguageProvider);
    final isId = lang == AppLanguage.indonesia;

    return PopScope(
      canPop: !isForce,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && onDismiss != null) {
          onDismiss!();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 12,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Judul di Tengah (Center)
              Text(
                updateResult.title.isNotEmpty
                    ? updateResult.title
                    : (isId ? 'Pembaruan Aplikasi' : 'App Update'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Penjelasan di Tengah (Center)
              Text(
                updateResult.message.isNotEmpty
                    ? updateResult.message
                    : (isId
                        ? 'Aplikasi Delitopia membutuhkan pembaruan ke versi terbaru di Google Play Store untuk dapat digunakan.'
                        : 'Delitopia app requires an update to the latest version on Google Play Store to continue.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151), // Teks normal & tegas, tidak redup
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),

              // Box Versi Minimalis (Versi Saat Ini -> Versi Play Store)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Kolom Versi Saat Ini
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          tr.get('current_version', lang),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v${updateResult.currentVersion}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),

                    // Panah Transisi
                    const Text(
                      '➔',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                      ),
                    ),

                    // Kolom Versi Terbaru (Hijau)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          tr.get('latest_version', lang),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v${updateResult.latestVersion}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Berdampingan (Tulisan Font Normal / Tidak Bold)
              Row(
                children: [
                  // Tombol Kiri: Nanti Saja / Keluar (Font Normal)
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          if (isForce) {
                            SystemNavigator.pop();
                          } else {
                            Navigator.of(context).pop();
                            if (onDismiss != null) {
                              onDismiss!();
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: Text(
                          isForce
                              ? tr.get('exit_btn', lang)
                              : tr.get('later', lang),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500, // Tidak bold
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Tombol Kanan: Perbarui (Font Normal)
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          AppUpdateService.launchPlayStore(
                            customUrl: updateResult.playStoreUrl,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDD2222),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          tr.get('update_btn', lang),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500, // Tidak bold
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
