import 'package:flutter/material.dart';
import '../filters/filter_preset.dart';
import 'sticker_pack.dart';
import 'export_options.dart';

/// All configuration options for the image editor.
class EditorConfig {
  /// Enable crop & rotate tab. Default: true
  final bool enableCrop;

  /// Allowed aspect ratios in crop mode.
  /// If null, shows all built-in ratios (free, 1:1, 4:3, 16:9, 9:16).
  final List<CropAspectRatio>? cropAspectRatios;

  /// Enable filters tab. Default: true
  final bool enableFilters;

  /// Custom filters to show INSTEAD of built-in ones.
  /// If null, built-in filters are used.
  final List<FilterPreset>? customFilters;

  /// Whether to prepend custom filters before built-in ones.
  final bool prependCustomFilters;

  /// Enable adjust tab (brightness, contrast, saturation, warmth). Default: true
  final bool enableAdjust;

  /// Enable drawing/paint tab. Default: true
  final bool enableDrawing;

  /// Colors shown in the drawing color picker.
  final List<Color> brushColors;

  /// Enable text overlay tab. Default: true
  final bool enableText;

  /// Font families available for text overlay.
  final List<String> availableFonts;

  /// Enable stickers tab. Default: true
  final bool enableStickers;

  /// Sticker packs to show in the stickers panel.
  final List<StickerPack> stickerPacks;

  /// Maximum undo steps kept in memory. Default: 20
  final int maxUndoSteps;

  /// Export options (format, quality, max size).
  final ExportOptions exportOptions;

  const EditorConfig({
    this.enableCrop = true,
    this.cropAspectRatios,
    this.enableFilters = true,
    this.customFilters,
    this.prependCustomFilters = false,
    this.enableAdjust = true,
    this.enableDrawing = true,
    this.brushColors = const [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.pink,
    ],
    this.enableText = true,
    this.availableFonts = const ['Roboto', 'serif', 'monospace'],
    this.enableStickers = true,
    this.stickerPacks = const [],
    this.maxUndoSteps = 20,
    this.exportOptions = const ExportOptions(),
  });
}

/// Crop aspect ratio definition.
class CropAspectRatio {
  final String label;

  /// null means free-form
  final double? ratio;

  const CropAspectRatio({required this.label, this.ratio});

  static const free = CropAspectRatio(label: 'Free', ratio: null);
  static const square = CropAspectRatio(label: '1:1', ratio: 1.0);
  static const ratio4x3 = CropAspectRatio(label: '4:3', ratio: 4 / 3);
  static const ratio16x9 = CropAspectRatio(label: '16:9', ratio: 16 / 9);
  static const ratio9x16 = CropAspectRatio(label: '9:16', ratio: 9 / 16);

  static const defaultRatios = [free, square, ratio4x3, ratio16x9, ratio9x16];
}
