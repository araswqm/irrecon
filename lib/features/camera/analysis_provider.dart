import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_engine.dart';
import '../../core/api/openai_provider.dart';
import '../../core/api/anthropic_provider.dart';
import '../../core/api/gemini_provider.dart';
import '../../core/api/ollama_provider.dart';
import '../../core/api/custom_provider.dart';
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
      String message = e.toString();
      if (e is DioException) {
        message = _formatDioError(e);
      }
      state = state.copyWith(
        step: AnalysisStep.error,
        errorMessage: message,
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

  /// Format a DioException with its response body so users see the real API error.
  String _formatDioError(DioException e) {
    final buffer = StringBuffer()
      ..write('DioException [${e.type.name}]');

    if (e.response != null) {
      final resp = e.response!;
      buffer.write(' | HTTP ${resp.statusCode}');
      if (resp.statusMessage != null) {
        buffer.write(' ${resp.statusMessage}');
      }
      // Extract meaningful body — try JSON first, fall back to raw string
      if (resp.data != null) {
        buffer.write('\n\nResponse body:');
        if (resp.data is Map || resp.data is List) {
          buffer.write('\n${_compactJson(resp.data)}');
        } else {
          final body = resp.data.toString();
          // Truncate very long responses
          buffer.write('\n${body.length > 2000 ? '${body.substring(0, 2000)}…' : body}');
        }
      }
    } else {
      buffer.write(' | ${e.message}');
    }

    return buffer.toString();
  }

  /// Compact one-line JSON for readability in error messages.
  String _compactJson(dynamic data) {
    try {
      // Pretty-print with 2-space indent but cap depth
      final encoder = data is List
          ? const JsonEncoder.withIndent('  ')
          : const JsonEncoder.withIndent('  ');
      final pretty = encoder.convert(data);
      // Keep at most 3000 chars of pretty-printed JSON
      return pretty.length > 3000 ? '${pretty.substring(0, 3000)}\n…' : pretty;
    } catch (_) {
      return data.toString();
    }
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
