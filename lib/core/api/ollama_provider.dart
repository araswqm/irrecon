import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../../data/models/analysis_result.dart';
import 'api_engine.dart';

/// Local Ollama LLM provider.
class OllamaProvider implements ApiEngine {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _cachedUrl;

  OllamaProvider({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  AIProvider get provider => AIProvider.ollama;

  Future<String> _getUrl() async {
    _cachedUrl ??= await _storage.read(key: AppConstants.keyOllamaUrl);
    return _cachedUrl ?? 'http://localhost:11434';
  }

  @override
  Future<AnalysisResult> analyzeRemote({
    required String imageBase64,
    String? brandHint,
    String? modelHint,
  }) async {
    final baseUrl = await _getUrl();
    final url = '$baseUrl/api/generate';

    var prompt = analysisPromptTemplate;
    if (brandHint != null) {
      prompt += '\nThe user selected brand: $brandHint.';
    }
    if (modelHint != null) {
      prompt += '\nThe user selected model: $modelHint.';
    }

    final response = await _dio.post(
      url,
      options: Options(headers: {
        'Content-Type': 'application/json',
      }),
      data: {
        'model': 'llava',
        'prompt': prompt,
        'images': [imageBase64],
        'stream': false,
        'options': {
          'num_predict': 1024,
        },
      },
    );

    final text = response.data['response'] as String?;
    if (text == null) {
      throw Exception('Invalid response from Ollama');
    }

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (e) {
      throw Exception('Failed to parse Ollama response: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final baseUrl = await _getUrl();
      final response = await _dio.get('$baseUrl/api/tags');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
