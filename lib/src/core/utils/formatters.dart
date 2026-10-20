import 'package:intl/intl.dart';

/// Formatters for common data types
class Formatters {
  Formatters._();

  // Currency Formatter (Indonesian Rupiah)
  static String currency(num amount, {bool includeSymbol = true}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: includeSymbol ? 'Rp ' : '',
      decimalDigits: 0);
    return formatter.format(amount);
  }

  // Compact Currency Formatter (e.g., 1.5K, 2.3M)
  static String compactCurrency(num amount, {bool includeSymbol = true}) {
    final symbol = includeSymbol ? 'Rp ' : '';
    
    if (amount >= 1000000000) {
      return '$symbol${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '$symbol${amount.toStringAsFixed(0)}';
    }
  }

  // Number Formatter with thousand separators
  static String number(num number, {int decimalDigits = 0}) {
    final formatter = NumberFormat.decimalPattern('id_ID');
    if (decimalDigits > 0) {
      return number.toStringAsFixed(decimalDigits);
    }
    return formatter.format(number);
  }

  // Percentage Formatter
  static String percentage(num value, {int decimalDigits = 0}) {
    return '${value.toStringAsFixed(decimalDigits)}%';
  }

  // Date Formatter - Full (e.g., "Monday, 15 January 2024")
  static String dateFull(DateTime date) {
    final formatter = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    return formatter.format(date);
  }

  // Date Formatter - Short (e.g., "15/01/2024")
  static String dateShort(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy', 'id_ID');
    return formatter.format(date);
  }

  // Date Formatter - Medium (e.g., "15 Jan 2024")
  static String dateMedium(DateTime date) {
    final formatter = DateFormat('dd MMM yyyy', 'id_ID');
    return formatter.format(date);
  }

  // Time Formatter - 12 Hour (e.g., "02:30 PM")
  static String time12Hour(DateTime time) {
    final formatter = DateFormat('hh:mm a', 'id_ID');
    return formatter.format(time);
  }

  // Time Formatter - 24 Hour (e.g., "14:30")
  static String time24Hour(DateTime time) {
    final formatter = DateFormat('HH:mm', 'id_ID');
    return formatter.format(time);
  }

  // Time Formatter with Timezone (e.g., "14:30 WIB")
  static String timeWithZone(DateTime time, {String zone = 'WIB'}) {
    final formatter = DateFormat('HH:mm', 'id_ID');
    return '${formatter.format(time)} $zone';
  }

  // DateTime Formatter (e.g., "15/01/2024 14:30")
  static String dateTime(DateTime dateTime) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
    return formatter.format(dateTime);
  }

  // DateTime Formatter with Timezone (e.g., "15/01/2024 14:30 WIB")
  static String dateTimeWithZone(DateTime dateTime, {String zone = 'WIB'}) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
    return '${formatter.format(dateTime)} $zone';
  }

  // Relative Time Formatter (e.g., "2 hours ago", "3 days ago")
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  // Time Remaining Formatter (e.g., "2h 30m", "1d 5h")
  static String timeRemaining(Duration duration) {
    if (duration.isNegative) {
      return 'Expired';
    }

    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Phone Number Formatter (Indonesian format)
  static String phoneNumber(String phone) {
    // Remove all non-digit characters
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Handle different formats
    if (cleaned.startsWith('62')) {
      // +62 812-3456-7890
      if (cleaned.length >= 11) {
        return '+62 ${cleaned.substring(2, 5)}-${cleaned.substring(5, 9)}-${cleaned.substring(9)}';
      }
    } else if (cleaned.startsWith('0')) {
      // 0812-3456-7890
      if (cleaned.length >= 10) {
        return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 8)}-${cleaned.substring(8)}';
      }
    }

    return phone; // Return original if format doesn't match
  }

  // Credit Card Number Formatter
  static String creditCard(String cardNumber) {
    // Remove all non-digit characters
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');

    // Format as XXXX XXXX XXXX XXXX
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }

    return buffer.toString();
  }

  // Mask Credit Card Number (e.g., "**** **** **** 1234")
  static String maskCreditCard(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 4) return cardNumber;

    final lastFour = cleaned.substring(cleaned.length - 4);
    return '**** **** **** $lastFour';
  }

  // Mask Email (e.g., "j***@example.com")
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) {
      return '***@$domain';
    }

    final masked = username[0] + '*' * (username.length - 2) + username[username.length - 1];
    return '$masked@$domain';
  }

  // Mask Phone Number (e.g., "0812****7890")
  static String maskPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 8) return phone;

    final start = cleaned.substring(0, 4);
    final end = cleaned.substring(cleaned.length - 4);
    return '$start****$end';
  }

  // File Size Formatter
  static String fileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  // Distance Formatter
  static String distance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  // Duration Formatter (e.g., "1h 30m", "45m")
  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Rating Formatter (e.g., "4.5")
  static String rating(double rating) {
    return rating.toStringAsFixed(1);
  }

  // Capitalize First Letter
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Title Case (Capitalize Each Word)
  static String titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Truncate Text with Ellipsis
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - ellipsis.length) + ellipsis;
  }

  // Order ID Formatter (e.g., "ORD-2024-0001")
  static String orderId(int id) {
    final year = DateTime.now().year;
    return 'ORD-$year-${id.toString().padLeft(4, '0')}';
  }
}
