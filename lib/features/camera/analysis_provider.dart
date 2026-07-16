import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/api_engine.dart';
import '../../core/api/openai_provider.dart';
import '../../core/api/anthropic_provider.dart';
import '../../core/api/gemini_provider.dart';
import '../../core/api/ollama_provider.dart';
import '../../core/api/custom_provider.dart';
import '../../core/api/deepseek_provider.dart';
import '../../core/utils/image_optimizer.dart';
import '../../data/models/analysis_result.dart';
import '../../data/database/app_database.dart';
import '../../core/constants.dart';

/// The current step in the camera analysis flow.
enum AnalysisStep {
  idle,
  pickingImage,
  optimizingImage,
  callingLLM,
  matchingDatabase,
  complete,
  error,
}

/// State for the camera analysis flow.
class AnalysisState {
  final AnalysisStep step;
  final String? imageBase64;
  final String? errorMessage;
  final AnalysisResult? result;
  final List<({String modelName, double score})> matches;
  final int? selectedBrandId;
  final int? selectedModelId;

  const AnalysisState({
    this.step = AnalysisStep.idle,
    this.imageBase64,
    this.errorMessage,
    this.result,
    this.matches = const [],
    this.selectedBrandId,
    this.selectedModelId,
  });

  AnalysisState copyWith({
    AnalysisStep? step,
    String? imageBase64,
    String? errorMessage,
    AnalysisResult? result,
    List<({String modelName, double score})>? matches,
    int? selectedBrandId,
    int? selectedModelId,
    bool clearImage = false,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return AnalysisState(
      step: step ?? this.step,
      imageBase64: clearImage ? null : (imageBase64 ?? this.imageBase64),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      result: clearResult ? null : (result ?? this.result),
      matches: matches ?? this.matches,
      selectedBrandId: selectedBrandId ?? this.selectedBrandId,
      selectedModelId: selectedModelId ?? this.selectedModelId,
    );
  }
}

/// Riverpod notifier for the camera analysis flow.
class AnalysisNotifier extends StateNotifier<AnalysisState> {
  AnalysisNotifier() : super(const AnalysisState());

  Future<void> pickAndAnalyze(File imageFile) async {
    // Step 1: Optimize image
    state = state.copyWith(
      step: AnalysisStep.optimizingImage,
      clearResult: true,
      clearError: true,
    );

    try {
      final base64 = await ImageOptimizer.resizeToBase64(imageFile: imageFile);
      state = state.copyWith(
        step: AnalysisStep.callingLLM,
        imageBase64: base64,
      );

      // Step 2: Call LLM
      final provider = await _createProvider();
      final result = await provider.analyzeRemote(imageBase64: base64);

      state = state.copyWith(step: AnalysisStep.matchingDatabase, result: result);

      // Step 3: Match against local database
      final matches = await _matchAgainstDb(result);
      state = state.copyWith(
        step: AnalysisStep.complete,
        matches: matches,
      );
    } catch (e) {
      state = state.copyWith(
        step: AnalysisStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  void selectBrand(int brandId) {
    state = state.copyWith(selectedBrandId: brandId);
  }

  void selectModel(int modelId) {
    state = state.copyWith(selectedModelId: modelId);
  }

  void reset() {
    state = const AnalysisState();
  }

  Future<ApiEngine> _createProvider() async {
    final storage = const FlutterSecureStorage();
    final providerName =
        await storage.read(key: AppConstants.keySelectedProvider) ?? 'openAI';

    final providerEnum = AIProviderExtension.fromStored(providerName);
    switch (providerEnum) {
      case AIProvider.openAI:
        return OpenAIProvider(storage: storage);
      case AIProvider.anthropic:
        return AnthropicProvider(storage: storage);
      case AIProvider.gemini:
        return GeminiProvider(storage: storage);
      case AIProvider.ollama:
        return OllamaProvider(storage: storage);
      case AIProvider.custom:
        return CustomProvider(storage: storage);
      case AIProvider.deepSeek:
        return DeepSeekProvider(storage: storage);
    }
  }

  Future<List<({String modelName, double score})>> _matchAgainstDb(
      AnalysisResult result) async {
    final db = AppDatabase();
    final matches = <({String modelName, double score})>[];

    try {
      final brandResults = await db.searchBrands(result.detectedBrand);
      if (brandResults.isNotEmpty) {
        for (final brand in brandResults.take(5)) {
          final models = await db.getModelsByBrand(brand.id);
          for (final model in models.take(10)) {
            matches.add((
              modelName: '${brand.name} ${model.name}',
              score: 0.85, // Placeholder score
            ));
          }
        }
      }
    } catch (_) {
      // DB not populated yet
    }

    return matches;
  }
}

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  return AnalysisNotifier();
});
