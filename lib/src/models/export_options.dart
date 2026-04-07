import 'dart:typed_data';
import 'dart:io';

enum ExportFormat { png, jpeg }

/// Options used when exporting the final image.
class ExportOptions {
  /// Output format. Default: png
  final ExportFormat format;

  /// JPEG quality 0.0–1.0. Ignored for PNG. Default: 0.92
  final double jpegQuality;

  /// Max width in pixels. null = original width.
  final int? maxWidth;

  /// Max height in pixels. null = original height.
  final int? maxHeight;

  /// Pixel density multiplier. Default: 1.0
  final double pixelRatio;

  const ExportOptions({
    this.format = ExportFormat.png,
    this.jpegQuality = 0.92,
    this.maxWidth,
    this.maxHeight,
    this.pixelRatio = 1.0,
  });
}

/// Result returned after export.
class EditorResult {
  /// Raw bytes of the exported image.
  final Uint8List bytes;

  /// Saved file, if [savePath] was provided.
  final File? file;

  /// Width of the exported image in pixels.
  final int width;

  /// Height of the exported image in pixels.
  final int height;

  /// Format used for export.
  final ExportFormat format;

  const EditorResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    this.file,
  });
}
