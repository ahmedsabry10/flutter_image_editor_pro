import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../controllers/editor_controller.dart';
import '../filters/filter_preset.dart';
import '../models/editor_config.dart';
import '../models/editor_theme.dart';
import '../models/export_options.dart';
import '../models/sticker_pack.dart';
import 'crop_overlay.dart';
import 'drawing_canvas.dart';
import 'editor_toolbar.dart';
import 'filter_preview_strip.dart';
import 'sticker_layer.dart';
import 'text_overlay.dart';

/// The main image editor widget.
/// Embed this anywhere in your app, or use [ImageEditorPro.open] for a full-screen page.
class ImageEditorWidget extends StatefulWidget {
  /// The image to edit. Accepts [File], [Uint8List], or [ImageProvider].
  final dynamic image;

  /// Optional external controller. If null, an internal one is created.
  final EditorController? controller;

  /// Editor configuration — which tools to enable, filters, stickers, etc.
  final EditorConfig config;

  /// Visual theme. Defaults to [EditorTheme.dark()].
  final EditorTheme? theme;

  /// Called when the user taps "Save". Receives the exported image bytes.
  final void Function(EditorResult result)? onExport;

  /// Called when the user taps "Close" or the back button.
  final VoidCallback? onClose;

  /// Called whenever the active tool changes.
  final void Function(EditorTool tool)? onToolChanged;

  /// Called after undo/redo changes the history state.
  final void Function(bool canUndo, bool canRedo)? onUndoStateChanged;

  const ImageEditorWidget({
    super.key,
    required this.image,
    this.controller,
    this.config = const EditorConfig(),
    this.theme,
    this.onExport,
    this.onClose,
    this.onToolChanged,
    this.onUndoStateChanged,
  });

  @override
  State<ImageEditorWidget> createState() => _ImageEditorWidgetState();
}

class _ImageEditorWidgetState extends State<ImageEditorWidget> {
  late EditorController _ctrl;
  late EditorTheme _theme;
  ui.Image? _thumbnail;
  ImageProvider? _imageProvider;
  bool _loading = true;
  bool _exporting = false;

  // Crop state
  Rect? _cropRect;

  // Adjust panel values (local — committed on drag end)
  late AdjustValues _localAdjust;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? EditorController();
    _ctrl.initHistory(widget.config.maxUndoSteps);
    _theme = widget.theme ?? EditorTheme.dark();
    _localAdjust = _ctrl.adjustValues;
    _ctrl.addListener(_onControllerChange);
    _loadImage();
  }

  void _onControllerChange() {
    widget.onToolChanged?.call(_ctrl.activeTool);
    widget.onUndoStateChanged?.call(_ctrl.canUndo, _ctrl.canRedo);
  }

  Future<void> _loadImage() async {
    setState(() => _loading = true);
    final img = widget.image;
    if (img is Uint8List) {
      _imageProvider = MemoryImage(img);
      _thumbnail = await _decodeUiImage(img);
    } else if (img is String) {
      _imageProvider = NetworkImage(img);
    } else if (img is ImageProvider) {
      _imageProvider = img;
    } else {
      // File
      try {
        final bytes = await (img as dynamic).readAsBytes() as Uint8List;
        _imageProvider = MemoryImage(bytes);
        _thumbnail = await _decodeUiImage(bytes);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<ui.Image?> _decodeUiImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary = _ctrl.exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final opts = widget.config.exportOptions;
      final image = await boundary.toImage(pixelRatio: opts.pixelRatio);
      final format = opts.format == ExportFormat.png
          ? ui.ImageByteFormat.png
          : ui.ImageByteFormat.rawRgba;
      final byteData = await image.toByteData(format: format);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final result = EditorResult(
        bytes: bytes,
        width: image.width,
        height: image.height,
        format: opts.format,
      );
      widget.onExport?.call(result);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: _theme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: _theme.activeToolColor),
        ),
      );
    }

    return Container(
      color: _theme.backgroundColor,
      child: Column(
        children: [
          // ── Top toolbar ──────────────────────────────────────────────
          EditorToolbar(
            controller: _ctrl,
            config: widget.config,
            theme: _theme,
            onExport: _export,
            onClose: widget.onClose ?? () => Navigator.maybePop(context),
          ),

          // ── Canvas ───────────────────────────────────────────────────
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Image + filter + drawing layers wrapped in RepaintBoundary
                RepaintBoundary(
                  key: _ctrl.exportKey,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => Stack(
                      children: [
                        // Image with filter
                        _buildFilteredImage(),
                        // Drawing layer
                        if (widget.config.enableDrawing)
                          LayoutBuilder(
                            builder: (ctx, constraints) => DrawingCanvas(
                              controller: _ctrl,
                              size: Size(constraints.maxWidth,
                                  constraints.maxHeight),
                            ),
                          ),
                        // Text layers
                        if (widget.config.enableText)
                          TextOverlayLayer(
                            controller: _ctrl,
                            theme: _theme,
                            onTap: _onTextLayerTap,
                          ),
                        // Sticker layers
                        if (widget.config.enableStickers)
                          StickerLayerWidget(
                            controller: _ctrl,
                            theme: _theme,
                          ),
                      ],
                    ),
                  ),
                ),

                // Crop overlay (on top, outside RepaintBoundary)
                if (widget.config.enableCrop &&
                    _ctrl.activeTool == EditorTool.crop)
                  LayoutBuilder(
                    builder: (ctx, constraints) => CropOverlay(
                      imageSize: Size(
                          constraints.maxWidth, constraints.maxHeight),
                      ratios: widget.config.cropAspectRatios ??
                          CropAspectRatio.defaultRatios,
                      onCropChanged: (r) => setState(() => _cropRect = r),
                    ),
                  ),

                // Export loading indicator
                if (_exporting)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: _theme.activeToolColor),
                          const SizedBox(height: 12),
                          Text('Saving...',
                              style: TextStyle(color: _theme.textColor)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tool-specific panel ──────────────────────────────────────
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => _buildToolPanel(),
          ),

          // ── Bottom tab bar ───────────────────────────────────────────
          EditorBottomBar(
            controller: _ctrl,
            config: widget.config,
            theme: _theme,
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredImage() {
    if (_imageProvider == null) {
      return Container(color: Colors.grey.shade900);
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final adjust = _ctrl.adjustValues;
        // Build combined color matrix: filter × adjust
        final matrix = _combineMatrices(
          _ctrl.filter.matrix,
          _buildAdjustMatrix(adjust),
        );
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: Image(
            image: _imageProvider!,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  /// Multiply two 4×5 color matrices.
  List<double> _combineMatrices(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        if (col < 4) {
          result[row * 5 + col] = a[row * 5 + 0] * b[0 * 5 + col] +
              a[row * 5 + 1] * b[1 * 5 + col] +
              a[row * 5 + 2] * b[2 * 5 + col] +
              a[row * 5 + 3] * b[3 * 5 + col];
        } else {
          // Offset column
          result[row * 5 + 4] = a[row * 5 + 0] * b[0 * 5 + 4] +
              a[row * 5 + 1] * b[1 * 5 + 4] +
              a[row * 5 + 2] * b[2 * 5 + 4] +
              a[row * 5 + 3] * b[3 * 5 + 4] +
              a[row * 5 + 4];
        }
      }
    }
    return result;
  }

  /// Build adjust color matrix from [AdjustValues].
  List<double> _buildAdjustMatrix(AdjustValues v) {
    // Brightness: add offset
    final b = v.brightness * 100;
    // Contrast: scale around 128
    final c = v.contrast + 1.0; // 0..2
    final ct = 128 * (1 - c);
    // Saturation
    final s = v.saturation + 1.0;
    final sr = (1 - s) * 0.299;
    final sg = (1 - s) * 0.587;
    final sb = (1 - s) * 0.114;
    // Warmth: shift red/blue
    final w = v.warmth * 30;

    return [
      c * (sr + s), c * sg, c * sb, 0, b + ct + w,
      c * sr, c * (sg + s), c * sb, 0, b + ct,
      c * sr, c * sg, c * (sb + s), 0, b + ct - w,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _buildToolPanel() {
    switch (_ctrl.activeTool) {
      case EditorTool.filters:
        return _buildFiltersPanel();
      case EditorTool.adjust:
        return _buildAdjustPanel();
      case EditorTool.drawing:
        return _buildDrawingPanel();
      case EditorTool.text:
        return _buildTextPanel();
      case EditorTool.stickers:
        return _buildStickersPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Filters panel ────────────────────────────────────────────────────────
  Widget _buildFiltersPanel() {
    final filters = widget.config.customFilters != null
        ? (widget.config.prependCustomFilters
            ? [...widget.config.customFilters!, ...FilterPreset.builtIn]
            : [...FilterPreset.builtIn, ...widget.config.customFilters!])
        : FilterPreset.builtIn;

    return Container(
      color: _theme.toolbarColor,
      child: FilterPreviewStrip(
        thumbnail: _thumbnail,
        filters: filters,
        selected: _ctrl.filter,
        theme: _theme,
        onSelect: _ctrl.setFilter,
      ),
    );
  }

  // ── Adjust panel ─────────────────────────────────────────────────────────
  Widget _buildAdjustPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _adjustSlider('Brightness', Icons.brightness_6,
              _localAdjust.brightness,
              (v) => _onAdjustChange(_localAdjust.copyWith(brightness: v))),
          _adjustSlider('Contrast', Icons.contrast, _localAdjust.contrast,
              (v) => _onAdjustChange(_localAdjust.copyWith(contrast: v))),
          _adjustSlider('Saturation', Icons.color_lens,
              _localAdjust.saturation,
              (v) => _onAdjustChange(_localAdjust.copyWith(saturation: v))),
          _adjustSlider('Warmth', Icons.wb_sunny, _localAdjust.warmth,
              (v) => _onAdjustChange(_localAdjust.copyWith(warmth: v))),
        ],
      ),
    );
  }

  Widget _adjustSlider(String label, IconData icon, double value,
      void Function(double) onChange) {
    return Row(
      children: [
        Icon(icon, color: _theme.iconColor, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label,
              style: TextStyle(color: _theme.textColor, fontSize: 11)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _theme.sliderActiveColor,
              inactiveTrackColor: _theme.sliderInactiveColor,
              thumbColor: _theme.activeToolColor,
              overlayColor: _theme.activeToolColor.withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: -1.0,
              max: 1.0,
              onChanged: onChange,
              onChangeEnd: (_) => _ctrl.commitAdjust(),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value >= 0
                ? '+${(value * 100).round()}'
                : '${(value * 100).round()}',
            style: TextStyle(
                color: _theme.iconColor, fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _onAdjustChange(AdjustValues v) {
    setState(() => _localAdjust = v);
    _ctrl.setAdjust(v);
  }

  // ── Drawing panel ────────────────────────────────────────────────────────
  Widget _buildDrawingPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color picker
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Eraser toggle
                GestureDetector(
                  onTap: () => _ctrl.setEraser(!_ctrl.isEraser),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _ctrl.isEraser
                            ? _theme.activeToolColor
                            : Colors.white24,
                        width: 2,
                      ),
                      color: _theme.toolbarColor,
                    ),
                    child: Icon(Icons.auto_fix_normal,
                        color: _ctrl.isEraser
                            ? _theme.activeToolColor
                            : _theme.iconColor,
                        size: 16),
                  ),
                ),
                ...widget.config.brushColors
                    .map((c) => GestureDetector(
                          onTap: () {
                            _ctrl.setEraser(false);
                            _ctrl.setBrushColor(c);
                          },
                          child: AnimatedBuilder(
                            animation: _ctrl,
                            builder: (_, __) => Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: !_ctrl.isEraser &&
                                          _ctrl.brushColor == c
                                      ? _theme.activeToolColor
                                      : Colors.white24,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Brush size
          Row(
            children: [
              Icon(Icons.brush, color: _theme.iconColor, size: 16),
              Expanded(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Slider(
                    value: _ctrl.brushSize,
                    min: 2,
                    max: 40,
                    activeColor: _theme.sliderActiveColor,
                    inactiveColor: _theme.sliderInactiveColor,
                    onChanged: _ctrl.setBrushSize,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Text(
                  '${_ctrl.brushSize.round()}px',
                  style:
                      TextStyle(color: _theme.iconColor, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Text panel ───────────────────────────────────────────────────────────
  Widget _buildTextPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tap the canvas to place text, or add a new layer.',
              style: TextStyle(color: _theme.iconColor, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: _openTextDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _theme.activeToolColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.add, color: _theme.exportButtonTextColor, size: 16),
                  const SizedBox(width: 4),
                  Text('Add Text',
                      style: TextStyle(
                          color: _theme.exportButtonTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTextDialog([TextLayer? existing]) async {
    final result = await showDialog<TextLayer>(
      context: context,
      builder: (_) => TextEditorDialog(existing: existing, theme: _theme),
    );
    if (result == null) return;
    if (existing != null) {
      _ctrl.updateTextLayer(result);
    } else {
      _ctrl.addTextLayer(result);
    }
  }

  void _onTextLayerTap(TextLayer layer) {
    _openTextDialog(layer);
  }

  // ── Stickers panel ───────────────────────────────────────────────────────
  Widget _buildStickersPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Add stickers to your image.',
              style: TextStyle(color: _theme.iconColor, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: _openStickerPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _theme.activeToolColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_emotions,
                      color: _theme.exportButtonTextColor, size: 16),
                  const SizedBox(width: 4),
                  Text('Stickers',
                      style: TextStyle(
                          color: _theme.exportButtonTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerPickerSheet(
        packs: widget.config.stickerPacks,
        theme: _theme,
        onPick: (widget) {
          _ctrl.addSticker(StickerLayer(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            widget: widget,
          ));
        },
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChange);
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }
}
