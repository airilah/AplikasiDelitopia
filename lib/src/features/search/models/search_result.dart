import '../../../core/localization/app_language.dart';
import '../../../core/utils/sold_count_formatter.dart';

class SearchMenuItem {
  final int menuId;
  final String name;
  final double price;
  final int soldCount;
  final int branchId;
  final String branchName;
  final bool isOpen;
  final double? distanceInKm;

  const SearchMenuItem({
    required this.menuId,
    required this.name,
    required this.price,
    required this.soldCount,
    required this.branchId,
    required this.branchName,
    required this.isOpen,
    this.distanceInKm,
  });

  String get formattedPrice {
    final priceInt = price.toInt();
    final str = priceInt.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $formatted';
  }

  String formattedSold(AppLanguage lang) =>
      formatSoldCount(soldCount, lang: lang);

  String get distanceText {
    if (distanceInKm == null) return '';
    return '${distanceInKm!.toStringAsFixed(1)} km';
  }
}

class SearchOutletItem {
  final int branchId;
  final int brandId;
  final String outletName;
  final String address;
  final String openingHours;
  final String closingHours;
  final bool isOpen;
  final double? distanceInKm;

  const SearchOutletItem({
    required this.branchId,
    required this.brandId,
    required this.outletName,
    required this.address,
    required this.openingHours,
    required this.closingHours,
    required this.isOpen,
    this.distanceInKm,
  });

  String get hoursText {
    if (openingHours.isEmpty || closingHours.isEmpty) return '10:00 - 22:00';
    return '$openingHours - $closingHours';
  }

  String get distanceText {
    if (distanceInKm == null) return '';
    return '${distanceInKm!.toStringAsFixed(1)} km';
  }
}

class GlobalSearchResult {
  final List<SearchOutletItem> outlets;
  final List<SearchMenuItem> menus;

  const GlobalSearchResult({
    required this.outlets,
    required this.menus,
  });

  bool get isEmpty => outlets.isEmpty && menus.isEmpty;
  bool get isNotEmpty => !isEmpty;
}
