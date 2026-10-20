import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_client.dart';
import '../../../shared/services/service_providers.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final locationService = ref.watch(locationServiceProvider);
  return SearchService(apiClient, locationService);
});

class GlobalSearchState {
  final String query;
  final bool isLoading;
  final GlobalSearchResult? result;
  final List<String> recentSearches;

  const GlobalSearchState({
    this.query = '',
    this.isLoading = false,
    this.result,
    this.recentSearches = const [],
  });

  GlobalSearchState copyWith({
    String? query,
    bool? isLoading,
    GlobalSearchResult? result,
    bool clearResult = false,
    List<String>? recentSearches,
  }) {
    return GlobalSearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }
}

class GlobalSearchNotifier extends StateNotifier<GlobalSearchState> {
  final SearchService _searchService;
  Timer? _debounceTimer;
  static const String _recentSearchesKey = 'delitopia_global_recent_searches';

  GlobalSearchNotifier(this._searchService) : super(const GlobalSearchState()) {
    _loadRecentSearches();
    _searchService.preloadData();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? [];
      state = state.copyWith(recentSearches: list);
    } catch (_) {}
  }

  Future<void> _saveRecentSearches(List<String> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, list);
    } catch (_) {}
  }

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      state = state.copyWith(query: '', isLoading: false, clearResult: true);
    } else {
      // Tidak melakukan pencarian per karakter.
      // Reset hasil sebelumnya saat user mengedit/mengetik agar tidak membingungkan,
      // tanpa menampilkan spinner loading.
      state = state.copyWith(query: query, isLoading: false, clearResult: true);
    }
  }

  Future<void> executeSearch(String query) async {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      state = state.copyWith(isLoading: false, clearResult: true);
      return;
    }

    state = state.copyWith(isLoading: true, query: clean);
    _saveToRecent(clean);

    try {
      final res = await _searchService.search(clean);
      state = state.copyWith(isLoading: false, result: res);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        result: const GlobalSearchResult(outlets: [], menus: []),
      );
    }
  }

  void _saveToRecent(String query) {
    final current = List<String>.from(state.recentSearches);
    current.remove(query);
    current.insert(0, query);
    if (current.length > 8) {
      current.removeLast();
    }
    state = state.copyWith(recentSearches: current);
    _saveRecentSearches(current);
  }

  void removeRecentSearch(String query) {
    final current = List<String>.from(state.recentSearches);
    current.remove(query);
    state = state.copyWith(recentSearches: current);
    _saveRecentSearches(current);
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: const []);
    _saveRecentSearches(const []);
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    state = state.copyWith(query: '', isLoading: false, clearResult: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final globalSearchProvider =
    StateNotifierProvider.autoDispose<GlobalSearchNotifier, GlobalSearchState>(
        (ref) {
  final service = ref.watch(searchServiceProvider);
  return GlobalSearchNotifier(service);
});
