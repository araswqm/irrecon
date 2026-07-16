import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

/// State for the brand/model search screen.
class SearchState {
  final String query;
  final bool isLoading;
  final List<BrandSearchHit> brandResults;
  final List<ModelSearchHit> modelResults;
  final String? error;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.brandResults = const [],
    this.modelResults = const [],
    this.error,
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    List<BrandSearchHit>? brandResults,
    List<ModelSearchHit>? modelResults,
    String? error,
    bool clearResults = false,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      brandResults: clearResults ? [] : (brandResults ?? this.brandResults),
      modelResults: clearResults ? [] : (modelResults ?? this.modelResults),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for the search screen with debounced fuzzy search.
class SearchNotifier extends StateNotifier<SearchState> {
  final AppDatabase _db;
  Timer? _debounce;

  SearchNotifier(this._db) : super(const SearchState());

  /// Set the search query (debounced).
  void setQuery(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = state.copyWith(clearResults: true);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final brands = await _db.fuzzySearchBrands(query);
      final models = await _db.fuzzySearchModels(query);
      state = state.copyWith(
        brandResults: brands,
        modelResults: models,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(AppDatabase());
});
