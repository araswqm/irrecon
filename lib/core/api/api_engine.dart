import '../../data/models/analysis_result.dart';

/// Enum of supported AI providers.
enum AIProvider {
  openAI,
  anthropic,
  gemini,
  ollama,
  deepSeek,
  custom,
}

/// Extension to parse provider from stored string.
extension AIProviderExtension on AIProvider {
  String get storedName => name;

  static AIProvider fromStored(String name) {
    return AIProvider.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AIProvider.openAI,
    );
  }
}

/// Abstract interface for LLM vision-based remote analysis.
abstract class ApiEngine {
  /// Analyze a remote control image and return structured results.
  ///
  /// [imageBase64] is the base64-encoded JPEG image.
  /// [brandHint] is an optional brand name from user selection.
  /// [modelHint] is an optional model name from user selection.
  Future<AnalysisResult> analyzeRemote({
    required String imageBase64,
    String? brandHint,
    String? modelHint,
  });

  /// Test the connection / API key validity.
  Future<bool> testConnection();

  /// Get the provider type.
  AIProvider get provider;
}

/// Prompt template used for all LLM vision calls.
const String analysisPromptTemplate = '''
You are analyzing a photo of a remote control device. Identify the following:

1. **brand**: The manufacturer name (e.g. "Samsung", "LG", "Sony").
2. **model**: The model number if visible (may be partial or absent).
3. **device_type**: The type of device ("tv", "ac", "soundbar", "tv_box", "projector", "fan", "light", or "other").
4. **keys**: List of button labels visible on the remote (e.g. "Power", "Volume Up", "Mute", "1", "2", "3", etc.).
5. **confidence**: A score from 0.0 to 1.0 indicating how confident you are in the identification.

Respond ONLY with valid JSON in this exact format, no other text:
{
  "brand": "string or null",
  "model": "string or null",
  "device_type": "string",
  "keys": ["string", ...],
  "confidence": 0.0-1.0
}
''';
