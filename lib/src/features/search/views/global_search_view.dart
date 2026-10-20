import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_language.dart';
import '../controllers/search_controller.dart';
import '../models/search_result.dart';

class GlobalSearchView extends ConsumerStatefulWidget {
  const GlobalSearchView({super.key});

  @override
  ConsumerState<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends ConsumerState<GlobalSearchView> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedTabIndex = 0; // 0: Semua, 1: Makanan, 2: Outlet

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchItemTapped(String text) {
    _focusNode.unfocus();
    _textController.text = text;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    ref.read(globalSearchProvider.notifier).executeSearch(text);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(globalSearchProvider);
    final searchNotifier = ref.read(globalSearchProvider.notifier);
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFFDD2222),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/navigation?index=0');
              }
            },
          ),
          titleSpacing: 0,
          title: Container(
            height: 42,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
                decoration: InputDecoration(
                  hintText: lang == AppLanguage.indonesia
                      ? 'Cari makanan atau outlet...'
                      : 'Search food or outlet...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: IconButton(
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFDD2222),
                      size: 20,
                    ),
                    onPressed: () {
                      final clean = _textController.text.trim();
                      if (clean.isNotEmpty) {
                        _focusNode.unfocus();
                        searchNotifier.executeSearch(clean);
                      }
                    },
                  ),
                  suffixIcon: _textController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Colors.grey),
                          onPressed: () {
                            _textController.clear();
                            searchNotifier.clearQuery();
                            setState(() {
                              _selectedTabIndex = 0;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  searchNotifier.onQueryChanged(val);
                  setState(() {});
                },
                onSubmitted: (val) {
                  final clean = val.trim();
                  if (clean.isNotEmpty) {
                    _focusNode.unfocus();
                    searchNotifier.executeSearch(clean);
                  }
                },
              ),
            ),
          ),
          bottom: searchState.isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    color: Colors.white,
                    backgroundColor: Color(0xFFDD2222),
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: _buildBody(context, searchState, searchNotifier, lang),
      );
  }

  Widget _buildBody(
    BuildContext context,
    GlobalSearchState state,
    GlobalSearchNotifier notifier,
    AppLanguage lang,
  ) {
    // 1. Loading State without previous result
    if (state.isLoading && state.result == null) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFFDD2222),
          ),
        ),
      );
    }

    // 2. Idle State / Typing in progress: No search result submitted yet
    if (state.result == null) {
      return _buildIdleView(state, notifier, lang);
    }

    final result = state.result!;

    // 3. Empty Search Result
    if (result.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                lang == AppLanguage.indonesia
                    ? 'Makanan atau outlet tidak ditemukan'
                    : 'Food or outlet not found',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                lang == AppLanguage.indonesia
                    ? 'Coba gunakan kata kunci lain seperti nama makanan atau cabang terdekat'
                    : 'Try using other keywords like dish name or nearest branch',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 4. Results View with Category Tabs (Konsep A)
    return Column(
      children: [
        _buildCategoryTabs(result, lang),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        Expanded(
          child: _buildTabContent(context, result, lang),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs(GlobalSearchResult result, AppLanguage lang) {
    final int foodCount = result.menus.length;
    final int outletCount = result.outlets.length;
    final int allCount = foodCount + outletCount;

    final tabs = [
      {'label': lang == AppLanguage.indonesia ? 'Semua' : 'All', 'count': allCount},
      {'label': lang == AppLanguage.indonesia ? 'Makanan' : 'Food', 'count': foodCount},
      {'label': lang == AppLanguage.indonesia ? 'Outlet' : 'Outlets', 'count': outletCount},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final tab = tabs[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFDD2222) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFDD2222) : Colors.grey.shade300,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF444444),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${tab['count']}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    GlobalSearchResult result,
    AppLanguage lang,
  ) {
    if (_selectedTabIndex == 1) {
      // TAB: Makanan
      if (result.menus.isEmpty) {
        return _buildEmptySection(
          icon: Icons.fastfood_outlined,
          message: lang == AppLanguage.indonesia
              ? 'Tidak ada menu makanan yang cocok'
              : 'No matching food menus',
        );
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: result.menus.length,
        itemBuilder: (context, index) {
          return _buildMenuItem(context, result.menus[index], lang);
        },
      );
    }

    if (_selectedTabIndex == 2) {
      // TAB: Outlet
      if (result.outlets.isEmpty) {
        return _buildEmptySection(
          icon: Icons.storefront_outlined,
          message: lang == AppLanguage.indonesia
              ? 'Tidak ada outlet yang cocok'
              : 'No matching outlets',
        );
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: result.outlets.length,
        itemBuilder: (context, index) {
          return _buildOutletItem(context, result.outlets[index]);
        },
      );
    }

    // TAB: Semua (0)
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Outlets Section (maksimal 2 kartu di tab semua agar tidak menutupi menu)
        if (result.outlets.isNotEmpty) ...[
          _buildSectionHeader(
            title: lang == AppLanguage.indonesia ? 'OUTLET TERDEKAT' : 'NEAREST OUTLETS',
            count: result.outlets.length,
            showSeeAll: result.outlets.length > 2,
            onSeeAll: () {
              setState(() {
                _selectedTabIndex = 2;
              });
            },
          ),
          for (final outlet in result.outlets.take(2))
            _buildOutletItem(context, outlet),
        ],

        // Menus Section
        if (result.menus.isNotEmpty) ...[
          _buildSectionHeader(
            title: lang == AppLanguage.indonesia ? 'MENU MAKANAN' : 'FOOD MENUS',
            count: result.menus.length,
          ),
          for (final menu in result.menus)
            _buildMenuItem(context, menu, lang),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    bool showSeeAll = false,
    VoidCallback? onSeeAll,
  }) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF666666),
              letterSpacing: 0.6,
            ),
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                ref.watch(appLanguageProvider) == AppLanguage.indonesia ? 'Lihat Semua' : 'See All',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDD2222),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySection({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletItem(BuildContext context, SearchOutletItem outlet) {
    final lang = ref.watch(appLanguageProvider);
    return InkWell(
      onTap: () {
        context.push('/menu?branchId=${outlet.branchId}&brandId=${outlet.brandId}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1.0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: Nama Outlet Bersih & Jarak
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    outlet.outletName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (outlet.distanceText.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    outlet.distanceText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),

            // Baris 2: Alamat Cabang
            Text(
              outlet.address,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Baris 3: Status Buka • Jam Operasional
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: outlet.isOpen
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    outlet.isOpen ? (lang == AppLanguage.indonesia ? 'Buka' : 'Open') : (lang == AppLanguage.indonesia ? 'Tutup' : 'Closed'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: outlet.isOpen
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD32F2F),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  outlet.hoursText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    SearchMenuItem menu,
    AppLanguage lang,
  ) {
    return InkWell(
      onTap: () {
        context.push('/product/${menu.menuId}?branchId=${menu.branchId}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1.0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: Nama Menu & Jarak
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    menu.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (menu.distanceText.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    menu.distanceText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),

            // Baris 2: Harga • Terjual
            Row(
              children: [
                Text(
                  menu.formattedPrice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDD2222),
                  ),
                ),
                if (menu.soldCount > 0) ...[
                  Text(
                    ' • ${menu.formattedSold(lang)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Baris 3: Status Buka • Nama Cabang Bersih
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: menu.isOpen
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    menu.isOpen ? (lang == AppLanguage.indonesia ? 'Buka' : 'Open') : (lang == AppLanguage.indonesia ? 'Tutup' : 'Closed'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: menu.isOpen
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD32F2F),
                    ),
                  ),
                ),
                if (menu.branchName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      menu.branchName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleView(
    GlobalSearchState state,
    GlobalSearchNotifier notifier,
    AppLanguage lang,
  ) {
    final currentQuery = state.query.trim();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Quick Action: Cari "<query yang diketik>"
        if (currentQuery.isNotEmpty) ...[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _focusNode.unfocus();
              notifier.executeSearch(currentQuery);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDD2222).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDD2222).withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFDD2222),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: lang == AppLanguage.indonesia
                            ? 'Cari "'
                            : 'Search "',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                        children: [
                          TextSpan(
                            text: currentQuery,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDD2222),
                            ),
                          ),
                          const TextSpan(text: '"'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFFDD2222),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Riwayat Pencarian Terakhir
        if (state.recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == AppLanguage.indonesia
                    ? 'Pencarian Terakhir'
                    : 'Recent Searches',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333),
                ),
              ),
              GestureDetector(
                onTap: () => notifier.clearRecentSearches(),
                child: Text(
                  lang == AppLanguage.indonesia ? 'Hapus' : 'Clear',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDD2222),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.recentSearches.map((item) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _onSearchItemTapped(item),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF444444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => notifier.removeRecentSearch(item),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Saran Pencarian Populer
        Text(
          lang == AppLanguage.indonesia
              ? 'Pencarian Populer'
              : 'Popular Searches',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Salmon Sushi',
            'Sushi Roll',
            'Sushikun PTC',
            'Ramen',
            'Kopitiam',
            'Bento',
          ].map((item) {
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _onSearchItemTapped(item),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFDD2222).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFDD2222).withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFDD2222),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
