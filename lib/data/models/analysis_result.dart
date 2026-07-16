/// Result returned by an LLM after analyzing a remote control image.
class AnalysisResult {
  /// Detected brand name from the image (e.g. "Samsung").
  final String detectedBrand;

  /// Detected model hint (optional, may be partial).
  final String? detectedModel;

  /// Device type classification (e.g. "tv", "ac", "soundbar").
  final String deviceType;

  /// List of key names the LLM identified from the image.
  final List<String> identifiedKeys;

  /// Confidence score from the LLM (0.0 - 1.0).
  final double confidence;

  /// Raw JSON response from the LLM for debugging.
  final String? rawResponse;

  const AnalysisResult({
    required this.detectedBrand,
    this.detectedModel,
    required this.deviceType,
    this.identifiedKeys = const [],
    this.confidence = 0.0,
    this.rawResponse,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      detectedBrand: json['brand'] as String? ?? 'Unknown',
      detectedModel: json['model'] as String?,
      deviceType: json['device_type'] as String? ?? 'tv',
      identifiedKeys: (json['keys'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rawResponse: json.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'brand': detectedBrand,
        'model': detectedModel,
        'device_type': deviceType,
        'keys': identifiedKeys,
        'confidence': confidence,
      };

  @override
  String toString() =>
      'AnalysisResult(brand: $detectedBrand, deviceType: $deviceType, '
      'confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}
