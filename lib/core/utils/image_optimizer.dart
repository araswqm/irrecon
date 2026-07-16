import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../constants.dart';

/// Handles image picking, resizing, and base64 encoding for LLM analysis.
class ImageOptimizer {
  /// Resize an image to max [maxDimension] on the longest side,
  /// then encode to base64 JPEG at the given [quality].
  static Future<String> resizeToBase64({
    required File imageFile,
    int maxDimension = AppConstants.maxImageDimension,
    int quality = AppConstants.jpegQuality,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image file: ${imageFile.path}');
    }

    img.Image resized;
    if (image.width > maxDimension || image.height > maxDimension) {
      resized = img.copyResize(image,
          width: image.width > image.height ? maxDimension : null,
          height: image.height >= image.width ? maxDimension : null);
    } else {
      resized = image;
    }

    final jpegBytes = img.encodeJpg(resized, quality: quality);
    return base64Encode(jpegBytes);
  }

  /// Returns a data URI for use with some LLM APIs.
  static Future<String> toDataUri(File imageFile) async {
    final b64 = await resizeToBase64(imageFile: imageFile);
    return 'data:image/jpeg;base64,$b64';
  }

  /// Get image dimensions without full decoding.
  static Future<({int width, int height})> getDimensions(
      File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image: ${imageFile.path}');
    }
    return (width: image.width, height: image.height);
  }
}
