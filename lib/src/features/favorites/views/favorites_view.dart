import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/widgets/cached_image.dart';
import '../controllers/favorite_controller.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/models/brand_model.dart';
import '../../menu/views/brand_branch_selection_view.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../shared/widgets/price_display_widget.dart';

class FavoritesView extends ConsumerWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=0',
            color: Colors.white,
          ),
          title: Text(tr.get('favorites_title', lang)), backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: favoritesAsync.when(
          data: (favorites) {
            if (favorites.isEmpty) {
              return _buildEmptyState(context, lang);
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(favoritesProvider);
              },
              color: const Color(0xFFDD2222),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  final menu = favorite.menu;

                  if (menu == null) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        final branches = ref.read(branchesProvider).valueOrNull;
                        final targetBranchId = menu.branchesId ?? menu.branchId;
                        if (branches != null && targetBranchId != null) {
                          final matchingBranches =
                              branches.where((b) => b.id == targetBranchId);
                          if (matchingBranches.isNotEmpty) {
                            final branch = matchingBranches.first;
                            ref.read(selectedBranchProvider.notifier).state =
                                branch;
                            ref.read(selectedBrandProvider.notifier).state =
                                Brand(
                              id: branch.brandId,
                              name: branch.brandName,
                              logo: branch.brandLogo ?? '',
                              service: 0,
                              tax: 0,
                              category: const []);
                          }
                        }

                        final branchQuery = targetBranchId != null
                            ? '?branchId=$targetBranchId'
                            : '';
                        context.push('/product/${menu.id}$branchQuery');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Menu Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: menu.photo.isNotEmpty
                                  ? CachedImage(
                                      imageUrl: menu.photo,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorWidget: Image.asset(
                                        'assets/images/logo.png',
                                        width: 80,
                                        height: 80,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.fastfood,
                                          size: 38,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.fastfood,
                                        size: 38,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),

                            // Menu Details (matching Gambar 3: Name, Rating/Sold, Price with discount badge)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    menu.name,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Rating & Sold Row
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        menu.averageRating > 0
                                            ? menu.averageRating.toStringAsFixed(1)
                                            : '0.0',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (menu.reviewCount > 0) ...[
                                        const SizedBox(width: 2),
                                        Text(
                                          '(${menu.reviewCount})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 5),
                                      Text(
                                        '•',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          menu.formattedSoldFor(lang),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Price with strikethrough and discount percentage badge
                                  PriceDisplayWidget.fromMenu(
                                    menu: menu,
                                    fontSize: 16,
                                    priceColor: const Color(0xFFDD2222),
                                    showBadge: true,
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              icon: const Icon(
                                Icons.favorite,
                                color: Color(0xFFDD2222),
                              ),
                              onPressed: () {
                                _showRemoveDialog(
                                    context, ref, menu.id, menu.name);
                              },
                            ),
                          ],
                        ),
                      ),
                    ));
                },
              ));
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFDD2222),
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  lang == AppLanguage.indonesia
                      ? 'Gagal memuat favorit'
                      : 'Failed to load favorites',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(favoritesProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                  ),
                  child: Text(tr.get('retry', lang),
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ));
  }

  Widget _buildEmptyState(BuildContext context, AppLanguage lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            lang == AppLanguage.indonesia ? 'Belum Ada Favorit' : 'No Favorites Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang == AppLanguage.indonesia
                ? 'Mulai tambahkan produk favorit Anda'
                : 'Start adding your favorite items',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/navigation?index=1'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(tr.get('explore_menu_btn', lang),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ));
  }

  void _showRemoveDialog(
      BuildContext context, WidgetRef ref, int menuId, String menuName) async {
    final lang = ref.read(appLanguageProvider);
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: tr.get('remove_favorite_title', lang),
      message: lang == AppLanguage.indonesia
          ? 'Hapus "$menuName" dari favorit?'
          : 'Remove "$menuName" from favorites?',
      confirmText: tr.get('remove_btn', lang),
      cancelText: tr.get('cancel', lang),
      type: AppDialogType.danger,
    );

    if (!confirmed) return;

    await ref
        .read(favoriteControllerProvider.notifier)
        .removeFavorite(menuId);

    if (context.mounted) {
      Helpers.showSnackbar(
          context, tr.get('removed_favorites_msg', lang),
          backgroundColor: Colors.green);
    }
  }
}
