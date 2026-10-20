import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/api_constants.dart';
import '../animations/shimmer_loading.dart';

String resolveImageUrl(String imageUrl) {
  final value = imageUrl.trim().replaceAll('\\', '/');
  if (value.isEmpty || value.startsWith('data:')) {
    return value;
  }

  final appOrigin = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  String publicStorageUrl(String path) {
    final cleanPath = path
        .replaceFirst(RegExp(r'^/+storage/+'), '')
        .replaceFirst(RegExp(r'^/+'), '');
    return Uri.encodeFull('$appOrigin/api/files/storage/$cleanPath');
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    try {
      final uri = Uri.parse(value);
      final apiUri = Uri.parse(appOrigin);

      if (uri.host == apiUri.host && uri.path.startsWith('/storage/')) {
        return publicStorageUrl(uri.path);
      }

      // Never rewrite host for POS photo servers
      if (uri.host == 'sales.mannagroup.id' || uri.host == 'sales.mannapertiwi.com') {
        return value;
      }

      final isLocalOrBackendHost = uri.host == '127.0.0.1' ||
          uri.host == 'localhost' ||
          uri.host == '10.0.2.2' ||
          uri.host == 'aplikasi.mannagroup.id' ||
          uri.path.startsWith('/images') ||
          uri.path.startsWith('/storage');

      if (isLocalOrBackendHost &&
          (uri.host != apiUri.host ||
              uri.scheme != apiUri.scheme ||
              (apiUri.hasPort && uri.port != apiUri.port))) {
        final newUri = uri.replace(
          scheme: apiUri.scheme,
          host: apiUri.host,
          port:
              apiUri.hasPort ? apiUri.port : (apiUri.scheme == 'https' ? 443 : 80));
        if (newUri.path.startsWith('/storage/')) {
          return publicStorageUrl(newUri.path);
        }
        return newUri.toString();
      }
    } catch (_) {
      return value;
    }
    return value;
  }

  final normalizedPath = value.startsWith('/') ? value : '/$value';
  if (normalizedPath.startsWith('/storage/')) {
    return publicStorageUrl(normalizedPath);
  }

  return Uri.encodeFull('$appOrigin$normalizedPath');
}

/// Optimized cached network image widget with shimmer loading placeholder
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final Color? placeholderColor;
  final String? heroTag;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.placeholderColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = resolveImageUrl(imageUrl);
    if (resolvedImageUrl.isEmpty) {
      final fallback = errorWidget ?? _buildDefaultError();
      Widget content = fallback;
      if (borderRadius != null) {
        content = ClipRRect(
          borderRadius: borderRadius!,
          child: fallback);
      }
      if (heroTag != null && heroTag!.isNotEmpty) {
        return Hero(tag: heroTag!, child: content);
      }
      return content;
    }

    final int? targetCacheWidth;
    final int? targetCacheHeight;

    if (width != null && width! > 0 && width!.isFinite) {
      targetCacheWidth = (width! * 2).toInt().clamp(64, 1200);
      targetCacheHeight = null;
    } else if (height != null && height! > 0 && height!.isFinite) {
      targetCacheWidth = null;
      targetCacheHeight = (height! * 2).toInt().clamp(64, 1200);
    } else {
      targetCacheWidth = 1080;
      targetCacheHeight = null;
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: resolvedImageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheHeight: targetCacheHeight,
      memCacheWidth: targetCacheWidth,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: placeholderColor ?? Colors.grey[300],
        child: ShimmerLoading(
          width: width ?? double.infinity,
          height: height ?? 100,
        ),
      ),
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultError(context));

    Widget result = imageWidget;
    if (borderRadius != null) {
      result = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget);
    }

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(tag: heroTag!, child: result);
    }

    return result;
  }

  Widget _buildDefaultError([BuildContext? context]) {
    final bool isWideBanner =
        (width == null || width == double.infinity || (width != null && width! >= 260)) &&
            (height != null && height!.isFinite && height! >= 120);

    if (isWideBanner) {
      final isIndo = context != null
          ? Localizations.maybeLocaleOf(context)?.languageCode != 'en'
          : true;
      return Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDD2222), Color(0xFFFF6B35)],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'PROMO DELITOPIA APP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isIndo
                        ? 'Dapatkan Diskon Khusus Pengguna Baru & Reward Points!'
                        : 'Get Special Discounts for New Users & Reward Points!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 48,
            ),
          ],
        ));
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 50,
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.fastfood_rounded,
            color: Color(0xFFDD2222),
            size: 36,
          ),
        ),
      ));
  }
}

/// Circular cached image with shimmer loading
class CachedCircularImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final Color? backgroundColor;
  final Widget? errorWidget;

  const CachedCircularImage({
    super.key,
    required this.imageUrl,
    this.size = 50,
    this.backgroundColor,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = resolveImageUrl(imageUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.grey[200],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: resolvedImageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: ShimmerLoading(
              width: size,
              height: size,
            ),
          ),
          errorWidget: (context, url, error) => errorWidget ?? Icon(
            Icons.person,
            size: size * 0.6,
            color: Colors.grey[400],
          ),
        ),
      ));
  }
}

/// Product card image with hero animation support
class CachedProductImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final double height;
  final BorderRadius? borderRadius;

  const CachedProductImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.height = 120,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = resolveImageUrl(imageUrl);

    return Hero(
      tag: heroTag,
      child: CachedImage(
        imageUrl: resolvedImageUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
        errorWidget: Container(
          height: height,
          color: Colors.grey[200],
          child: Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 60,
              height: 60,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.fastfood,
                size: 48,
                color: Color(0xFFDD2222),
              ),
            ),
          ),
        ),
      ));
  }
}

/// Brand logo with hero animation support
class CachedBrandLogo extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final bool isCircular;
  final double borderRadius;

  const CachedBrandLogo({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.size = 50,
    this.backgroundColor = Colors.white,
    this.iconColor = const Color(0xFFDD2222),
    this.isCircular = true,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = resolveImageUrl(imageUrl);

    return Hero(
      tag: heroTag,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircular ? null : BorderRadius.circular(borderRadius),
        ),
        child: isCircular
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: resolvedImageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 100),
                  placeholder: (context, url) => ShimmerLoading(
                    width: size,
                    height: size,
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.restaurant_rounded,
                      color: iconColor,
                      size: size * 0.5,
                    ),
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CachedNetworkImage(
                  imageUrl: resolvedImageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 100),
                  placeholder: (context, url) => ShimmerLoading(
                    width: size,
                    height: size,
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.restaurant_rounded,
                      color: iconColor,
                      size: size * 0.5,
                    ),
                  ),
                ),
              ),
      ));
  }
}

/// Banner image with smooth loading
class CachedBannerImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const CachedBannerImage({
    super.key,
    required this.imageUrl,
    this.height = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedImage(
      imageUrl: imageUrl,
      height: height,
      width: double.infinity,
      fit: fit,
      borderRadius: borderRadius);

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: image);
    }

    return image;
  }
}

/// Utility helper for pre-caching images into memory in the background
class AppImageCache {
  /// Pre-cache a single image into the memory cache
  static Future<void> precache(
    BuildContext context,
    String? rawUrl, {
    int? maxWidth = 1080,
    int? maxHeight,
  }) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    final resolved = resolveImageUrl(rawUrl);
    if (resolved.isEmpty || !resolved.startsWith('http')) return;
    try {
      final provider = CachedNetworkImageProvider(
        resolved,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      if (context.mounted) {
        await precacheImage(provider, context);
      }
    } catch (_) {
      // Pre-caching is an optimization; failures are silently caught
    }
  }

  /// Pre-cache multiple image URLs asynchronously in the background
  static void precacheMultiple(
    BuildContext context,
    Iterable<String?> rawUrls, {
    int limit = 12,
  }) {
    if (!context.mounted) return;
    final validUrls = rawUrls
        .where((u) => u != null && u.trim().isNotEmpty)
        .cast<String>()
        .take(limit)
        .toList();

    for (final url in validUrls) {
      precache(context, url);
    }
  }
}

