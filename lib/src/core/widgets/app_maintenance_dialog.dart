import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_language.dart';
import '../models/app_version_info.dart';
import '../services/app_update_service.dart';

/// Pop-up Maintenance / Persiapan Rilis Aplikasi (Pilihan 1: Katalog Terbuka, Checkout Terkunci)
/// Tampilan: Status Maintenance, Sampai Desember 2026, dan Tombol Mengerti Tunggal Jelas
/// Otomatis sinkron realtime jika ada perubahan konfigurasi di website admin
class AppMaintenanceDialog extends ConsumerWidget {
  final AppMaintenanceInfo maintenance;
  final VoidCallback? onDismiss;
  final VoidCallback? onContact;

  const AppMaintenanceDialog({
    super.key,
    required this.maintenance,
    this.onDismiss,
    this.onContact,
  });

  /// Helper untuk menampilkan dialog maintenance
  static Future<void> show(
    BuildContext context, {
    required AppMaintenanceInfo maintenance,
    VoidCallback? onDismiss,
    VoidCallback? onContact,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => AppMaintenanceDialog(
        maintenance: maintenance,
        onDismiss: onDismiss,
        onContact: onContact,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sinkronisasi realtime: jika admin mematikan maintenance (OFF), otomatis tutup dialog
    ref.listen<AppMaintenanceInfo?>(appMaintenanceProvider, (previous, next) {
      if (next != null && !next.isActive && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (onDismiss != null) onDismiss!();
      }
    });

    final lang = ref.watch(appLanguageProvider);
    final isId = lang == AppLanguage.indonesia;

    final currentMaintenance = ref.watch(appMaintenanceProvider) ?? maintenance;
    final launchDate = currentMaintenance.launchDate.isNotEmpty
        ? currentMaintenance.launchDate
        : (isId ? 'Desember 2026' : 'December 2026');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 12,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Judul di Tengah (Center - Realtime dari website admin)
            Text(
              currentMaintenance.title.isNotEmpty
                  ? currentMaintenance.title
                  : (isId ? 'Maintenance Aplikasi' : 'App Maintenance'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // Penjelasan di Tengah (Center - Realtime dari website admin)
            Text(
              currentMaintenance.message.isNotEmpty
                  ? currentMaintenance.message
                  : (isId
                      ? 'Layanan pemesanan sedang dalam pemeliharaan sistem. Pemesanan menu akan dibuka pada Desember 2026.'
                      : 'Ordering service is currently undergoing system maintenance. Menu ordering will open on December 2026.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151), // Teks normal & tegas, tidak redup
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),

            // Box Status Minimalis (Baris 1: Status - Maintenance (Merah), Baris 2: Sampai - Desember 2026 (Hijau))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Baris 1: Status (pojok kiri hitam) & Maintenance (pojok kanan merah)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A), // Hitam pojok kiri
                        ),
                      ),
                      Text(
                        'Maintenance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDD2222), // Merah pojok kanan
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Baris 2: Sampai (pojok kiri hitam) & Desember 2026 (pojok kanan hijau)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr.get('until', lang),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A), // Hitam pojok kiri
                        ),
                      ),
                      Text(
                        launchDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A), // Hijau pojok kanan
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Tunggal: Mengerti (Lebar Penuh, Tinggi Nyaman 50px, Teks Lebih Besar & Tidak Terpotong)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onDismiss != null) {
                    onDismiss!();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero, // Mencegah teks terpotong oleh default padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Center(
                  child: Text(
                    tr.get('understand', lang),
                    style: const TextStyle(
                      fontSize: 16.5,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      height: 1.2, // Spasi vertikal aman agar tidak terpotong
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
