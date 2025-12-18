import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Image Preprocessing Service for V2.5
/// Enhances receipt images for better OCR accuracy
/// All processing is done on-device
class ImagePreprocessingService {
  factory ImagePreprocessingService() => _instance;
  ImagePreprocessingService._internal();
  static final ImagePreprocessingService _instance =
      ImagePreprocessingService._internal();

  static ImagePreprocessingService get instance => _instance;

  /// Main entry point: Preprocess receipt image for OCR
  Future<Uint8List?> preprocessReceipt(File imageFile) async {
    try {
      debugPrint('ImagePreprocessing: Starting preprocessing...');

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('ImagePreprocessing: Failed to decode image');
        return null;
      }

      // Run preprocessing in isolate to avoid blocking UI
      final processedImage = await compute(_processReceiptImage, image);

      if (processedImage == null) {
        return bytes; // Return original if processing fails
      }

      // Encode as high-quality JPEG
      final processedBytes = img.encodeJpg(processedImage, quality: 90);

      debugPrint('ImagePreprocessing: Completed successfully');
      return Uint8List.fromList(processedBytes);
    } catch (e) {
      debugPrint('ImagePreprocessing: Error - $e');
      return null;
    }
  }

  /// Static method for compute isolate
  static img.Image? _processReceiptImage(img.Image image) {
    try {
      img.Image processed = image;

      // Step 1: Auto-orient based on EXIF data (already handled by image package)

      // Step 2: Resize if too large (max 2000px on longest side)
      processed = _resizeIfNeeded(processed, maxDimension: 2000);

      // Step 3: Convert to grayscale for better text recognition
      processed = img.grayscale(processed);

      // Step 4: Increase contrast to make text stand out
      processed = _adjustContrast(processed, 1.4);

      // Step 5: Apply adaptive sharpening
      processed = _sharpen(processed);

      // Step 6: Apply slight denoise
      processed = _denoise(processed);

      return processed;
    } catch (e) {
      return null;
    }
  }

  /// Resize image if it exceeds max dimension
  static img.Image _resizeIfNeeded(img.Image image,
      {required int maxDimension,}) {
    final width = image.width;
    final height = image.height;

    if (width <= maxDimension && height <= maxDimension) {
      return image;
    }

    double scale;
    if (width > height) {
      scale = maxDimension / width;
    } else {
      scale = maxDimension / height;
    }

    final newWidth = (width * scale).round();
    final newHeight = (height * scale).round();

    return img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Adjust contrast using linear transformation
  static img.Image _adjustContrast(img.Image image, double factor) {
    return img.adjustColor(image, contrast: factor);
  }

  /// Apply sharpening filter for text clarity
  static img.Image _sharpen(img.Image image) {
    // Unsharp mask sharpening kernel
    final kernel = [
      0,
      -1,
      0,
      -1,
      5,
      -1,
      0,
      -1,
      0,
    ];

    return img.convolution(image, filter: kernel, div: 1, offset: 0);
  }

  /// Apply simple denoise
  static img.Image _denoise(img.Image image) {
    // Use a slight Gaussian blur then sharpen for denoising effect
    // This is a simplified version - works well for receipt text
    return img.gaussianBlur(image, radius: 1);
  }

  /// Detect and correct skew (rotation) in receipt image
  Future<Uint8List?> deskewReceipt(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Simple deskew: Detect edges and rotate to align
      // This is a simplified implementation
      final processed = await compute(_deskewImage, image);

      if (processed == null) return bytes;

      return Uint8List.fromList(img.encodeJpg(processed, quality: 90));
    } catch (e) {
      debugPrint('ImagePreprocessing: Deskew error - $e');
      return null;
    }
  }

  static img.Image? _deskewImage(img.Image image) {
    // Simplified deskew - in production, use edge detection
    // For now, just return the image as-is
    // A full implementation would:
    // 1. Detect edges using Sobel filter
    // 2. Find dominant lines using Hough transform
    // 3. Calculate rotation angle
    // 4. Rotate image to correct
    return image;
  }

  /// Crop receipt from background
  Future<Uint8List?> autoCropReceipt(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final cropped = await compute(_autoCrop, image);

      if (cropped == null) return bytes;

      return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
    } catch (e) {
      debugPrint('ImagePreprocessing: Auto crop error - $e');
      return null;
    }
  }

  static img.Image? _autoCrop(img.Image image) {
    // Convert to grayscale for edge detection
    final gray = img.grayscale(image);

    // Find bounding box of content
    int minX = image.width;
    int maxX = 0;
    int minY = image.height;
    int maxY = 0;

    // Threshold for "content" vs "background"
    const threshold = 240; // Assume light background

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final luminance = img.getLuminance(pixel);

        if (luminance < threshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    // Add padding
    const padding = 20;
    minX = (minX - padding).clamp(0, image.width);
    maxX = (maxX + padding).clamp(0, image.width);
    minY = (minY - padding).clamp(0, image.height);
    maxY = (maxY + padding).clamp(0, image.height);

    // Ensure valid dimensions
    if (maxX <= minX || maxY <= minY) {
      return image; // Return original if crop fails
    }

    return img.copyCrop(
      image,
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Apply binarization (black & white) for difficult receipts
  Future<Uint8List?> binarizeReceipt(File imageFile,
      {int threshold = 128,}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final binary = await compute(
        (img.Image img) => _binarize(img, threshold),
        image,
      );

      return Uint8List.fromList(img.encodeJpg(binary, quality: 90));
    } catch (e) {
      debugPrint('ImagePreprocessing: Binarize error - $e');
      return null;
    }
  }

  static img.Image _binarize(img.Image image, int threshold) {
    final gray = img.grayscale(image);
    final result = img.Image(width: gray.width, height: gray.height);

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final luminance = img.getLuminance(pixel);

        if (luminance < threshold) {
          result.setPixel(x, y, img.ColorRgb8(0, 0, 0)); // Black
        } else {
          result.setPixel(x, y, img.ColorRgb8(255, 255, 255)); // White
        }
      }
    }

    return result;
  }

  /// Get preprocessing quality metrics
  ImageQualityMetrics analyzeImageQuality(img.Image image) {
    // Calculate brightness
    double totalBrightness = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y += 10) {
      // Sample every 10th pixel
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        totalBrightness += img.getLuminance(pixel);
        pixelCount++;
      }
    }

    final avgBrightness = totalBrightness / pixelCount;

    // Calculate sharpness (simple variance-based)
    double variance = 0;
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final lum = img.getLuminance(pixel);
        variance += (lum - avgBrightness) * (lum - avgBrightness);
      }
    }
    variance /= pixelCount;

    return ImageQualityMetrics(
      brightness: avgBrightness,
      contrast: variance / 255,
      width: image.width,
      height: image.height,
      isGoodForOCR: avgBrightness > 50 && avgBrightness < 220 && variance > 20,
    );
  }

  /// Get preprocessing recommendations based on image analysis
  List<PreprocessingRecommendation> getRecommendations(
      ImageQualityMetrics metrics,) {
    final recommendations = <PreprocessingRecommendation>[];

    if (metrics.brightness < 80) {
      recommendations.add(
        PreprocessingRecommendation(
          type: PreprocessingType.brightness,
          message: 'Image is too dark. Consider using better lighting.',
          severity: RecommendationSeverity.warning,
        ),
      );
    } else if (metrics.brightness > 200) {
      recommendations.add(
        PreprocessingRecommendation(
          type: PreprocessingType.brightness,
          message: 'Image is overexposed. Reduce lighting or flash.',
          severity: RecommendationSeverity.warning,
        ),
      );
    }

    if (metrics.contrast < 0.1) {
      recommendations.add(
        PreprocessingRecommendation(
          type: PreprocessingType.contrast,
          message: 'Low contrast. Text may be difficult to read.',
          severity: RecommendationSeverity.warning,
        ),
      );
    }

    if (metrics.width < 800 || metrics.height < 800) {
      recommendations.add(
        PreprocessingRecommendation(
          type: PreprocessingType.resolution,
          message: 'Low resolution. Move closer to the receipt.',
          severity: RecommendationSeverity.error,
        ),
      );
    }

    return recommendations;
  }
}

/// Image quality metrics
class ImageQualityMetrics {
  ImageQualityMetrics({
    required this.brightness,
    required this.contrast,
    required this.width,
    required this.height,
    required this.isGoodForOCR,
  });
  final double brightness;
  final double contrast;
  final int width;
  final int height;
  final bool isGoodForOCR;

  String get qualityLabel {
    if (isGoodForOCR) return 'Good';
    if (brightness < 50 || brightness > 220) return 'Poor (Lighting)';
    if (contrast < 0.1) return 'Poor (Contrast)';
    return 'Fair';
  }
}

/// Preprocessing recommendation
class PreprocessingRecommendation {
  PreprocessingRecommendation({
    required this.type,
    required this.message,
    required this.severity,
  });
  final PreprocessingType type;
  final String message;
  final RecommendationSeverity severity;
}

enum PreprocessingType {
  brightness,
  contrast,
  sharpness,
  resolution,
  rotation,
}

enum RecommendationSeverity {
  info,
  warning,
  error,
}
