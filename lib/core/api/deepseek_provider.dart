import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../../data/models/analysis_result.dart';
import 'api_engine.dart';

/// DeepSeek AI provider using their OpenAI-compatible API.
///
/// Uses the DeepSeek chat completions endpoint with vision support.
/// Endpoint: https://api.deepseek.com/v1/chat/completions
/// Model: deepseek-chat
class DeepSeekProvider implements ApiEngine {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  DeepSeekProvider({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  AIProvider get provider => AIProvider.deepSeek;

  Future<String> _getApiKey() async {
    final key = await _storage.read(key: AppConstants.keyDeepSeekKey);
    if (key == null || key.isEmpty) {
      throw Exception('DeepSeek API key not configured');
    }
    return key;
  }

  @override
  Future<AnalysisResult> analyzeRemote({
    required String imageBase64,
    String? brandHint,
    String? modelHint,
  }) async {
    final apiKey = await _getApiKey();

    var prompt = analysisPromptTemplate;
    if (brandHint != null) prompt += '\nBrand hint: $brandHint.';
    if (modelHint != null) prompt += '\nModel hint: $modelHint.';

    final dataUri = 'data:image/jpeg;base64,$imageBase64';

    final response = await _dio.post(
      'https://api.deepseek.com/v1/chat/completions',
      options: Options(headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      }),
      data: {
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': dataUri},
              },
            ],
          },
        ],
        'max_tokens': 1024,
      },
    );

    final responseData = response.data as Map<String, dynamic>;
    final choices = responseData['choices'] as List<dynamic>;
    if (choices.isEmpty) {
      throw Exception('DeepSeek returned no choices');
    }

    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
    final content = message['content'] as String;

    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (e) {
      throw Exception('Failed to parse DeepSeek response: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final apiKey = await _getApiKey();
      final response = await _dio.post(
        'https://api.deepseek.com/v1/chat/completions',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        }),
        data: {
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'user', 'content': 'Respond with just the word "ok".'},
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
