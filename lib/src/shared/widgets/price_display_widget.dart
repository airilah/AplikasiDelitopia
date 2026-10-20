import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/menu_model.dart';
import '../models/product_model.dart';

/// A reusable widget to display price with promo strikethrough and discount badge.
class PriceDisplayWidget extends StatelessWidget {
  final String priceText;
  final String? originalPriceText;
  final bool hasPromo;
  final int? discountPercentage;
  final double fontSize;
  final Color? priceColor;
  final bool isVertical;
  final bool showBadge;

  const PriceDisplayWidget({
    super.key,
    required this.priceText,
    this.originalPriceText,
    this.hasPromo = false,
    this.discountPercentage,
    this.fontSize = 14,
    this.priceColor,
    this.isVertical = false,
    this.showBadge = false,
  });

  /// Factory constructor for Menu model
  factory PriceDisplayWidget.fromMenu({
    Key? key,
    required Menu menu,
    double fontSize = 14,
    Color? priceColor,
    bool isVertical = false,
    bool showBadge = false,
  }) {
    return PriceDisplayWidget(
      key: key,
      priceText: menu.hasPromo ? menu.formattedPromoPrice : menu.formattedPrice,
      originalPriceText: menu.hasPromo ? menu.formattedOriginalPrice : null,
      hasPromo: menu.hasPromo,
      discountPercentage: menu.discountPercentage,
      fontSize: fontSize,
      priceColor: priceColor,
      isVertical: isVertical,
      showBadge: showBadge,
    );
  }

  /// Factory constructor for Product model
  factory PriceDisplayWidget.fromProduct({
    Key? key,
    required Product product,
    double fontSize = 14,
    Color? priceColor,
    bool isVertical = false,
    bool showBadge = false,
  }) {
    final bool hasPromo = product.hasPromo || (product.originalPrice != null && product.originalPrice! > product.price);
    return PriceDisplayWidget(
      key: key,
      priceText: product.formattedPrice,
      originalPriceText: hasPromo ? product.formattedOriginalPrice : null,
      hasPromo: hasPromo,
      discountPercentage: product.discountPercentage,
      fontSize: fontSize,
      priceColor: priceColor,
      isVertical: isVertical,
      showBadge: showBadge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color effectivePriceColor = priceColor ?? AppColors.primary;

    if (!hasPromo || originalPriceText == null || originalPriceText!.isEmpty) {
      return Text(
        priceText,
        style: TextStyle(
          color: effectivePriceColor,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      );
    }

    final originalFontSize = (fontSize * 0.72).clamp(9.0, 12.0);

    final children = <Widget>[
      // Promo Price
      Text(
        priceText,
        style: TextStyle(
          color: effectivePriceColor,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
      const SizedBox(width: 5),
      // Original Price (Strikethrough di sebelah kanan dengan tulisan lebih kecil)
      Flexible(
        child: Text(
          originalPriceText!,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: originalFontSize,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.textTertiary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (showBadge && discountPercentage != null && discountPercentage! > 0) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEB),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '-$discountPercentage%',
            style: const TextStyle(
              color: Color(0xFFDD2222),
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ];

    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            priceText,
            style: TextStyle(
              color: effectivePriceColor,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                originalPriceText!,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: originalFontSize,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textTertiary,
                ),
              ),
              if (showBadge && discountPercentage != null && discountPercentage! > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '-$discountPercentage%',
                    style: const TextStyle(
                      color: Color(0xFFDD2222),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: children,
    );
  }
}
