import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/brand_name_formatter.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/models/brand_model.dart';
import '../../../shared/models/branch_model.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../../core/widgets/app_dialog.dart';

String _formatBrandName(String name) => formatBrandName(name);



// State provider to track selected brand and branch
final selectedBrandProvider = StateProvider<Brand?>((ref) => null);
final selectedBranchProvider = StateProvider<Branch?>((ref) => null);

class BrandBranchSelectionView extends ConsumerStatefulWidget {
  final String? initialBrandId;
  
  const BrandBranchSelectionView({super.key, this.initialBrandId});

  @override
  ConsumerState<BrandBranchSelectionView> createState() => _BrandBranchSelectionViewState();
}

class _BrandBranchSelectionViewState extends ConsumerState<BrandBranchSelectionView> {
  Brand? _selectedBrand;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Wait for next frame to initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelection();
    });
  }

  void _initializeSelection() {
    if (_hasInitialized) return;
    
    final brandsAsync = ref.read(brandsProvider);
    brandsAsync.whenData((brands) {
      if (!mounted || brands.isEmpty || _hasInitialized) return;
      
      Brand? brandToSelect;
      
      // Try to find brand from initialBrandId
      if (widget.initialBrandId != null) {
        try {
          brandToSelect = brands.firstWhere(
            (b) => b.id.toString() == widget.initialBrandId);
        } catch (_) {
          // Brand not found, will select first
        }
      }
      
      // If no initial brand or not found, select first brand
      brandToSelect ??= brands.first;
      
      setState(() {
        _selectedBrand = brandToSelect;
        _hasInitialized = true;
      });
      ref.read(selectedBrandProvider.notifier).state = brandToSelect;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(brandsProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=0',
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=0',
            color: Colors.white,
          ),
          title: Text(tr.get('select_branch', lang).toUpperCase()),
          backgroundColor: const Color(0xFFDD2222),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: brandsAsync.when(
          data: (brands) {
            if (brands.isEmpty) {
              return Center(
                child: Text(tr.get('no_brands_available', lang)));
            }

            return Column(
              children: [
                // Brand Selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: brands.length,
                      itemBuilder: (context, index) {
                        final brand = brands[index];
                        final isSelected = _selectedBrand?.id == brand.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedBrand = brand;
                            });
                            ref.read(selectedBrandProvider.notifier).state = brand;
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFDD2222)
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFDD2222).withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedImage(
                                      imageUrl: brand.logo,
                                      fit: BoxFit.contain,
                                      errorWidget: const Icon(
                                        Icons.restaurant,
                                        size: 32,
                                        color: Color(0xFFDD2222),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    _formatBrandName(brand.name),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? const Color(0xFFDD2222)
                                          : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Branch Selection
                if (_selectedBrand != null)
                  Expanded(
                    child: _BranchList(brandId: _selectedBrand!.id.toString()),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('${tr.get('unable_to_load_brands', lang)}: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(brandsProvider),
                  child: Text(tr.get('retry', lang)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchList extends ConsumerStatefulWidget {
  final String brandId;

  const _BranchList({required this.brandId});

  @override
  ConsumerState<_BranchList> createState() => _BranchListState();
}

class _BranchListState extends ConsumerState<_BranchList> {
  List<BranchWithDistance>? _sortedBranches;
  bool _isLoadingLocation = false;
  bool _hasLoadedLocation = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    // Load location and sort after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedLocation) {
        _loadAndSortBranches();
      }
    });
  }

  @override
  void didUpdateWidget(_BranchList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset if brand changes
    if (oldWidget.brandId != widget.brandId) {
      setState(() {
        _sortedBranches = null;
        _isLoadingLocation = false;
        _hasLoadedLocation = false;
        _locationMessage = null;
      });
      // Load for new brand
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasLoadedLocation) {
          _loadAndSortBranches();
        }
      });
    }
  }

  Future<void> _loadAndSortBranches() async {
    if (!mounted || _hasLoadedLocation || _isLoadingLocation) return;

    final branches = ref.read(branchesByBrandProvider(widget.brandId)).maybeWhen(
      data: (branches) => branches,
      orElse: () => null);

    if (branches == null || branches.isEmpty) return;

    _hasLoadedLocation = true;

    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();

      if (!mounted) return;

      if (position != null) {
        final sorted = await locationService.getBranchesByDistance(
          branches,
          position);
        if (mounted) {
          setState(() {
            _sortedBranches = sorted;
            _isLoadingLocation = false;
            _locationMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _sortedBranches = null;
            _isLoadingLocation = false;
            _locationMessage = tr.get('enable_location_permission', ref.read(appLanguageProvider));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sortedBranches = null;
          _isLoadingLocation = false;
          _locationMessage = tr.get('unable_to_calculate_distance', ref.read(appLanguageProvider));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedBrand = ref.watch(selectedBrandProvider);
    final branchesAsync = ref.watch(branchesByBrandProvider(widget.brandId));
    final lang = ref.watch(appLanguageProvider);

    return branchesAsync.when(
      data: (branches) {
        if (branches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  tr.get('no_branches_available', lang),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr.get('brand_has_no_branches', lang),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        if (!_hasLoadedLocation && !_isLoadingLocation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasLoadedLocation && !_isLoadingLocation) {
              _loadAndSortBranches();
            }
          });
        }

        final displayBranches = _sortedBranches ?? 
            branches.map((b) => BranchWithDistance(branch: b, distance: 0)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedBrand != null
                          ? '${_formatBrandName(selectedBrand.name)} Outlet (${branches.length})'
                          : '${tr.get('select_outlet_header', lang)} (${branches.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoadingLocation)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr.get('sorting_distance', lang),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    )
                  else if (_locationMessage != null)
                    Flexible(
                      child: Text(
                        _locationMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _isLoadingLocation = false;
                    _hasLoadedLocation = false;
                    _sortedBranches = null;
                    _locationMessage = null;
                  });
                  ref.invalidate(branchesByBrandProvider(widget.brandId));
                  await _loadAndSortBranches();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: displayBranches.length,
                  itemBuilder: (context, index) {
                    final branchWithDistance = displayBranches[index];
                    final branch = branchWithDistance.branch;
                    final showDistance = _sortedBranches != null &&
                        !branchWithDistance.distance.isInfinite;
                    final isTerdekat = index == 0 && showDistance;

                    return Container(
                      margin: EdgeInsets.only(
                        top: isTerdekat ? 10 : 0,
                        bottom: 16,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Card(
                            margin: EdgeInsets.zero,
                            elevation: 2,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: isTerdekat
                                  ? const BorderSide(
                                      color: Color(0xFFDD2222), width: 1.8)
                                  : BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final currentSelectedBranch =
                                    ref.read(selectedBranchProvider);
                                final cartAsync = AuthGuard.isAuthenticated(ref)
                                    ? await ref.read(cartProvider.future)
                                    : null;

                                final hasCartItems =
                                    cartAsync?.items.isNotEmpty ?? false;
                                final isDifferentBranch =
                                    currentSelectedBranch != null &&
                                        currentSelectedBranch.id.toString() !=
                                            branch.id.toString();

                                if (hasCartItems && isDifferentBranch) {
                                  if (!context.mounted) return;
                                  final shouldClear = await AppDialog.showConfirm(
                                    context: context,
                                    title: tr.get('change_branch_dialog_title', lang),
                                    message: tr.get('change_branch_dialog_desc', lang),
                                    confirmText: tr.get('clear_cart', lang),
                                    cancelText: tr.get('cancel', lang),
                                    type: AppDialogType.danger,
                                  );

                                  if (shouldClear == true) {
                                    await ref
                                        .read(cartControllerProvider.notifier)
                                        .clearCart();
                                    ref.invalidate(cartProvider);

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(tr.get('cart_cleared_snack', lang)),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 2),
                                        ));
                                    }
                                  } else {
                                    return;
                                  }
                                }

                                if (context.mounted) {
                                  ref
                                      .read(selectedBranchProvider.notifier)
                                      .state = branch;
                                  context.go(
                                      '/menu?brandId=${branch.brandId}&branchId=${branch.id}');
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      branch.outlet
                                          .replaceAll('TOMOKO', 'Tomoko')
                                          .replaceAll('AH BANG', 'Ah Bang'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (branch.address != null && branch.address!.trim().isNotEmpty)
                                          ? branch.address!.trim()
                                          : branch.location,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF111827),
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    // Row: Open Hours & Distance
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 13.5,
                                          color: branch.isOpenNow
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFDC2626),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          branch.isOpenNow
                                              ? tr.get('open_status', lang)
                                              : tr.get('closed_status', lang),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: branch.isOpenNow
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFDC2626),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '(${branch.openingHours.length >= 5 ? branch.openingHours.substring(0, 5) : branch.openingHours} - ${branch.closingHours.length >= 5 ? branch.closingHours.substring(0, 5) : branch.closingHours} WIB)',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF334155),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (showDistance && !branchWithDistance.distance.isInfinite) ...[
                                          const SizedBox(width: 6),
                                          const Text('•',
                                              style: TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 11)),
                                          const SizedBox(width: 6),
                                          Text(
                                            branchWithDistance.distance < 1
                                                ? '${(branchWithDistance.distance * 1000).round()} m'
                                                : '${branchWithDistance.distance.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFDD2222),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Map Button
                                    InkWell(
                                      onTap: () async {
                                        final addressQuery =
                                            (branch.address?.isNotEmpty ?? false)
                                                ? '${branch.outlet}, ${branch.address}'
                                                : branch.location;
                                        final Uri mapUri = Uri.parse(
                                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addressQuery)}');
                                        try {
                                          if (await canLaunchUrl(
                                              mapUri)) {
                                            await launchUrl(
                                              mapUri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                          }
                                        } catch (_) {}
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.map_outlined,
                                              size: 14,
                                              color: Color(0xFF111827),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              tr.get('view_location_on_map', lang),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF111827),
                                                fontWeight: FontWeight.normal,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // TERDEKAT badge overlay
                          if (isTerdekat)
                            Positioned(
                              top: -10,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDD2222),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  tr.get('nearest', lang),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.normal,
                                    letterSpacing: 0.5,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFDD2222),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                tr.get('unable_to_load_outlets', lang),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(branchesByBrandProvider(widget.brandId));
                },
                icon: const Icon(Icons.refresh),
                label: Text(tr.get('retry', lang)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
