import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/animations/animated_widgets.dart';

// ──────────────────────────────────────────────────────────────────────────────
// HomeBannerCarousel
// ──────────────────────────────────────────────────────────────────────────────
// The key optimization here: _BannerIndicator is a separate StatefulWidget.
// Previously, the page indicator state (setState for _currentPage) was in the
// parent DynamicHomePageState, causing the ENTIRE home page to rebuild on every
// banner slide (every 2 seconds). Now only the tiny indicator bar rebuilds.
// ──────────────────────────────────────────────────────────────────────────────

class HomeBannerCarousel extends StatefulWidget {
  final List<dynamic> banners;
  final double? height;
  final EdgeInsetsGeometry padding;
  final void Function(dynamic banner)? onTap;

  const HomeBannerCarousel({
    super.key,
    required this.banners,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.onTap,
  });

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.banners.isNotEmpty) {
        AppImageCache.precacheMultiple(
          context,
          widget.banners.map((b) {
            try {
              if (b?.image != null) return b.image as String;
            } catch (_) {}
            try {
              if (b?.photo != null) return b.photo as String;
            } catch (_) {}
            try {
              if (b?.imageUrl != null) return b.imageUrl as String;
            } catch (_) {}
            return null;
          }),
          limit: 10,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    if (widget.banners.length <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      final current = _pageController.page?.round() ?? 0;
      final next = (current + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double horizontalPadding = 40.0;
    if (widget.padding is EdgeInsets) {
      horizontalPadding = (widget.padding as EdgeInsets).horizontal;
    } else if (widget.padding is EdgeInsetsDirectional) {
      horizontalPadding = (widget.padding as EdgeInsetsDirectional).horizontal;
    }
    final cardWidth = (screenWidth - horizontalPadding).clamp(100.0, 1200.0);
    // Standard 750x360 banner aspect ratio: 750 / 360 = 2.0833
    final bannerHeight = widget.height ?? (cardWidth * 360 / 750);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // RepaintBoundary isolates PageView repaints from the rest of the page
        RepaintBoundary(
          child: SizedBox(
            height: bannerHeight,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.banners.length,
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return Padding(
                  padding: widget.padding,
                  child: _BannerCard(
                    banner: banner,
                    onTap: widget.onTap != null ? () => widget.onTap!(banner) : null,
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          // Isolated indicator — setState here ONLY rebuilds this tiny widget,
          // not the whole page. This is the core fix for the 2-second rebuild lag.
          _BannerIndicator(
            pageController: _pageController,
            count: widget.banners.length,
          ),
        ],
      ],
    );
  }
}

/// Banner card widget — stateless so it can be cached/reused efficiently
class _BannerCard extends StatelessWidget {
  final dynamic banner;
  final VoidCallback? onTap;

  const _BannerCard({
    required this.banner,
    this.onTap,
  });

  String _resolveImageUrl() {
    if (banner == null) return '';
    // Support multiple model schemas (e.g. guest banners with banner.image, schema banners with banner.photo)
    try {
      if (banner.image != null) return banner.image as String;
    } catch (_) {}
    try {
      if (banner.photo != null) return banner.photo as String;
    } catch (_) {}
    try {
      if (banner.imageUrl != null) return banner.imageUrl as String;
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      onTap: onTap ?? () {},
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 750 / 360,
            child: CachedImage(
              imageUrl: _resolveImageUrl(),
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}

/// Isolated indicator widget with its own State.
/// Only this widget calls setState when page changes — not the parent page.
class _BannerIndicator extends StatefulWidget {
  final PageController pageController;
  final int count;

  const _BannerIndicator({
    required this.pageController,
    required this.count,
  });

  @override
  State<_BannerIndicator> createState() => _BannerIndicatorState();
}

class _BannerIndicatorState extends State<_BannerIndicator> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_onPageChange);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageChange);
    super.dispose();
  }

  void _onPageChange() {
    if (!mounted) return;
    final page = widget.pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: _currentPage == index ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: _currentPage == index
                ? const Color(0xFFDD2222)
                : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
