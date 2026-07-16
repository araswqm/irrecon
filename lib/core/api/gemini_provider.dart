import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../../data/models/analysis_result.dart';
import 'api_engine.dart';

/// Google Gemini Pro Vision provider.
class GeminiProvider implements ApiEngine {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _cachedKey;
  String? _cachedModel;

  GeminiProvider({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  AIProvider get provider => AIProvider.gemini;

  Future<String> _getApiKey() async {
    _cachedKey ??= await _storage.read(key: AppConstants.keyGeminiKey);
    if (_cachedKey == null || _cachedKey!.isEmpty) {
      throw Exception('Gemini API key not configured');
    }
    return _cachedKey!;
  }

  Future<String> _getModel() async {
    _cachedModel ??= await _storage.read(key: AppConstants.keyGeminiModel);
    return _cachedModel ?? 'gemini-2.0-flash';
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

    final modelName = await _getModel();
    final url = '${AppConstants.geminiEndpoint}/$modelName:generateContent?key=$apiKey';

    final response = await _dio.post(
      url,
      options: Options(headers: {
        'Content-Type': 'application/json',
      }),
      data: {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': imageBase64,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': 1024,
        },
      },
    );

    final text = response.data['candidates']?[0]?['content']?['parts']?[0]
        ?['text'] as String?;
    if (text == null) {
      throw Exception('Invalid response from Gemini');
    }

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (e) {
      throw Exception('Failed to parse Gemini response: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final apiKey = await _getApiKey();
      final modelName = await _getModel();
      final url =
          '${AppConstants.geminiEndpoint}/$modelName:generateContent?key=$apiKey';
      final response = await _dio.post(
        url,
        options: Options(headers: {
          'Content-Type': 'application/json',
        }),
        data: {
          'contents': [
            {
              'parts': [
                {'text': 'Respond with "ok"'},
              ],
            },
          ],
          'generationConfig': {
            'maxOutputTokens': 10,
          },
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
