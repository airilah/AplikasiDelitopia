import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_language.dart';
import '../services/app_update_service.dart';

/// Pop-up Rating Play Store (Desain 2: Simple & Profesional - Tanpa Ikon Atas)
/// Ditampilkan saat pesanan selesai / diterima (Post-Delivery Success)
class AppRatingDialog extends ConsumerStatefulWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onRated;

  const AppRatingDialog({
    super.key,
    this.onDismiss,
    this.onRated,
  });

  /// Helper untuk menampilkan pop-up rating
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDismiss,
    VoidCallback? onRated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => AppRatingDialog(
        onDismiss: onDismiss,
        onRated: onRated,
      ),
    );
  }

  /// Cek apakah pop-up rating layak dimunculkan (anti-spam, max 1x per 30 hari jika ditolak, tidak muncul jika sudah dinilai)
  static Future<bool> shouldShowPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRated = prefs.getBool('playstore_has_rated') ?? false;
      if (hasRated) return false;

      final lastPromptMillis = prefs.getInt('playstore_last_prompt_millis') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyDaysMillis = 30 * 24 * 60 * 60 * 1000;

      return (now - lastPromptMillis) > thirtyDaysMillis;
    } catch (_) {
      return true;
    }
  }

  /// Catat bahwa pengguna menolak / menunda
  static Future<void> recordPromptDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('playstore_last_prompt_millis', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Catat bahwa pengguna sudah memberikan rating
  static Future<void> recordRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('playstore_has_rated', true);
    } catch (_) {}
  }

  @override
  ConsumerState<AppRatingDialog> createState() => _AppRatingDialogState();
}

class _AppRatingDialogState extends ConsumerState<AppRatingDialog> {
  int _selectedStars = 5;

  final List<String> _feedbacksId = [
    'Kurang Puas ⭐',
    'Cukup ⭐⭐',
    'Baik ⭐⭐⭐',
    'Puas ⭐⭐⭐⭐',
    'Sangat Puas ⭐⭐⭐⭐⭐',
  ];

  final List<String> _feedbacksEn = [
    'Dissatisfied ⭐',
    'Fair ⭐⭐',
    'Good ⭐⭐⭐',
    'Satisfied ⭐⭐⭐⭐',
    'Very Satisfied ⭐⭐⭐⭐⭐',
  ];

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final isId = lang == AppLanguage.indonesia;
    final feedbacks = isId ? _feedbacksId : _feedbacksEn;

    return Dialog(
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
            // Judul di Tengah (Center - Tanpa Ikon Bintang Atas)
            Text(
              tr.get('rate_app_title', lang),
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
              tr.get('rate_app_desc', lang),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),

            // Box Rating Minimalis (5 Bintang Interaktif)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNumber = index + 1;
                      final isSelected = starNumber <= _selectedStars;
                      return InkWell(
                        key: ValueKey('star_$starNumber'),
                        onTap: () {
                          setState(() {
                            _selectedStars = starNumber;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    feedbacks[_selectedStars - 1],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A), // Tulisan hitam terang & tegas
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Berdampingan (Tulisan Font Normal / Tidak Bold & Teks Utuh Tidak Terpotong)
            Row(
              children: [
                // Tombol Kiri: Nanti Saja
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () {
                      AppRatingDialog.recordPromptDismissed();
                      Navigator.of(context).pop();
                      if (widget.onDismiss != null) {
                        widget.onDismiss!();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      minimumSize: const Size.fromHeight(44),
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
                      tr.get('maybe_later_btn', lang),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500, // Tidak bold
                        height: 1.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Tombol Kanan: Beri Nilai (Buka Play Store)
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {
                      AppRatingDialog.recordRated();
                      Navigator.of(context).pop();
                      AppUpdateService.launchPlayStore();
                      if (widget.onRated != null) {
                        widget.onRated!();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr.get('rate_now_btn', lang),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500, // Tidak bold
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
