/// App-wide constants for IRrecon.
class AppConstants {
  AppConstants._();

  // ── App Info ──
  static const String appName = 'IRrecon';
  static const String appVersion = '1.0.0';

  // ── IRDB ──
  static const String irdbUrl =
      'https://github.com/Lucaslhm/Flipper-IRDB/archive/refs/heads/main.zip';
  static const String irdbLocalDir = 'irdb_files';
  static const String indexFileName = 'irdb_index.json';
  static const int irdbDownloadTimeoutMs = 120000;

  // ── Image ──
  static const int maxImageDimension = 1024;
  static const int jpegQuality = 85;

  // ── Fuzzy Matching ──
  static const double matchThreshold = 0.6;
  static const double highMatchThreshold = 0.85;

  // ── Remote Layout ──
  static const double buttonSize = 56.0;
  static const double smallButtonSize = 44.0;
  static const double buttonSpacing = 8.0;

  // ── API ──
  static const String openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const String anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
  static const String geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Storage Keys ──
  static const String keyOpenAiKey = 'openai_api_key';
  static const String keyAnthropicKey = 'anthropic_api_key';
  static const String keyGeminiKey = 'gemini_api_key';
  static const String keyOllamaUrl = 'ollama_url';
  static const String keySelectedProvider = 'selected_provider';
  static const String keyCustomEndpoint = 'custom_api_endpoint';
  static const String keyCustomHeaders = 'custom_api_headers';
  static const String keyCustomBodyTemplate = 'custom_api_body_template';
  static const String keyDeepSeekKey = 'deepseek_api_key';
  static const String keyDbVersion = 'db_version';
  static const String keyDbLastUpdated = 'db_last_updated';
}
