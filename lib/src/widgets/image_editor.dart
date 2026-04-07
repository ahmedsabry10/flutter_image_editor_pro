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
class ImageEditorWidget extends StatefulWidget {
  final dynamic image;
  final EditorController? controller;
  final EditorConfig config;
  final EditorTheme? theme;
  final void Function(EditorResult result)? onExport;
  final VoidCallback? onClose;
  final void Function(EditorTool tool)? onToolChanged;
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
  Uint8List? _imageBytes;
  ImageProvider? _imageProvider;
  bool _loading = true;
  bool _exporting = false;

  // Crop state
  Rect? _pendingCropRect;
  Uint8List? _croppedBytes;

  // Adjust local
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
      _imageBytes = img;
      _imageProvider = MemoryImage(img);
      _thumbnail = await _decodeUiImage(img);
    } else if (img is String) {
      _imageProvider = NetworkImage(img);
    } else if (img is ImageProvider) {
      _imageProvider = img;
    } else {
      try {
        final bytes = await (img as dynamic).readAsBytes() as Uint8List;
        _imageBytes = bytes;
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

  // ── Apply crop ────────────────────────────────────────────────────────────
  /// FIX: Actually apply the crop rect to the image bytes.
  Future<void> _applyCrop() async {
    if (_pendingCropRect == null) return;
    final bytes = _croppedBytes ?? _imageBytes;
    if (bytes == null) return;

    setState(() => _loading = true);
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;

      // _pendingCropRect is in widget coordinates — we need to map to image pixels
      final widgetSize = _ctrl.canvasSize;
      if (widgetSize == null || widgetSize.isEmpty) return;

      final scaleX = srcImage.width / widgetSize.width;
      final scaleY = srcImage.height / widgetSize.height;

      final cropX = (_pendingCropRect!.left * scaleX).round().clamp(0, srcImage.width);
      final cropY = (_pendingCropRect!.top * scaleY).round().clamp(0, srcImage.height);
      final cropW = (_pendingCropRect!.width * scaleX).round().clamp(1, srcImage.width - cropX);
      final cropH = (_pendingCropRect!.height * scaleY).round().clamp(1, srcImage.height - cropY);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(cropX.toDouble(), cropY.toDouble(), cropW.toDouble(), cropH.toDouble()),
        Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
        Paint(),
      );
      final pic = recorder.endRecording();
      final cropped = await pic.toImage(cropW, cropH);
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final newBytes = byteData.buffer.asUint8List();
      _croppedBytes = newBytes;
      _imageProvider = MemoryImage(newBytes);
      _thumbnail = await _decodeUiImage(newBytes);
      _pendingCropRect = null;
      _ctrl.setTool(EditorTool.filters);
    } catch (e) {
      debugPrint('Crop error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: _theme.backgroundColor,
        child: Center(child: CircularProgressIndicator(color: _theme.activeToolColor)),
      );
    }

    return Container(
      color: _theme.backgroundColor,
      child: Column(
        children: [
          EditorToolbar(
            controller: _ctrl,
            config: widget.config,
            theme: _theme,
            onExport: _export,
            onClose: widget.onClose ?? () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                RepaintBoundary(
                  key: _ctrl.exportKey,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => Stack(
                      children: [
                        _buildFilteredImage(),
                        if (widget.config.enableDrawing)
                          LayoutBuilder(
                            builder: (ctx, constraints) => DrawingCanvas(
                              controller: _ctrl,
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              // FIX: only active when drawing tool is selected
                              isActive: _ctrl.activeTool == EditorTool.drawing,
                            ),
                          ),
                        if (widget.config.enableText)
                          TextOverlayLayer(
                            controller: _ctrl,
                            theme: _theme,
                            onTap: _onTextLayerTap,
                          ),
                        if (widget.config.enableStickers)
                          StickerLayerWidget(controller: _ctrl, theme: _theme),
                      ],
                    ),
                  ),
                ),
                // FIX: Crop overlay with Apply button
                if (widget.config.enableCrop && _ctrl.activeTool == EditorTool.crop)
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      // Save canvas size for pixel-accurate crop mapping
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _ctrl.canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                      });
                      return CropOverlay(
                        imageSize: Size(constraints.maxWidth, constraints.maxHeight),
                        ratios: widget.config.cropAspectRatios ?? CropAspectRatio.defaultRatios,
                        onCropChanged: (r) => _pendingCropRect = r,
                        onApply: _applyCrop,
                      );
                    },
                  ),
                if (_exporting)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _theme.activeToolColor),
                          const SizedBox(height: 12),
                          Text('Saving...', style: TextStyle(color: _theme.textColor)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => _buildToolPanel(),
          ),
          EditorBottomBar(controller: _ctrl, config: widget.config, theme: _theme),
        ],
      ),
    );
  }

  Widget _buildFilteredImage() {
    if (_imageProvider == null) return Container(color: Colors.grey.shade900);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final adjust = _ctrl.adjustValues;
        final matrix = _combineMatrices(_ctrl.filter.matrix, _buildAdjustMatrix(adjust));
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: Image(image: _imageProvider!, fit: BoxFit.contain),
        );
      },
    );
  }

  List<double> _combineMatrices(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        if (col < 4) {
          result[row * 5 + col] =
              a[row * 5 + 0] * b[0 * 5 + col] +
              a[row * 5 + 1] * b[1 * 5 + col] +
              a[row * 5 + 2] * b[2 * 5 + col] +
              a[row * 5 + 3] * b[3 * 5 + col];
        } else {
          result[row * 5 + 4] =
              a[row * 5 + 0] * b[0 * 5 + 4] +
              a[row * 5 + 1] * b[1 * 5 + 4] +
              a[row * 5 + 2] * b[2 * 5 + 4] +
              a[row * 5 + 3] * b[3 * 5 + 4] +
              a[row * 5 + 4];
        }
      }
    }
    return result;
  }

  List<double> _buildAdjustMatrix(AdjustValues v) {
    final brightness = v.brightness * 100;
    final contrast = v.contrast + 1.0;
    final ct = 128 * (1 - contrast);
    final saturation = v.saturation + 1.0;
    final sr = (1 - saturation) * 0.299;
    final sg = (1 - saturation) * 0.587;
    final sb = (1 - saturation) * 0.114;
    final warmth = v.warmth * 30;
    // Highlights
    final hl = v.highlights * 40;
    // Shadows
    final sh = v.shadows * 40;
    // Sharpness handled via separate widget if needed; skip in matrix

    return [
      contrast * (sr + saturation), contrast * sg, contrast * sb, 0, brightness + ct + warmth + hl,
      contrast * sr, contrast * (sg + saturation), contrast * sb, 0, brightness + ct + sh,
      contrast * sr, contrast * sg, contrast * (sb + saturation), 0, brightness + ct - warmth,
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

  // ── Filters panel ──────────────────────────────────────────────────────────
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

  // ── PROFESSIONAL Adjust panel ──────────────────────────────────────────────
  Widget _buildAdjustPanel() {
    return Container(
      color: _theme.toolbarColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category tabs
          _AdjustCategoryTabs(
            selected: _ctrl.adjustCategory,
            onSelect: (c) {
              _ctrl.adjustCategory = c;
              setState(() {});
            },
            theme: _theme,
          ),
          const SizedBox(height: 4),
          // Sliders for selected category
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildAdjustSliders(),
          ),
          // Reset button
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _localAdjust = const AdjustValues());
                  _ctrl.setAdjust(const AdjustValues());
                  _ctrl.commitAdjust();
                },
                child: Text(
                  'Reset',
                  style: TextStyle(
                    color: _theme.activeToolColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustSliders() {
    switch (_ctrl.adjustCategory) {
      case AdjustCategory.light:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _adjustSlider('Brightness', Icons.brightness_6, _localAdjust.brightness,
                (v) => _onAdjustChange(_localAdjust.copyWith(brightness: v))),
            _adjustSlider('Contrast', Icons.contrast, _localAdjust.contrast,
                (v) => _onAdjustChange(_localAdjust.copyWith(contrast: v))),
            _adjustSlider('Highlights', Icons.wb_sunny_outlined, _localAdjust.highlights,
                (v) => _onAdjustChange(_localAdjust.copyWith(highlights: v))),
            _adjustSlider('Shadows', Icons.nights_stay_outlined, _localAdjust.shadows,
                (v) => _onAdjustChange(_localAdjust.copyWith(shadows: v))),
          ],
        );
      case AdjustCategory.color:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _adjustSlider('Saturation', Icons.color_lens, _localAdjust.saturation,
                (v) => _onAdjustChange(_localAdjust.copyWith(saturation: v))),
            _adjustSlider('Warmth', Icons.wb_sunny, _localAdjust.warmth,
                (v) => _onAdjustChange(_localAdjust.copyWith(warmth: v))),
            _adjustSlider('Tint', Icons.invert_colors, _localAdjust.tint,
                (v) => _onAdjustChange(_localAdjust.copyWith(tint: v))),
            _adjustSlider('Vibrance', Icons.palette, _localAdjust.vibrance,
                (v) => _onAdjustChange(_localAdjust.copyWith(vibrance: v))),
          ],
        );
      case AdjustCategory.detail:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _adjustSlider('Sharpness', Icons.auto_fix_high, _localAdjust.sharpness,
                (v) => _onAdjustChange(_localAdjust.copyWith(sharpness: v))),
            _adjustSlider('Noise Reduction', Icons.blur_on, _localAdjust.noiseReduction,
                (v) => _onAdjustChange(_localAdjust.copyWith(noiseReduction: v))),
            _adjustSlider('Clarity', Icons.hdr_strong, _localAdjust.clarity,
                (v) => _onAdjustChange(_localAdjust.copyWith(clarity: v))),
          ],
        );
    }
  }

  Widget _adjustSlider(String label, IconData icon, double value, void Function(double) onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: _theme.iconColor, size: 16),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: _theme.textColor, fontSize: 11)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _theme.sliderActiveColor,
                inactiveTrackColor: _theme.sliderInactiveColor,
                thumbColor: _theme.activeToolColor,
                overlayColor: _theme.activeToolColor.withOpacity(0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
              value >= 0 ? '+${(value * 100).round()}' : '${(value * 100).round()}',
              style: TextStyle(
                color: value != 0 ? _theme.activeToolColor : _theme.iconColor,
                fontSize: 11,
                fontWeight: value != 0 ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _onAdjustChange(AdjustValues v) {
    setState(() => _localAdjust = v);
    _ctrl.setAdjust(v);
  }

  // ── Drawing panel ──────────────────────────────────────────────────────────
  Widget _buildDrawingPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Eraser
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => GestureDetector(
                    onTap: () => _ctrl.setEraser(!_ctrl.isEraser),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _ctrl.isEraser ? _theme.activeToolColor : Colors.white24,
                          width: 2,
                        ),
                        color: _theme.toolbarColor,
                      ),
                      child: Icon(Icons.auto_fix_normal,
                          color: _ctrl.isEraser ? _theme.activeToolColor : _theme.iconColor,
                          size: 18),
                    ),
                  ),
                ),
                ...widget.config.brushColors.map((c) => AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => GestureDetector(
                    onTap: () {
                      _ctrl.setEraser(false);
                      _ctrl.setBrushColor(c);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: !_ctrl.isEraser && _ctrl.brushColor == c
                              ? _theme.activeToolColor
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                builder: (_, __) => Text('${_ctrl.brushSize.round()}px',
                    style: TextStyle(color: _theme.iconColor, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Text panel ─────────────────────────────────────────────────────────────
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

  void _onTextLayerTap(TextLayer layer) => _openTextDialog(layer);

  // ── Stickers panel ─────────────────────────────────────────────────────────
  Widget _buildStickersPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text('Add stickers to your image.',
                style: TextStyle(color: _theme.iconColor, fontSize: 12)),
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
                  Icon(Icons.emoji_emotions, color: _theme.exportButtonTextColor, size: 16),
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
        onPick: (w) {
          _ctrl.addSticker(StickerLayer(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            widget: w,
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

// ── Adjust Category Tabs ───────────────────────────────────────────────────

enum AdjustCategory { light, color, detail }

class _AdjustCategoryTabs extends StatelessWidget {
  final AdjustCategory selected;
  final void Function(AdjustCategory) onSelect;
  final EditorTheme theme;

  const _AdjustCategoryTabs({
    required this.selected,
    required this.onSelect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: AdjustCategory.values.map((c) {
        final isActive = c == selected;
        final label = c == AdjustCategory.light
            ? '☀ Light'
            : c == AdjustCategory.color
                ? '🎨 Color'
                : '🔍 Detail';
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? theme.activeToolColor : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive ? theme.activeToolColor : theme.iconColor,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
