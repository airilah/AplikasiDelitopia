import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/models/review_model.dart';
import '../controllers/menu_controller.dart';

class ProductReviewsView extends ConsumerStatefulWidget {
  final int productId;
  final String? productName;

  const ProductReviewsView({
    super.key,
    required this.productId,
    this.productName,
  });

  @override
  ConsumerState<ProductReviewsView> createState() => _ProductReviewsViewState();
}

class _ProductReviewsViewState extends ConsumerState<ProductReviewsView> {
  String _reviewFilter = 'all'; // 'all', 'comment', 'star'
  int _selectedStar = 5;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;

    final filterKey = MenuReviewsKey(
      menuId: widget.productId,
      rating: _reviewFilter == 'star' ? _selectedStar : null,
      withComment: _reviewFilter == 'comment',
      all: _showAll,
      perPage: _showAll ? 1000 : 3,
    );
    final reviewsAsync = ref.watch(menuReviewsProvider(filterKey));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDD2222),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/navigation?index=1');
            }
          },
        ),
        actions: const [
          SizedBox(width: 48),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isIndo ? 'ULASAN MENU' : 'MENU REVIEWS',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.productName != null && widget.productName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.productName!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
      body: reviewsAsync.when(
        data: (reviewsData) {
          final total = reviewsData.totalReviews;
          final withComment = reviewsData.totalWithComment;
          final avgRating = reviewsData.averageRating;

          return RefreshIndicator(
            color: const Color(0xFFDD2222),
            onRefresh: () async {
              ref.invalidate(menuReviewsProvider(filterKey));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // 1. Rating Summary Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Big Score
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            total > 0 ? avgRating.toStringAsFixed(1) : '5.0',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (idx) {
                              final score = total > 0 ? avgRating : 5.0;
                              return Icon(
                                idx < score.floor()
                                    ? Icons.star_rounded
                                    : (idx < score
                                        ? Icons.star_half_rounded
                                        : Icons.star_outline_rounded),
                                color: const Color(0xFFF59E0B),
                                size: 16,
                              );
                            }),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            isIndo ? 'dari $total ulasan' : 'from $total reviews',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      // Divider
                      Container(
                        height: 70,
                        width: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 18),
                      // Star Breakdown Bars
                      Expanded(
                        child: Column(
                          children: [5, 4, 3, 2, 1].map((star) {
                            final count = reviewsData.ratingBreakdown[star] ?? 0;
                            final ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Row(
                                children: [
                                  Text(
                                    '$star',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 6,
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '$count',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // All
                      _buildChip(
                        label: isIndo ? 'Semua ($total)' : 'All ($total)',
                        isSelected: _reviewFilter == 'all',
                        onTap: () => setState(() {
                          _reviewFilter = 'all';
                          _showAll = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      // With Comments
                      _buildChip(
                        label: isIndo ? 'Dengan Komentar ($withComment)' : 'With Comments ($withComment)',
                        isSelected: _reviewFilter == 'comment',
                        onTap: () => setState(() {
                          _reviewFilter = 'comment';
                          _showAll = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      // Star 5 to 1
                      for (int star = 5; star >= 1; star--) ...[
                        _buildChip(
                          label: '$star ★ (${reviewsData.ratingBreakdown[star] ?? 0})',
                          isSelected: _reviewFilter == 'star' && _selectedStar == star,
                          onTap: () => setState(() {
                            _reviewFilter = 'star';
                            _selectedStar = star;
                            _showAll = false;
                          }),
                        ),
                        if (star > 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Review Items List
                if (reviewsData.reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined, size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          isIndo ? 'Belum Ada Ulasan' : 'No Reviews Found',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isIndo
                              ? 'Ulasan untuk filter ini belum tersedia.'
                              : 'Reviews matching this filter are not available yet.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  Builder(builder: (context) {
                    final int currentFilterTotal = _reviewFilter == 'comment'
                        ? reviewsData.totalWithComment
                        : (_reviewFilter == 'star'
                            ? (reviewsData.ratingBreakdown[_selectedStar] ?? 0)
                            : reviewsData.totalReviews);

                    final displayedReviews = _showAll
                        ? reviewsData.reviews
                        : reviewsData.reviews.take(3).toList();
                    final hasMoreReviews = !_showAll &&
                        (currentFilterTotal > 3 || reviewsData.reviews.length > 3);

                    return Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedReviews.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final review = displayedReviews[index];
                            return _buildReviewCard(review, isIndo);
                          },
                        ),
                        if (hasMoreReviews) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showAll = true;
                                });
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: const Color(0xFFDD2222), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDD2222)
                                          .withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isIndo
                                          ? 'Lihat Semua ($currentFilterTotal Ulasan)'
                                          : 'See All ($currentFilterTotal Reviews)',
                                      style: const TextStyle(
                                        color: Color(0xFFDD2222),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFFDD2222),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else if (_showAll && (currentFilterTotal > 3 || reviewsData.reviews.length > 3)) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showAll = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: const Color(0xFF94A3B8), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isIndo ? 'Tampilkan Lebih Sedikit' : 'Show Less',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      color: Color(0xFF64748B),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFDD2222)),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                isIndo ? 'Gagal memuat ulasan' : 'Failed to load reviews',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(menuReviewsProvider(filterKey)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD2222)),
                child: Text(
                  isIndo ? 'Coba Lagi' : 'Retry',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFDD2222) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFFDD2222) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(MenuReviewItem review, bool isIndo) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: review.userPhoto != null && review.userPhoto!.isNotEmpty
                    ? CachedNetworkImageProvider(review.userPhoto!)
                    : null,
                child: (review.userPhoto == null || review.userPhoto!.isEmpty)
                    ? const Icon(Icons.person, size: 18, color: Color(0xFF94A3B8))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.maskedName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      review.formattedDate(isIndo),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(5, (starIdx) {
                  return Icon(
                    starIdx < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 16,
                  );
                }),
              ),
            ],
          ),

          // Quick Tags
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: review.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Comment
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!.trim(),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
