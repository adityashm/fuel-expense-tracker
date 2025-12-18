import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  static Future<File?> compressImage(File imageFile) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        return imageFile; // Return original if compression fails
      }

      return File(result.path);
    } catch (e) {
      debugPrint('Image compression error: $e');
      return imageFile; // Return original if error
    }
  }

  static Future<int> getImageSize(File imageFile) async {
    return imageFile.length();
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<bool> isImageTooLarge(
    File imageFile, {
    int maxSizeKB = 500,
  }) async {
    final size = await getImageSize(imageFile);
    return size > (maxSizeKB * 1024);
  }
}
