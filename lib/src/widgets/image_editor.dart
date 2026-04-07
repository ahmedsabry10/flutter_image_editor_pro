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

  // Current image bytes (updated after each crop)
  Uint8List? _currentBytes;
  // Decoded image dimensions (actual pixels)
  int _imgW = 0, _imgH = 0;

  bool _loading = true;
  bool _exporting = false;

  // The rect the user drew on the overlay (in overlay/canvas coordinates)
  Rect? _pendingCropRect;
  // The size of the canvas widget when crop overlay was shown
  Size? _canvasSize;

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

  // ── Load image ─────────────────────────────────────────────────────────────
  Future<void> _loadImage() async {
    setState(() => _loading = true);
    try {
      Uint8List? bytes;
      final img = widget.image;
      if (img is Uint8List) {
        bytes = img;
      } else if (img is ImageProvider) {
        // Can't easily get bytes from arbitrary ImageProvider — skip pixel crop
      } else if (img is String) {
        // Network image — skip pixel crop
      } else {
        // File
        bytes = await (img as dynamic).readAsBytes() as Uint8List;
      }

      if (bytes != null) {
        _currentBytes = bytes;
        await _decodeImageSize(bytes);
        _thumbnail = await _decodeUiImageSmall(bytes);
      }
    } catch (e) {
      debugPrint('Load image error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _imgW = frame.image.width;
      _imgH = frame.image.height;
    } catch (_) {}
  }

  Future<ui.Image?> _decodeUiImageSmall(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  // Key incremented each time _currentBytes changes so Flutter doesn't serve
  // the stale MemoryImage from its cache after a crop.
  int _imageKey = 0;

  ImageProvider get _imageProvider {
    if (_currentBytes != null) return MemoryImage(_currentBytes!);
    final img = widget.image;
    if (img is Uint8List) return MemoryImage(img);
    if (img is ImageProvider) return img;
    if (img is String) return NetworkImage(img);
    return MemoryImage(_currentBytes ?? Uint8List(0));
  }

  // ── Apply crop ─────────────────────────────────────────────────────────────
  //
  // The key insight:
  //   - The canvas shows the image with BoxFit.contain
  //   - The image is letterboxed (black bars top/bottom or left/right)
  //   - The crop overlay covers the FULL canvas, not just the image area
  //   - So we must compute the actual rendered image rect inside the canvas
  //     and only map the portion of _pendingCropRect that overlaps it.
  //
  Future<void> _applyCrop() async {
    final bytes = _currentBytes;
    if (bytes == null || _imgW == 0 || _imgH == 0) {
      debugPrint('Crop: no bytes or image size unknown');
      return;
    }

    final canvasSize = _canvasSize;
    if (canvasSize == null) {
      debugPrint('Crop: canvas size not recorded');
      return;
    }

    // Use full canvas if user never dragged handles
    final cropRectInCanvas = _pendingCropRect ??
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);

    // ── Compute the rendered image rect inside the canvas (BoxFit.contain) ──
    final imageAspect = _imgW / _imgH;
    final canvasAspect = canvasSize.width / canvasSize.height;

    double renderedW, renderedH, offsetX, offsetY;
    if (imageAspect > canvasAspect) {
      // Letterboxed top/bottom
      renderedW = canvasSize.width;
      renderedH = canvasSize.width / imageAspect;
      offsetX = 0;
      offsetY = (canvasSize.height - renderedH) / 2;
    } else {
      // Pillarboxed left/right
      renderedH = canvasSize.height;
      renderedW = canvasSize.height * imageAspect;
      offsetX = (canvasSize.width - renderedW) / 2;
      offsetY = 0;
    }

    final renderedImageRect =
        Rect.fromLTWH(offsetX, offsetY, renderedW, renderedH);

    // ── Intersect crop rect with the actual image rect ──────────────────────
    final intersection = cropRectInCanvas.intersect(renderedImageRect);
    if (intersection.isEmpty) {
      debugPrint('Crop: selection outside image area');
      return;
    }

    // ── Map intersection → pixel coordinates ────────────────────────────────
    final scaleX = _imgW / renderedW;
    final scaleY = _imgH / renderedH;

    final pixelX = ((intersection.left - offsetX) * scaleX).round().clamp(0, _imgW);
    final pixelY = ((intersection.top - offsetY) * scaleY).round().clamp(0, _imgH);
    final pixelW = (intersection.width * scaleX).round().clamp(1, _imgW - pixelX);
    final pixelH = (intersection.height * scaleY).round().clamp(1, _imgH - pixelY);

    debugPrint('Crop pixels: x=$pixelX y=$pixelY w=$pixelW h=$pixelH (img ${_imgW}x$_imgH)');

    setState(() => _loading = true);
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(
            pixelX.toDouble(), pixelY.toDouble(),
            pixelW.toDouble(), pixelH.toDouble()),
        Rect.fromLTWH(0, 0, pixelW.toDouble(), pixelH.toDouble()),
        Paint(),
      );
      final pic = recorder.endRecording();
      final cropped = await pic.toImage(pixelW, pixelH);
      final byteData =
          await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final newBytes = byteData.buffer.asUint8List();
      // Evict old MemoryImage from Flutter's cache before swapping bytes.
      if (_currentBytes != null) {
        final oldProvider = MemoryImage(_currentBytes!);
        await oldProvider.evict();
      }
      _currentBytes = newBytes;
      _imageKey++;
      _imgW = pixelW;
      _imgH = pixelH;
      _thumbnail = await _decodeUiImageSmall(newBytes);
      _pendingCropRect = null;
      _ctrl.setTool(EditorTool.filters);
    } catch (e) {
      debugPrint('Crop error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────────
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary = _ctrl.exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final opts = widget.config.exportOptions;
      final image = await boundary.toImage(pixelRatio: opts.pixelRatio);
      // Always capture as PNG from the boundary, then re-encode to JPEG if needed.
      final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) return;
      final pngBytes = pngData.buffer.asUint8List();

      Uint8List outputBytes;
      if (opts.format == ExportFormat.jpeg) {
        // Re-encode PNG → JPEG via dart:ui codec round-trip.
        final codec = await ui.instantiateImageCodec(pngBytes);
        final frame = await codec.getNextFrame();
        final jpegData = await frame.image
            .toByteData(format: ui.ImageByteFormat.rawRgba);
        if (jpegData == null) return;
        // dart:ui has no native JPEG encoder; emit PNG with .jpeg label
        // so consumers can encode via the `image` package if desired.
        // For now we output PNG bytes (lossless) and flag format as jpeg.
        // TODO: add `package:image` for true JPEG encoding.
        outputBytes = pngBytes;
      } else {
        outputBytes = pngBytes;
      }

      widget.onExport?.call(EditorResult(
        bytes: outputBytes,
        width: image.width,
        height: image.height,
        format: opts.format,
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: _theme.backgroundColor,
        child: Center(
            child: CircularProgressIndicator(color: _theme.activeToolColor)),
      );
    }

    return Stack(
      children: [
        // ── Main editor layout ─────────────────────────────────────────────
        Container(
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
                child: RepaintBoundary(
                  key: _ctrl.exportKey,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildFilteredImage(),
                        if (widget.config.enableDrawing)
                          LayoutBuilder(
                            builder: (ctx, constraints) => DrawingCanvas(
                              controller: _ctrl,
                              size: Size(constraints.maxWidth,
                                  constraints.maxHeight),
                              isActive:
                                  _ctrl.activeTool == EditorTool.drawing,
                            ),
                          ),
                        if (widget.config.enableText)
                          TextOverlayLayer(
                            controller: _ctrl,
                            theme: _theme,
                            onTap: _onTextLayerTap,
                          ),
                        if (widget.config.enableStickers)
                          StickerLayerWidget(
                              controller: _ctrl, theme: _theme),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => _buildToolPanel(),
              ),
              EditorBottomBar(
                  controller: _ctrl,
                  config: widget.config,
                  theme: _theme),
            ],
          ),
        ),

        // ── Crop overlay — sits above everything including bottom bar ───────
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            if (!widget.config.enableCrop ||
                _ctrl.activeTool != EditorTool.crop) {
              return const SizedBox.shrink();
            }
            return LayoutBuilder(builder: (ctx, constraints) {
              // constraints here = full Stack size (whole editor)
              // We want the overlay to cover only the image canvas area,
              // so offset it below the toolbar.
              final toolbarH = _theme.toolbarHeight;
              final bottomH = _theme.bottomBarHeight;
              final canvasH =
                  constraints.maxHeight - toolbarH - bottomH;
              final sz = Size(constraints.maxWidth, canvasH);
              _canvasSize = sz;
              final aspect = (_imgW > 0 && _imgH > 0)
                  ? _imgW / _imgH
                  : 1.0;
              return Positioned(
                top: toolbarH,
                left: 0,
                right: 0,
                height: canvasH,
                child: CropOverlay(
                  canvasSize: sz,
                  imageAspect: aspect,
                  ratios: widget.config.cropAspectRatios ??
                      CropAspectRatio.defaultRatios,
                  onCropChanged: (r) => _pendingCropRect = r,
                  onApply: _applyCrop,
                ),
              );
            });
          },
        ),

        // ── Exporting indicator ────────────────────────────────────────────
        if (_exporting)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _theme.activeToolColor),
                  const SizedBox(height: 12),
                  Text('Saving...',
                      style: TextStyle(color: _theme.textColor)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilteredImage() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final matrix = _combineMatrices(
            _ctrl.filter.matrix, _buildAdjustMatrix(_ctrl.adjustValues));
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: Image(
            key: ValueKey(_imageKey),
            image: _imageProvider,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }

  List<double> _combineMatrices(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        if (col < 4) {
          out[row * 5 + col] = a[row * 5] * b[col] +
              a[row * 5 + 1] * b[5 + col] +
              a[row * 5 + 2] * b[10 + col] +
              a[row * 5 + 3] * b[15 + col];
        } else {
          out[row * 5 + 4] = a[row * 5] * b[4] +
              a[row * 5 + 1] * b[9] +
              a[row * 5 + 2] * b[14] +
              a[row * 5 + 3] * b[19] +
              a[row * 5 + 4];
        }
      }
    }
    return out;
  }

  List<double> _buildAdjustMatrix(AdjustValues v) {
    final br = v.brightness * 100;
    final c = v.contrast + 1.0;
    final ct = 128 * (1 - c);
    final s = v.saturation + 1.0;
    final sr = (1 - s) * 0.299;
    final sg = (1 - s) * 0.587;
    final sb = (1 - s) * 0.114;
    final w = v.warmth * 30;
    final hl = v.highlights * 40;
    final sh = v.shadows * 40;
    return [
      c * (sr + s), c * sg,      c * sb,      0, br + ct + w + hl,
      c * sr,       c * (sg + s),c * sb,      0, br + ct + sh,
      c * sr,       c * sg,      c * (sb + s),0, br + ct - w,
      0,            0,           0,           1, 0,
    ];
  }

  Widget _buildToolPanel() {
    switch (_ctrl.activeTool) {
      case EditorTool.filters:  return _buildFiltersPanel();
      case EditorTool.adjust:   return _buildAdjustPanel();
      case EditorTool.drawing:  return _buildDrawingPanel();
      case EditorTool.text:     return _buildTextPanel();
      case EditorTool.stickers: return _buildStickersPanel();
      default:                  return const SizedBox.shrink();
    }
  }

  // ── Filters ────────────────────────────────────────────────────────────────
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

  // ── Adjust ─────────────────────────────────────────────────────────────────
  Widget _buildAdjustPanel() {
    return Container(
      color: _theme.toolbarColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdjustCategoryTabs(
            selected: _ctrl.adjustCategory,
            onSelect: (c) { _ctrl.adjustCategory = c; setState(() {}); },
            theme: _theme,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildAdjustSliders(),
          ),
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
                child: Text('Reset',
                    style: TextStyle(
                        color: _theme.activeToolColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
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
        return Column(mainAxisSize: MainAxisSize.min, children: [
          _adjSlider('Brightness', Icons.brightness_6, _localAdjust.brightness,
              (v) => _onAdjust(_localAdjust.copyWith(brightness: v))),
          _adjSlider('Contrast', Icons.contrast, _localAdjust.contrast,
              (v) => _onAdjust(_localAdjust.copyWith(contrast: v))),
          _adjSlider('Highlights', Icons.wb_sunny_outlined, _localAdjust.highlights,
              (v) => _onAdjust(_localAdjust.copyWith(highlights: v))),
          _adjSlider('Shadows', Icons.nights_stay_outlined, _localAdjust.shadows,
              (v) => _onAdjust(_localAdjust.copyWith(shadows: v))),
        ]);
      case AdjustCategory.color:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          _adjSlider('Saturation', Icons.color_lens, _localAdjust.saturation,
              (v) => _onAdjust(_localAdjust.copyWith(saturation: v))),
          _adjSlider('Warmth', Icons.wb_sunny, _localAdjust.warmth,
              (v) => _onAdjust(_localAdjust.copyWith(warmth: v))),
          _adjSlider('Tint', Icons.invert_colors, _localAdjust.tint,
              (v) => _onAdjust(_localAdjust.copyWith(tint: v))),
          _adjSlider('Vibrance', Icons.palette, _localAdjust.vibrance,
              (v) => _onAdjust(_localAdjust.copyWith(vibrance: v))),
        ]);
      case AdjustCategory.detail:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          _adjSlider('Sharpness', Icons.auto_fix_high, _localAdjust.sharpness,
              (v) => _onAdjust(_localAdjust.copyWith(sharpness: v))),
          _adjSlider('Noise Reduction', Icons.blur_on, _localAdjust.noiseReduction,
              (v) => _onAdjust(_localAdjust.copyWith(noiseReduction: v))),
          _adjSlider('Clarity', Icons.hdr_strong, _localAdjust.clarity,
              (v) => _onAdjust(_localAdjust.copyWith(clarity: v))),
        ]);
    }
  }

  Widget _adjSlider(String label, IconData icon, double value,
      void Function(double) onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, color: _theme.iconColor, size: 16),
        const SizedBox(width: 6),
        SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: _theme.textColor, fontSize: 11))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _theme.sliderActiveColor,
              inactiveTrackColor: _theme.sliderInactiveColor,
              thumbColor: _theme.activeToolColor,
              overlayColor: _theme.activeToolColor.withOpacity(0.2),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
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
              color: value != 0
                  ? _theme.activeToolColor
                  : _theme.iconColor,
              fontSize: 11,
              fontWeight:
                  value != 0 ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    );
  }

  void _onAdjust(AdjustValues v) {
    setState(() => _localAdjust = v);
    _ctrl.setAdjust(v);
  }

  // ── Drawing ────────────────────────────────────────────────────────────────
  Widget _buildDrawingPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => GestureDetector(
                  onTap: () => _ctrl.setEraser(!_ctrl.isEraser),
                  child: Container(
                    width: 36, height: 36,
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
                    width: 36, height: 36,
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
        Row(children: [
          Icon(Icons.brush, color: _theme.iconColor, size: 16),
          Expanded(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Slider(
                value: _ctrl.brushSize,
                min: 2, max: 40,
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
        ]),
      ]),
    );
  }

  // ── Text ───────────────────────────────────────────────────────────────────
  Widget _buildTextPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
            child: Text('Tap the canvas to place text, or add a new layer.',
                style: TextStyle(color: _theme.iconColor, fontSize: 12))),
        GestureDetector(
          onTap: _openTextDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: _theme.activeToolColor,
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(Icons.add, color: _theme.exportButtonTextColor, size: 16),
              const SizedBox(width: 4),
              Text('Add Text',
                  style: TextStyle(
                      color: _theme.exportButtonTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _openTextDialog([TextLayer? existing]) async {
    final result = await showDialog<TextLayer>(
      context: context,
      builder: (_) => TextEditorDialog(existing: existing, theme: _theme),
    );
    if (result == null) return;
    existing != null
        ? _ctrl.updateTextLayer(result)
        : _ctrl.addTextLayer(result);
  }

  void _onTextLayerTap(TextLayer layer) => _openTextDialog(layer);

  // ── Stickers ───────────────────────────────────────────────────────────────
  Widget _buildStickersPanel() {
    return Container(
      color: _theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
            child: Text('Add stickers to your image.',
                style: TextStyle(color: _theme.iconColor, fontSize: 12))),
        GestureDetector(
          onTap: _openStickerPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: _theme.activeToolColor,
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(Icons.emoji_emotions,
                  color: _theme.exportButtonTextColor, size: 16),
              const SizedBox(width: 4),
              Text('Stickers',
                  style: TextStyle(
                      color: _theme.exportButtonTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  void _openStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerPickerSheet(
        packs: widget.config.stickerPacks,
        theme: _theme,
        onPick: (w) => _ctrl.addSticker(StickerLayer(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          widget: w,
        )),
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

// ── Adjust category enum & tabs ────────────────────────────────────────────

enum AdjustCategory { light, color, detail }

class _AdjustCategoryTabs extends StatelessWidget {
  final AdjustCategory selected;
  final void Function(AdjustCategory) onSelect;
  final EditorTheme theme;

  const _AdjustCategoryTabs(
      {required this.selected,
      required this.onSelect,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    const labels = {
      AdjustCategory.light: '☀ Light',
      AdjustCategory.color: '🎨 Color',
      AdjustCategory.detail: '🔍 Detail',
    };
    return Row(
      children: AdjustCategory.values.map((c) {
        final active = c == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? theme.activeToolColor : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                labels[c]!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? theme.activeToolColor : theme.iconColor,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
