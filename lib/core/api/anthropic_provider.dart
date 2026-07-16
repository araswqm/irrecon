import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../../data/models/analysis_result.dart';
import 'api_engine.dart';

/// Anthropic Claude vision provider.
class AnthropicProvider implements ApiEngine {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _cachedKey;
  String? _cachedModel;

  AnthropicProvider({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  AIProvider get provider => AIProvider.anthropic;

  Future<String> _getApiKey() async {
    _cachedKey ??= await _storage.read(key: AppConstants.keyAnthropicKey);
    if (_cachedKey == null || _cachedKey!.isEmpty) {
      throw Exception('Anthropic API key not configured');
    }
    return _cachedKey!;
  }

  Future<String> _getModel() async {
    _cachedModel ??= await _storage.read(key: AppConstants.keyAnthropicModel);
    return _cachedModel ?? 'claude-sonnet-5';
  }

  @override
  Future<AnalysisResult> analyzeRemote({
    required String imageBase64,
    String? brandHint,
    String? modelHint,
  }) async {
    final apiKey = await _getApiKey();

    var prompt = analysisPromptTemplate;
    if (brandHint != null) {
      prompt += '\nThe user selected brand: $brandHint.';
    }
    if (modelHint != null) {
      prompt += '\nThe user selected model: $modelHint.';
    }

    final response = await _dio.post(
      AppConstants.anthropicEndpoint,
      options: Options(headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': await _getModel(),
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': imageBase64,
                },
              },
            ],
          },
        ],
      },
    );

    final content = response.data['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw Exception('Invalid response from Anthropic');
    }

    final text = content[0]['text'] as String?;
    if (text == null) {
      throw Exception('Invalid response from Anthropic: no text content');
    }

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (e) {
      throw Exception('Failed to parse Anthropic response: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final apiKey = await _getApiKey();
      final response = await _dio.post(
        AppConstants.anthropicEndpoint,
        options: Options(headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Respond with "ok".'},
          ],
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
