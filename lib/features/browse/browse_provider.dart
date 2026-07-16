import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/models/device_type.dart';
import '../../data/models/brand.dart';
import '../../data/models/ir_model.dart';

/// State for the chained-dropdown browse screen.
class BrowseState {
  final List<DeviceType> deviceTypes;
  final int? selectedDeviceTypeId;
  final List<IRBrand> brands;
  final int? selectedBrandId;
  final List<IRModel> models;
  final int? selectedModelId;
  final bool isLoading;
  final String? error;

  const BrowseState({
    this.deviceTypes = const [],
    this.selectedDeviceTypeId,
    this.brands = const [],
    this.selectedBrandId,
    this.models = const [],
    this.selectedModelId,
    this.isLoading = false,
    this.error,
  });

  BrowseState copyWith({
    List<DeviceType>? deviceTypes,
    int? selectedDeviceTypeId,
    List<IRBrand>? brands,
    int? selectedBrandId,
    List<IRModel>? models,
    int? selectedModelId,
    bool? isLoading,
    String? error,
    bool clearBrands = false,
    bool clearModels = false,
    bool clearError = false,
  }) {
    return BrowseState(
      deviceTypes: deviceTypes ?? this.deviceTypes,
      selectedDeviceTypeId: selectedDeviceTypeId ?? this.selectedDeviceTypeId,
      brands: clearBrands ? [] : (brands ?? this.brands),
      selectedBrandId: selectedBrandId ?? this.selectedBrandId,
      models: clearModels ? [] : (models ?? this.models),
      selectedModelId: selectedModelId ?? this.selectedModelId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod notifier for the browse screen.
class BrowseNotifier extends StateNotifier<BrowseState> {
  final AppDatabase _db;

  BrowseNotifier(this._db) : super(const BrowseState()) {
    _loadDeviceTypes();
  }

  Future<void> _loadDeviceTypes() async {
    try {
      final types = await _db.getDeviceTypes();
      var newState = state.copyWith(deviceTypes: types);
      // Validate previously selected device type still exists (DB may have been re-indexed)
      if (state.selectedDeviceTypeId != null &&
          !types.any((dt) => dt.id == state.selectedDeviceTypeId)) {
        newState = newState.copyWith(
          selectedDeviceTypeId: null,
          clearBrands: true,
          clearModels: true,
        );
      }
      state = newState;
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> selectDeviceType(int deviceTypeId) async {
    state = state.copyWith(
      selectedDeviceTypeId: deviceTypeId,
      selectedBrandId: null,
      selectedModelId: null,
      isLoading: true,
      clearBrands: true,
      clearModels: true,
    );

    try {
      final brands = await _db.getBrandsByDeviceType(deviceTypeId);
      state = state.copyWith(brands: brands, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> selectBrand(int brandId) async {
    state = state.copyWith(
      selectedBrandId: brandId,
      selectedModelId: null,
      isLoading: true,
      clearModels: true,
    );

    try {
      final models = await _db.getModelsByBrand(brandId);
      state = state.copyWith(models: models, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void selectModel(int modelId) {
    state = state.copyWith(selectedModelId: modelId);
  }

  void reset() {
    state = const BrowseState();
    _loadDeviceTypes();
  }

  /// Force a complete reload from the database (e.g. after DB re-index).
  void refresh() {
    state = const BrowseState();
    _loadDeviceTypes();
  }
}

final browseProvider =
    StateNotifierProvider<BrowseNotifier, BrowseState>((ref) {
  return BrowseNotifier(AppDatabase());
});
