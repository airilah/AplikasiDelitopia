import 'package:flutter/material.dart';
import '../cached_image.dart';
import '../../../core/theme/app_theme.dart';

/// Product Card Widget
class ProductCard extends StatelessWidget {
  final String productId;
  final String imageUrl;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final double? rating;
  final int? reviewCount;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onAddToCartPressed;
  final String? heroTag;

  const ProductCard({
    super.key,
    required this.productId,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    this.rating,
    this.reviewCount,
    this.isFavorite = false,
    required this.onTap,
    this.onFavoritePressed,
    this.onAddToCartPressed,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDiscount = originalPrice != null && originalPrice! > price;

    return Card(
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusMD,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Stack(
              children: [
                CachedImage(
                  imageUrl: imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  heroTag: heroTag ?? 'product_photo_$productId',
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  errorWidget: Container(
                    height: 140,
                    color: AppColors.surface,
                    child: const Icon(Icons.fastfood, color: AppColors.textSecondary),
                  ),
                ),
                // Discount Badge
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: AppRadius.borderRadiusSM,
                      ),
                      child: Text(
                        '${((1 - price / originalPrice!) * 100).toStringAsFixed(0)}% OFF',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Favorite Button
                if (onFavoritePressed != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.small,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? AppColors.error : AppColors.textSecondary,
                        ),
                        onPressed: onFavoritePressed,
                        iconSize: 20,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
              ],
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    description,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Rating
                  if (rating != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (reviewCount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '($reviewCount)',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 8),

                  // Price Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rp ${price.toStringAsFixed(0)}',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (hasDiscount)
                            Text(
                              'Rp ${originalPrice!.toStringAsFixed(0)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      // Add to Cart Button
                      if (onAddToCartPressed != null)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppRadius.borderRadiusSM,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add_shopping_cart),
                            color: AppColors.textOnPrimary,
                            onPressed: onAddToCartPressed,
                            iconSize: 20,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
  }
}
