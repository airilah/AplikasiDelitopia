import '../localization/app_language.dart';

/// Formats the sold count into user-friendly social proof text.
///
/// Rules:
/// - 0 - 999:
///   ID: "0 terjual", "73 terjual", "355 terjual", "926 terjual"
///   EN: "0 sold", "73 sold", "355 sold", "926 sold"
/// - 1000+:
///   ID: "1rb+ terjual", "1.3rb+ terjual", "5.4rb+ terjual", "11.3rb+ terjual", "229.2rb+ terjual"
///   EN: "1k+ sold", "1.3k+ sold", "5.4k+ sold", "11.3k+ sold", "229.2k+ sold"
String formatSoldCount(int count, {AppLanguage lang = AppLanguage.indonesia}) {
  final isId = lang == AppLanguage.indonesia;
  final suffix = isId ? 'Terjual' : 'Sold';

  if (count < 1000) {
    final displayCount = count < 0 ? 0 : count;
    return '$displayCount $suffix';
  }

  final double k = count / 1000.0;
  String formattedK;
  if (k >= 100) {
    // For numbers >= 100k, show integer (e.g. 149rb+ or 229rb+) or with 1 decimal if non-zero
    final rounded = (k * 10).round() / 10;
    formattedK = (rounded % 1 == 0) ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
  } else {
    // For numbers < 100k, show 1 decimal if not an exact thousand (e.g. 1.3rb+, 5.4rb+, 11.3rb+)
    final rounded = (k * 10).round() / 10;
    formattedK = (rounded % 1 == 0) ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
  }

  final unit = isId ? 'rb+' : 'k+';
  return '$formattedK$unit $suffix';
}
