import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../filters/filter_preset.dart';
import '../models/editor_config.dart';
import '../models/export_options.dart';
import '../models/sticker_pack.dart';
import 'history_manager.dart';

enum EditorTool { crop, filters, adjust, drawing, text, stickers }

/// Adjust values — all range from -1.0 to 1.0 (0.0 = no change).
class AdjustValues {
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  const AdjustValues({
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.warmth = 0.0,
  });

  AdjustValues copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) {
    return AdjustValues(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      warmth: warmth ?? this.warmth,
    );
  }
}

/// Snapshot of the full editor state — used for undo/redo.
class EditorSnapshot {
  final FilterPreset filter;
  final AdjustValues adjustValues;
  final List<DrawingStroke> strokes;
  final List<TextLayer> textLayers;
  final List<StickerLayer> stickerLayers;

  const EditorSnapshot({
    required this.filter,
    required this.adjustValues,
    required this.strokes,
    required this.textLayers,
    required this.stickerLayers,
  });
}

/// A single drawing stroke.
class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  const DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });
}

/// A text layer placed on the canvas.
class TextLayer {
  final String id;
  String text;
  Offset position;
  double fontSize;
  Color color;
  String fontFamily;
  bool bold;
  bool italic;
  bool hasShadow;
  double rotation;

  TextLayer({
    required this.id,
    required this.text,
    this.position = const Offset(100, 100),
    this.fontSize = 28,
    this.color = Colors.white,
    this.fontFamily = 'Roboto',
    this.bold = false,
    this.italic = false,
    this.hasShadow = true,
    this.rotation = 0.0,
  });

  TextLayer copyWith({
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
    String? fontFamily,
    bool? bold,
    bool? italic,
    bool? hasShadow,
    double? rotation,
  }) {
    return TextLayer(
      id: id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      hasShadow: hasShadow ?? this.hasShadow,
      rotation: rotation ?? this.rotation,
    );
  }
}

/// Main controller for [ImageEditorWidget].
/// Exposes all actions and notifies listeners on state change.
class EditorController extends ChangeNotifier {
  // ── Tool ──────────────────────────────────────────────────────────────────
  EditorTool _activeTool = EditorTool.filters;
  EditorTool get activeTool => _activeTool;

  void setTool(EditorTool tool) {
    _activeTool = tool;
    notifyListeners();
  }

  // ── Filter ────────────────────────────────────────────────────────────────
  FilterPreset _filter = FilterPreset.normal;
  FilterPreset get filter => _filter;

  void setFilter(FilterPreset preset) {
    _filter = preset;
    _pushSnapshot();
    notifyListeners();
  }

  // ── Adjust ────────────────────────────────────────────────────────────────
  AdjustValues _adjustValues = const AdjustValues();
  AdjustValues get adjustValues => _adjustValues;

  void setAdjust(AdjustValues values) {
    _adjustValues = values;
    notifyListeners();
  }

  void commitAdjust() {
    _pushSnapshot();
  }

  // ── Drawing ───────────────────────────────────────────────────────────────
  final List<DrawingStroke> _strokes = [];
  List<DrawingStroke> get strokes => List.unmodifiable(_strokes);

  Color _brushColor = Colors.red;
  Color get brushColor => _brushColor;
  void setBrushColor(Color c) {
    _brushColor = c;
    notifyListeners();
  }

  double _brushSize = 6.0;
  double get brushSize => _brushSize;
  void setBrushSize(double s) {
    _brushSize = s;
    notifyListeners();
  }

  bool _isEraser = false;
  bool get isEraser => _isEraser;
  void setEraser(bool v) {
    _isEraser = v;
    notifyListeners();
  }

  void addStroke(DrawingStroke stroke) {
    _strokes.add(stroke);
    _pushSnapshot();
    notifyListeners();
  }

  // ── Text ──────────────────────────────────────────────────────────────────
  final List<TextLayer> _textLayers = [];
  List<TextLayer> get textLayers => List.unmodifiable(_textLayers);

  void addTextLayer(TextLayer layer) {
    _textLayers.add(layer);
    _pushSnapshot();
    notifyListeners();
  }

  void updateTextLayer(TextLayer updated) {
    final i = _textLayers.indexWhere((l) => l.id == updated.id);
    if (i != -1) {
      _textLayers[i] = updated;
      notifyListeners();
    }
  }

  void removeTextLayer(String id) {
    _textLayers.removeWhere((l) => l.id == id);
    _pushSnapshot();
    notifyListeners();
  }

  // ── Stickers ──────────────────────────────────────────────────────────────
  final List<StickerLayer> _stickerLayers = [];
  List<StickerLayer> get stickerLayers => List.unmodifiable(_stickerLayers);

  void addSticker(StickerLayer sticker) {
    _stickerLayers.add(sticker);
    _pushSnapshot();
    notifyListeners();
  }

  void updateSticker(StickerLayer updated) {
    final i = _stickerLayers.indexWhere((s) => s.id == updated.id);
    if (i != -1) {
      _stickerLayers[i] = updated;
      notifyListeners();
    }
  }

  void removeSticker(String id) {
    _stickerLayers.removeWhere((s) => s.id == id);
    _pushSnapshot();
    notifyListeners();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────
  late final HistoryManager<EditorSnapshot> _history;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void initHistory(int maxSteps) {
    _history = HistoryManager(maxSteps: maxSteps);
    _pushSnapshot();
  }

  void _pushSnapshot() {
    _history.push(EditorSnapshot(
      filter: _filter,
      adjustValues: _adjustValues,
      strokes: List.from(_strokes),
      textLayers: List.from(_textLayers),
      stickerLayers: List.from(_stickerLayers),
    ));
  }

  void undo() {
    final snap = _history.undo();
    if (snap != null) _applySnapshot(snap);
  }

  void redo() {
    final snap = _history.redo();
    if (snap != null) _applySnapshot(snap);
  }

  void _applySnapshot(EditorSnapshot snap) {
    _filter = snap.filter;
    _adjustValues = snap.adjustValues;
    _strokes
      ..clear()
      ..addAll(snap.strokes);
    _textLayers
      ..clear()
      ..addAll(snap.textLayers);
    _stickerLayers
      ..clear()
      ..addAll(snap.stickerLayers);
    notifyListeners();
  }

  void reset() {
    _filter = FilterPreset.normal;
    _adjustValues = const AdjustValues();
    _strokes.clear();
    _textLayers.clear();
    _stickerLayers.clear();
    _history.clear();
    _pushSnapshot();
    notifyListeners();
  }

  // ── Export key (used by ImageEditorWidget internally) ─────────────────────
  final GlobalKey exportKey = GlobalKey();
}
