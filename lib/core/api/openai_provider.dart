import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../../data/models/analysis_result.dart';
import 'api_engine.dart';

/// OpenAI GPT-4o vision provider.
class OpenAIProvider implements ApiEngine {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _cachedKey;

  OpenAIProvider({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  AIProvider get provider => AIProvider.openAI;

  Future<String> _getApiKey() async {
    _cachedKey ??= await _storage.read(key: AppConstants.keyOpenAiKey);
    if (_cachedKey == null || _cachedKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }
    return _cachedKey!;
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
      AppConstants.openAiEndpoint,
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$imageBase64',
                  'detail': 'high',
                },
              },
            ],
          },
        ],
        'max_tokens': 1024,
      },
    );

    final content =
        response.data['choices']?[0]?['message']?['content'] as String?;
    if (content == null) {
      throw Exception('Invalid response from OpenAI: no content');
    }

    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (e) {
      throw Exception('Failed to parse OpenAI response: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final apiKey = await _getApiKey();
      final response = await _dio.post(
        AppConstants.openAiEndpoint,
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': 'Respond with "ok".'},
          ],
          'max_tokens': 10,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
