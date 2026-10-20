import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/app_alert.dart';

/// Helper utilities for common tasks
class Helpers {
  Helpers._();

  static String formatNumber(num number) {
    return number.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  // Show beautiful premium floating Alert
  static void showCustomAlert(
    BuildContext context,
    String message, {
    required bool isSuccess,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    AppAlert.show(
      context,
      message,
      type: isSuccess ? AppAlertType.success : AppAlertType.error,
      duration: duration,
      action: action,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  // Show Snackbar
  static void showSnackbar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    final isError = backgroundColor == const Color(0xFFC62828) ||
        backgroundColor == const Color(0xFFDC2626) ||
        backgroundColor == Colors.red ||
        backgroundColor == const Color(0xFFF44336);
    final isWarning = backgroundColor == const Color(0xFFFF9800) ||
        backgroundColor == Colors.orange;
    final isInfo = backgroundColor == const Color(0xFF2196F3) ||
        backgroundColor == Colors.blue;

    final AppAlertType type;
    if (isError) {
      type = AppAlertType.error;
    } else if (isWarning) {
      type = AppAlertType.warning;
    } else if (isInfo) {
      type = AppAlertType.info;
    } else {
      type = AppAlertType.success;
    }

    AppAlert.show(
      context,
      message,
      type: type,
      duration: duration,
      action: action,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  // Show Success Snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    AppAlert.showSuccess(
      context,
      message,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  // Show Error Snackbar
  static void showError(
    BuildContext context,
    String message, {
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    AppAlert.showError(
      context,
      message,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  // Show Warning Snackbar
  static void showWarning(
    BuildContext context,
    String message, {
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    AppAlert.showWarning(
      context,
      message,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  // Show Info Snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    double? bottomOffset,
    bool includeBottomPadding = true,
  }) {
    AppAlert.showInfo(
      context,
      message,
      bottomOffset: bottomOffset,
      includeBottomPadding: includeBottomPadding,
    );
  }

  // Show Loading Dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ],
              ),
            ),
          ),
        ),
      ));
  }

  // Hide Loading Dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Show Confirmation Dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Ya, Lanjutkan',
    String cancelText = 'Batal',
    Color? confirmColor,
    bool isDanger = false,
    bool showIcon = false,
    IconData? icon,
    Color? iconColor,
    Color? iconBgColor,
  }) async {
    final String resolvedConfirm = (confirmText == 'Kosongkan Keranjang' ||
            confirmText == 'Ya, Kosongkan')
        ? 'Kosongkan'
        : confirmText;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBgColor ??
                        (isDanger
                            ? const Color(0xFFFFF0F0)
                            : const Color(0xFFF0F4FF)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon ??
                        (isDanger
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded),
                    color: iconColor ??
                        (isDanger
                            ? const Color(0xFFDD2222)
                            : const Color(0xFF1976D2)),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF374151), // Teks normal & tegas, tidak redup
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDD2222),
                        side: const BorderSide(color: Color(0xFFDD2222)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelText,
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
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor ?? const Color(0xFFDD2222),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        resolvedConfirm,
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
            ],
          ),
        ),
      ));
    return result ?? false;
  }

  // Show Bottom Sheet
  static Future<T?> showBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => child);
  }

  // Launch URL
  static Future<bool> launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('Error launching URL: $e');
      return false;
    }
  }

  // Make Phone Call
  static Future<bool> makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  // Send SMS
  static Future<bool> sendSMS(String phoneNumber, {String? message}) async {
    final uri = Uri.parse('sms:$phoneNumber${message != null ? '?body=$message' : ''}');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  // Send Email
  static Future<bool> sendEmail(
    String email, {
    String? subject,
    String? body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      }.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'));

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  // Open WhatsApp
  static Future<bool> openWhatsApp(String phoneNumber, {String? message}) async {
    final uri = Uri.parse(
      'https://wa.me/$phoneNumber${message != null ? '?text=${Uri.encodeComponent(message)}' : ''}');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // Share Text
  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  // Share Files
  static Future<void> shareFiles(List<String> filePaths, {String? text}) async {
    await Share.shareXFiles(
      filePaths.map((path) => XFile(path)).toList(),
      text: text);
  }

  // Copy to Clipboard
  static Future<void> copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showSuccess(context, 'Copied to clipboard');
    }
  }

  // Get from Clipboard
  static Future<String?> getFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  // Hide Keyboard
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // Request Focus
  static void requestFocus(BuildContext context, FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }

  // Check if Device is Online
  static Future<bool> isOnline() async {
    try {
      // This is a simplified check. For production, use connectivity_plus
      // and internet_connection_checker_plus packages
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delay/Sleep
  static Future<void> delay(Duration duration) {
    return Future.delayed(duration);
  }

  // Debounce Function
  static void Function() debounce(
    void Function() function,
    Duration duration,
  ) {
    Future.delayed(duration, function);
    return function;
  }

  // Generate Random ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Check if String is Email
  static bool isEmail(String text) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(text);
  }

  // Check if String is Phone Number
  static bool isPhoneNumber(String text) {
    return RegExp(r'^(\+62|62|0)\d{8,12}$').hasMatch(text);
  }

  // Check if String is URL
  static bool isURL(String text) {
    return RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    ).hasMatch(text);
  }

  // Get Initials from Name
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  // Generate Color from String (for avatars)
  static Color generateColorFromString(String text) {
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.5, 0.6).toColor();
  }

  // Get Greeting based on Time
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  // Format Bytes to Human Readable
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // Calculate Distance between two coordinates
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c; // Distance in km
  }

  static double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  // Get Random Item from List
  static T getRandomItem<T>(List<T> list) {
    return list[(list.length * (DateTime.now().millisecond / 1000)).floor()];
  }

  // Chunk List into Smaller Lists
  static List<List<T>> chunkList<T>(List<T> list, int chunkSize) {
    final List<List<T>> chunks = [];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
}
