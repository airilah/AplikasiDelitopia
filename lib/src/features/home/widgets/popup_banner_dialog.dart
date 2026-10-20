import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../shared/models/product_model.dart' as models;

class PopupBannerDialog extends ConsumerStatefulWidget {
  final List<models.Banner> banners;
  final int initialPage;

  const PopupBannerDialog({
    super.key,
    required this.banners,
    this.initialPage = 0,
  });

  @override
  ConsumerState<PopupBannerDialog> createState() => _PopupBannerDialogState();
}

class _PopupBannerDialogState extends ConsumerState<PopupBannerDialog> {
  late PageController _pageController;
  late int _currentPage;
  final Set<int> _showDetailsIndices = {};
  final Map<int, double> _aspectRatios = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _resolveAspectRatios();
  }

  @override
  void didUpdateWidget(covariant PopupBannerDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners != widget.banners) {
      _resolveAspectRatios();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _resolveAspectRatios() {
    for (int i = 0; i < widget.banners.length; i++) {
      final banner = widget.banners[i];
      final imageUrl = (banner.popup != null && banner.popup!.trim().isNotEmpty)
          ? banner.popup!.trim()
          : banner.photo.trim();
      _fetchAspectRatio(i, imageUrl);
    }
  }

  void _fetchAspectRatio(int index, String rawUrl) {
    if (rawUrl.isEmpty) return;
    final resolvedUrl = resolveImageUrl(rawUrl);
    if (resolvedUrl.isEmpty) return;

    try {
      final ImageProvider provider;
      if (resolvedUrl.startsWith('http://') ||
          resolvedUrl.startsWith('https://')) {
        provider = CachedNetworkImageProvider(resolvedUrl);
      } else if (resolvedUrl.startsWith('assets/')) {
        provider = AssetImage(resolvedUrl);
      } else {
        provider = CachedNetworkImageProvider(resolvedUrl);
      }

      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          final width = info.image.width;
          final height = info.image.height;
          if (width > 0 && height > 0) {
            final ratio = width / height;
            if (_aspectRatios[index] != ratio) {
              if (mounted) {
                setState(() {
                  _aspectRatios[index] = ratio;
                });
              } else {
                _aspectRatios[index] = ratio;
              }
            }
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              stream.removeListener(listener);
            } catch (_) {}
          });
        },
        onError: (dynamic error, StackTrace? stackTrace) {
          try {
            stream.removeListener(listener);
          } catch (_) {}
        },
      );
      stream.addListener(listener);
    } catch (_) {}
  }

  void _toggleSlideDetails(int index) {
    setState(() {
      if (_showDetailsIndices.contains(index)) {
        _showDetailsIndices.remove(index);
      } else {
        _showDetailsIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Batasan tinggi maksimum poster agar pas di layar tanpa terpotong status bar & navigasi
    final maxContentHeight = (screenHeight * 0.72).clamp(360.0, 600.0);
    final maxContentWidth = (screenWidth - 48).clamp(240.0, 420.0);

    // Semua popup promo poster Delitopia berformat vertikal 9:16 (1080 x 1920 = 0.5625)
    final double activeRatio = _aspectRatios[_currentPage] ?? (9.0 / 16.0);

    // Hitung ukuran container agar 100% presisi sesuai rasio gambar poster (tanpa ada sisa ruang)
    double targetHeight = maxContentHeight;
    double targetWidth = targetHeight * activeRatio;

    if (targetWidth > maxContentWidth) {
      targetWidth = maxContentWidth;
      targetHeight = targetWidth / activeRatio;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: SizedBox(
          width: targetWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Popup Images Slider
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: targetWidth,
                    height: targetHeight,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: widget.banners.length,
                        itemBuilder: (context, index) {
                          final banner = widget.banners[index];
                          return _buildSlideItem(banner, index);
                        },
                      ),
                    ),
                  ),
                  // Page Indicator
                  if (widget.banners.length > 1) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.banners.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Close Button (Top-Right menempel persis di pojok poster)
              Positioned(
                top: -12,
                right: -10,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFDD2222),
                      size: 22,
                    ),
                  ),
                ),
              ),

              // Navigation Arrows (menempel persis di sisi kiri & kanan poster)
              if (widget.banners.length > 1) ...[
                if (_currentPage > 0)
                  Positioned(
                    left: -14,
                    top: 0,
                    bottom: widget.banners.length > 1 ? 26 : 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFFDD2222),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_currentPage < widget.banners.length - 1)
                  Positioned(
                    right: -14,
                    top: 0,
                    bottom: widget.banners.length > 1 ? 26 : 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFDD2222),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlideItem(models.Banner banner, int index) {
    final lang = ref.watch(appLanguageProvider);
    final isShowingDetails = _showDetailsIndices.contains(index);
    final hasDetails = (banner.description != null &&
            banner.description!.trim().isNotEmpty);

    final imageUrl = (banner.popup != null && banner.popup!.trim().isNotEmpty)
        ? banner.popup!.trim()
        : banner.photo.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (hasDetails) {
          _toggleSlideDetails(index);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Gambar Banner Promo Utama (Sesuai ukuran poster, tanpa background tambahan)
          CachedImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            errorWidget: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        size: 56,
                        color: Color(0xFFDD2222),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        banner.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (banner.description != null &&
                          banner.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          banner.description!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Dimming Overlay + Judul & Deskripsi S&K (Muncul saat poster diklik)
          AnimatedOpacity(
            opacity: isShowingDetails ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !isShowingDetails,
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Judul Promo
                        Text(
                          banner.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDD2222),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Konten Deskripsi & S&K
                        Expanded(
                          child: Theme(
                            data: ThemeData(
                              scrollbarTheme: ScrollbarThemeData(
                                thumbColor: WidgetStateProperty.all(
                                  Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            child: Scrollbar(
                              thumbVisibility: true,
                              radius: const Radius.circular(4),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  banner.description ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFFF1F5F9),
                                    fontSize: 13,
                                    height: 1.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        // Tombol / Badge kembali ke gambar poster
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tr.get('tap_to_view_poster', lang),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Pill Hint (Hanya muncul jika poster memiliki isi S&K di deskripsi)
          if (!isShowingDetails && hasDetails)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tr.get('tap_image_for_tnc', lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
