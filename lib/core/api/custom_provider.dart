import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../../data/models/analysis_result.dart';
import 'api_engine.dart';

/// User-defined custom API provider.
///
/// Allows the user to configure a custom endpoint URL, headers, and
/// request body template with `{{image_base64}}` and `{{prompt}}` placeholders.
class CustomProvider implements ApiEngine {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _cachedEndpoint;
  String? _cachedHeaders;
  String? _cachedBodyTemplate;

  CustomProvider({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  AIProvider get provider => AIProvider.custom;

  Future<String> _getEndpoint() async {
    _cachedEndpoint ??=
        await _storage.read(key: AppConstants.keyCustomEndpoint);
    if (_cachedEndpoint == null || _cachedEndpoint!.isEmpty) {
      throw Exception('Custom API endpoint not configured');
    }
    return _cachedEndpoint!;
  }

  Future<Map<String, String>> _getHeaders() async {
    _cachedHeaders ??=
        await _storage.read(key: AppConstants.keyCustomHeaders);
    if (_cachedHeaders == null || _cachedHeaders!.isEmpty) return {};
    try {
      final decoded = jsonDecode(_cachedHeaders!) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<String> _getBodyTemplate() async {
    _cachedBodyTemplate ??=
        await _storage.read(key: AppConstants.keyCustomBodyTemplate);
    return _cachedBodyTemplate ?? '{"image": "{{image_base64}}", "prompt": "{{prompt}}"}';
  }

  @override
  Future<AnalysisResult> analyzeRemote({
    required String imageBase64,
    String? brandHint,
    String? modelHint,
  }) async {
    final endpoint = await _getEndpoint();
    final headers = await _getHeaders();
    var bodyTemplate = await _getBodyTemplate();

    var prompt = analysisPromptTemplate;
    if (brandHint != null) prompt += '\nBrand hint: $brandHint.';
    if (modelHint != null) prompt += '\nModel hint: $modelHint.';

    // Replace placeholders
    bodyTemplate = bodyTemplate.replaceAll('{{image_base64}}', imageBase64);
    bodyTemplate = bodyTemplate.replaceAll('{{prompt}}', prompt);

    final body = jsonDecode(bodyTemplate);

    final response = await _dio.post(
      endpoint,
      options: Options(headers: {
        'Content-Type': 'application/json',
        ...headers,
      }),
      data: body,
    );

    final responseData = response.data;
    String responseText;

    // Try common response formats
    if (responseData is Map<String, dynamic>) {
      responseText = responseData['response'] as String? ??
          responseData['text'] as String? ??
          responseData['content'] as String? ??
          responseData.toString();
    } else {
      responseText = responseData.toString();
    }

    try {
      final json = jsonDecode(responseText) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (e) {
      throw Exception('Failed to parse custom API response: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final endpoint = await _getEndpoint();
      final response = await _dio.get(
        endpoint,
        options: Options(headers: await _getHeaders()),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
