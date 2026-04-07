import 'package:flutter/material.dart';
import '../controllers/editor_controller.dart';
import '../models/editor_theme.dart';

/// Renders all text layers and handles dragging, resizing, and editing.
class TextOverlayLayer extends StatelessWidget {
  final EditorController controller;
  final EditorTheme theme;
  final void Function(TextLayer layer) onTap;

  const TextOverlayLayer({
    super.key,
    required this.controller,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Stack(
        children: controller.textLayers
            .map((layer) => _DraggableText(
                  key: ValueKey(layer.id),
                  layer: layer,
                  theme: theme,
                  onMove: (pos) =>
                      controller.updateTextLayer(layer.copyWith(position: pos)),
                  onTap: () => onTap(layer),
                  onDelete: () => controller.removeTextLayer(layer.id),
                ))
            .toList(),
      ),
    );
  }
}

class _DraggableText extends StatefulWidget {
  final TextLayer layer;
  final EditorTheme theme;
  final void Function(Offset) onMove;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraggableText({
    super.key,
    required this.layer,
    required this.theme,
    required this.onMove,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_DraggableText> createState() => _DraggableTextState();
}

class _DraggableTextState extends State<_DraggableText> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    return Positioned(
      left: layer.position.dx,
      top: layer.position.dy,
      child: GestureDetector(
        onTap: () {
          setState(() => _selected = !_selected);
          widget.onTap();
        },
        onPanUpdate: (d) =>
            widget.onMove(layer.position + d.delta),
        child: Transform.rotate(
          angle: layer.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: _selected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.white54, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Text(
                  layer.text,
                  style: TextStyle(
                    fontSize: layer.fontSize,
                    color: layer.color,
                    fontFamily: layer.fontFamily,
                    fontWeight:
                        layer.bold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: layer.italic
                        ? FontStyle.italic
                        : FontStyle.normal,
                    shadows: layer.hasShadow
                        ? [
                            const Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                              offset: Offset(1, 1),
                            )
                          ]
                        : null,
                  ),
                ),
              ),
              // Delete button when selected
              if (_selected)
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for adding or editing a text layer.
class TextEditorDialog extends StatefulWidget {
  final TextLayer? existing;
  final EditorTheme theme;

  const TextEditorDialog({super.key, this.existing, required this.theme});

  @override
  State<TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<TextEditorDialog> {
  late TextEditingController _textCtrl;
  late Color _color;
  late double _fontSize;
  late bool _bold;
  late bool _italic;
  late bool _shadow;

  @override
  void initState() {
    super.initState();
    final l = widget.existing;
    _textCtrl = TextEditingController(text: l?.text ?? '');
    _color = l?.color ?? Colors.white;
    _fontSize = l?.fontSize ?? 28;
    _bold = l?.bold ?? false;
    _italic = l?.italic ?? false;
    _shadow = l?.hasShadow ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.theme.toolbarColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textCtrl,
              autofocus: true,
              style: TextStyle(color: widget.theme.textColor, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Enter text...',
                hintStyle: TextStyle(color: widget.theme.iconColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: widget.theme.inactiveToolColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: widget.theme.inactiveToolColor)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: widget.theme.activeToolColor)),
              ),
            ),
            const SizedBox(height: 16),
            // Font size slider
            Row(
              children: [
                Icon(Icons.format_size, color: widget.theme.iconColor, size: 18),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 12,
                    max: 72,
                    activeColor: widget.theme.sliderActiveColor,
                    inactiveColor: widget.theme.sliderInactiveColor,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                Text('${_fontSize.round()}',
                    style: TextStyle(
                        color: widget.theme.textColor, fontSize: 12)),
              ],
            ),
            // Style toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _toggleBtn(Icons.format_bold, _bold,
                    () => setState(() => _bold = !_bold)),
                _toggleBtn(Icons.format_italic, _italic,
                    () => setState(() => _italic = !_italic)),
                _toggleBtn(Icons.wb_sunny_outlined, _shadow,
                    () => setState(() => _shadow = !_shadow)),
              ],
            ),
            const SizedBox(height: 8),
            // Color picker (simple row)
            _buildColorRow(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(color: widget.theme.iconColor)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.exportButtonColor,
                      foregroundColor: widget.theme.exportButtonTextColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (_textCtrl.text.trim().isEmpty) return;
                      final layer = (widget.existing ?? TextLayer(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                text: '',
                              ))
                          .copyWith(
                            text: _textCtrl.text.trim(),
                            color: _color,
                            fontSize: _fontSize,
                            bold: _bold,
                            italic: _italic,
                            hasShadow: _shadow,
                          );
                      Navigator.pop(context, layer);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active
              ? widget.theme.activeToolColor
              : widget.theme.toolbarColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.theme.inactiveToolColor),
        ),
        child: Icon(icon,
            color:
                active ? widget.theme.exportButtonTextColor : widget.theme.iconColor,
            size: 18),
      ),
    );
  }

  Widget _buildColorRow() {
    const colors = [
      Colors.white, Colors.black, Colors.red, Colors.orange,
      Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.pink,
    ];
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: colors
            .map((c) => GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c
                            ? widget.theme.activeToolColor
                            : Colors.white24,
                        width: _color == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }
}
